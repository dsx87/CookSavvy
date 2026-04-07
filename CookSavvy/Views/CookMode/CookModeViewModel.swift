import SwiftUI
import Combine

@MainActor
final class CookModeViewModel: ObservableObject {
    let recipe: Recipe

    @Published var currentStep: Int = 0
    @Published var timerSeconds: Int = 0
    @Published var timerRunning: Bool = false
    @Published var completedSteps: Set<Int> = []
    @Published var showFeedback: Bool = false
    @Published var feedbackRating: Int = 0

    private let userDataService: UserDataServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private let onDismiss: () -> Void
    private var timerCancellable: AnyCancellable?
    private var startDate: Date?
    private var cookDuration: TimeInterval?

    init(
        recipe: Recipe,
        userDataService: UserDataServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.recipe = recipe
        self.userDataService = userDataService
        self.analyticsService = analyticsService
        self.logger = logger
        self.onDismiss = onDismiss
        self.startDate = Date()
    }

    var stepCount: Int { recipe.instructions.count }

    var progress: Double {
        guard stepCount > 0 else { return 0 }
        return Double(completedSteps.count) / Double(stepCount)
    }

    var currentStepText: String {
        guard currentStep < stepCount else { return "" }
        return recipe.instructions[currentStep].text
    }

    var currentStepTimer: Int? {
        guard currentStep < stepCount else { return nil }
        return recipe.instructions[currentStep].timerMinutes
    }

    var isFirstStep: Bool { currentStep == 0 }
    var isLastStep: Bool { currentStep == stepCount - 1 }

    var stepAccessibilityLabel: String {
        String(format: Strings.Accessibility.stepOf, currentStep + 1, stepCount)
    }

    func timerDisplayText() -> String {
        guard let timerMin = currentStepTimer else { return "" }
        let remaining = timerRunning ? max(timerMin * 60 - timerSeconds, 0) : timerMin * 60
        return formatTime(remaining)
    }

    var timerProgress: CGFloat {
        guard let timerMin = currentStepTimer, timerMin > 0 else { return 0 }
        return timerRunning ? CGFloat(timerSeconds) / CGFloat(timerMin * 60) : 0
    }

    func toggleTimer() {
        if timerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }

    func goNext() {
        guard currentStep < stepCount - 1 else { return }
        currentStep += 1
        resetTimer()
    }

    func goPrevious() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        resetTimer()
    }

    func markDone() {
        completedSteps.insert(currentStep)
        if currentStep < stepCount - 1 {
            currentStep += 1
            resetTimer()
        }
    }

    func finish() {
        completedSteps.insert(currentStep)
        stopTimer()
        cookDuration = startDate.map { Date().timeIntervalSince($0) }
        showFeedback = true
    }

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

    func dismiss() {
        stopTimer()
        onDismiss()
    }

    // MARK: - Private

    private func startTimer() {
        timerRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard let timerMin = self.currentStepTimer else { return }
                if self.timerSeconds < timerMin * 60 {
                    self.timerSeconds += 1
                } else {
                    self.stopTimer()
                }
            }
    }

    private func stopTimer() {
        timerRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func resetTimer() {
        stopTimer()
        timerSeconds = 0
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
