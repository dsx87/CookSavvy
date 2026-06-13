import SwiftUI

/// ViewModel backing the Cook Mode full-screen step-by-step cooking flow.
///
/// Manages:
/// - Navigation through recipe steps (next, previous, mark done)
/// - An optional per-step countdown timer driven by an async `Task` loop
/// - A circular progress ring based on completed step count
/// - A post-cook feedback sheet (star rating) shown when the last step is finished
/// - Persisting the completed cooking session via `UserDataService`
@MainActor
@Observable final class CookModeViewModel {
    /// The recipe being cooked.
    let recipe: Recipe

    /// Zero-indexed position of the currently displayed step.
    var currentStep: Int = 0
    /// Elapsed seconds since the current step's timer was started.
    var timerSeconds: Int = 0
    /// `true` when the per-step countdown timer is actively running.
    var timerRunning: Bool = false
    /// Indices of steps the user has explicitly marked as done.
    var completedSteps: Set<Int> = []
    /// `true` when the post-cook feedback sheet is visible.
    var showFeedback: Bool = false
    /// The star rating (1–5) the user gave this cook; `0` means not yet rated.
    var feedbackRating: Int = 0

    private let userDataService: UserDataServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private let idleTimerService: IdleTimerServiceProtocol
    private let onDismiss: () -> Void
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    private var startDate: Date?
    private var cookDuration: TimeInterval?

    /// Creates a cook-mode session for a specific recipe and dismissal callback.
    init(
        recipe: Recipe,
        userDataService: UserDataServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol,
        idleTimerService: IdleTimerServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.recipe = recipe
        self.userDataService = userDataService
        self.analyticsService = analyticsService
        self.logger = logger
        self.idleTimerService = idleTimerService
        self.onDismiss = onDismiss
        self.startDate = Date()
    }

    /// Keeps the screen awake for the duration of the cooking session.
    ///
    /// Cook Mode is hands-free, so the system idle timer is disabled while the screen is
    /// visible and re-enabled when it disappears (see `endKeepingScreenAwake`). The view's
    /// `onAppear`/`onDisappear` lifecycle is the single source of truth for the balanced pair.
    func beginKeepingScreenAwake() {
        idleTimerService.setIdleTimerDisabled(true)
    }

    /// Re-enables the system idle timer when Cook Mode is no longer on screen.
    func endKeepingScreenAwake() {
        idleTimerService.setIdleTimerDisabled(false)
    }

    /// Total number of steps in the recipe.
    var stepCount: Int { recipe.instructions.count }

    /// Fraction of steps completed (0.0 – 1.0), used to drive the progress ring.
    var progress: Double {
        guard stepCount > 0 else { return 0 }
        return Double(completedSteps.count) / Double(stepCount)
    }

    /// The instruction text for the currently visible step.
    var currentStepText: String {
        guard currentStep < stepCount else { return "" }
        return recipe.instructions[currentStep].text
    }

    /// The optional timer duration (in minutes) for the current step; `nil` if none is set.
    var currentStepTimer: Int? {
        guard currentStep < stepCount else { return nil }
        return recipe.instructions[currentStep].timerMinutes
    }

    /// `true` when the current step is the first one (previous button disabled).
    var isFirstStep: Bool { currentStep == 0 }
    /// `true` when the current step is the last one (next shows "Finish" behaviour).
    var isLastStep: Bool { currentStep == stepCount - 1 }

    /// VoiceOver label describing the current step position (e.g. "Step 2 of 5").
    var stepAccessibilityLabel: String {
        String(format: Strings.Accessibility.stepOf, currentStep + 1, stepCount)
    }

    /// Formatted remaining time for the current step's timer (e.g. "2:30").
    /// Returns an empty string if the step has no timer.
    func timerDisplayText() -> String {
        guard let timerMin = currentStepTimer else { return "" }
        let remaining = timerRunning ? max(timerMin * 60 - timerSeconds, 0) : timerMin * 60
        return formatTime(remaining)
    }

    /// Fractional elapsed time (0.0 – 1.0) used to animate the timer ring arc.
    var timerProgress: CGFloat {
        guard let timerMin = currentStepTimer, timerMin > 0 else { return 0 }
        return timerRunning ? CGFloat(timerSeconds) / CGFloat(timerMin * 60) : 0
    }

    /// Toggles the step timer between running and paused.
    func toggleTimer() {
        if timerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }

    /// Advances to the next step and resets the timer.
    func goNext() {
        guard currentStep < stepCount - 1 else { return }
        currentStep += 1
        resetTimer()
    }

    /// Returns to the previous step and resets the timer.
    func goPrevious() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        resetTimer()
    }

    /// Marks the current step done and advances to the next one.
    func markDone() {
        completedSteps.insert(currentStep)
        if currentStep < stepCount - 1 {
            currentStep += 1
            resetTimer()
        }
    }

    /// Marks the last step done, stops the timer, captures the total cooking duration,
    /// and shows the feedback rating sheet.
    func finish() {
        completedSteps.insert(currentStep)
        stopTimer()
        cookDuration = startDate.map { Date().timeIntervalSince($0) }
        showFeedback = true
    }

    /// Saves the cooking session with the user's star rating and dismisses Cook Mode.
    func submitFeedback() {
        let rating = feedbackRating > 0 ? feedbackRating : nil
        let duration = cookDuration
        analyticsService.track(.recipeCooked)
        Task {
            do {
                try await userDataService.markAsCooked(recipe: recipe, duration: duration, rating: rating)
            } catch {
                logger.error("Failed to save cooked recipe feedback: \(String(describing: error))")
            }
        }
        onDismiss()
    }

    /// Saves the cooking session without a rating and dismisses Cook Mode.
    func skipFeedback() {
        let duration = cookDuration
        analyticsService.track(.recipeCooked)
        Task {
            do {
                try await userDataService.markAsCooked(recipe: recipe, duration: duration)
            } catch {
                logger.error("Failed to save cooked recipe progress: \(String(describing: error))")
            }
        }
        onDismiss()
    }

    /// Stops any running timer and dismisses Cook Mode without saving.
    func dismiss() {
        stopTimer()
        onDismiss()
    }

    // MARK: - Private

    /// Starts an async timer loop and increments `timerSeconds` each second until the step duration elapses.
    private func startTimer() {
        timerRunning = true
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard let timerMin = self.currentStepTimer else { continue }
                if self.timerSeconds < timerMin * 60 {
                    self.timerSeconds += 1
                } else {
                    // T-035 deferred polish: completion is intentionally silent for now
                    // (no haptic/sound). The progress ring likewise only advances when a
                    // step is explicitly marked Done. Both are tracked as non-blocking
                    // follow-ups on the ticket.
                    self.stopTimer()
                    return
                }
            }
        }
    }

    /// Cancels the timer task and marks the timer as stopped.
    private func stopTimer() {
        timerRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    /// Stops the timer and resets `timerSeconds` to zero (called on step navigation).
    private func resetTimer() {
        stopTimer()
        timerSeconds = 0
    }

    /// Formats a total-seconds integer into "M:SS" display format (e.g. 90 → "1:30").
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
