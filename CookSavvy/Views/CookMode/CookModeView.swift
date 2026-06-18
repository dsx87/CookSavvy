import SwiftUI

/// Full-screen Cook Mode view with step-by-step cooking navigation.
///
/// Shows a progress ring and dot indicator at the top, the current step text in the center,
/// an optional countdown timer for timed steps, and prev/next navigation at the bottom.
/// On finishing the last step, an overlay feedback card appears for star rating.
struct CookModeView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var viewModel: CookModeViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.accent.opacity(UI.CookMode.bgOpacity), theme.bg],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                stepProgressDots
                stepContent
                navigationButtons
            }

            if viewModel.showFeedback {
                feedbackOverlay
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .none : UI.Anim.easeDefault, value: viewModel.showFeedback)
        // Cook Mode is hands-free, so keep the screen awake for the whole session and
        // restore the system idle timer once the screen is dismissed.
        .onAppear { viewModel.beginKeepingScreenAwake() }
        .onDisappear { viewModel.endKeepingScreenAwake() }
    }

    // MARK: - Top Bar

    /// Top bar with progress ring, step counter, recipe title, and close button.
    private var topBar: some View {
        HStack {
            Button { viewModel.dismiss() } label: {
                Image(systemName: Icons.CookMode.close)
                    .font(UI.Fonts.buttonIcon)
                    .foregroundStyle(theme.text2)
                    .frame(width: UI.CookMode.closeButtonSize, height: UI.CookMode.closeButtonSize)
                    .background(theme.surface, in: Circle())
            }
            .accessibilityIdentifier(AccessibilityID.CookMode.closeButton)
            .accessibilityLabel(Strings.Accessibility.closeButton)

            Spacer()

            VStack(spacing: UI.CookMode.titleInfoSpacing) {
                Text(viewModel.recipe.title)
                    .font(UI.Fonts.sectionTitle)
                    .foregroundStyle(theme.text1)
                Text(String(format: Strings.CookMode.stepOf, viewModel.currentStep + 1, viewModel.stepCount))
                    .font(UI.Fonts.smallCaption)
                    .foregroundStyle(theme.text2)
                    .accessibilityLabel(viewModel.stepAccessibilityLabel)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(theme.surface, lineWidth: UI.CookMode.progressLineWidth)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: UI.CookMode.progressLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(viewModel.completedSteps.count)")
                    .font(UI.Fonts.smallCaptionBold)
                    .foregroundStyle(theme.accent)
            }
            .frame(width: UI.CookMode.progressSize, height: UI.CookMode.progressSize)
            .animation(UI.Anim.easeDefault, value: viewModel.progress)
        }
        .padding(.horizontal, UI.CookMode.horizontalPadding)
        .padding(.top, UI.CookMode.topBarTopPadding)
    }

    // MARK: - Step Progress Dots

    /// Horizontal row of dots showing which steps are completed, current, or pending.
    private var stepProgressDots: some View {
        HStack(spacing: UI.CookMode.dotsSpacing) {
            ForEach(0..<viewModel.stepCount, id: \.self) { i in
                Capsule()
                    .fill(i == viewModel.currentStep ? theme.accent :
                            (viewModel.completedSteps.contains(i) ? theme.mint : theme.surfaceLight))
                    .frame(height: UI.Common.dotHeight)
                    .frame(maxWidth: i == viewModel.currentStep ? .infinity : UI.Common.dotInactiveWidth)
                    .animation(reduceMotion ? nil : UI.Anim.springDefault, value: viewModel.currentStep)
            }
        }
        .padding(.horizontal, UI.CookMode.horizontalPadding)
        .padding(.top, UI.CookMode.dotsTopPadding)
        .accessibilityIdentifier(AccessibilityID.CookMode.stepProgress)
        .accessibilityHidden(true)
    }

    // MARK: - Step Content

    /// The current step instruction text and optional timer in a scrollable card.
    ///
    /// A `GeometryReader` + `minHeight` keeps short steps vertically centered (matching the
    /// previous Spacer-sandwiched look) while letting long steps or large Dynamic Type scroll
    /// instead of clipping.
    private var stepContent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: UI.CookMode.contentSpacing) {
                    Text(viewModel.currentStepText)
                        .font(UI.Fonts.stepContent)
                        .foregroundStyle(theme.text1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, UI.CookMode.horizontalPadding)
                        .id(viewModel.currentStep)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .accessibilityIdentifier(AccessibilityID.CookMode.stepText)

                    if let timerMin = viewModel.currentStepTimer {
                        timerView(minutes: timerMin)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .padding(.vertical, UI.CookMode.stepContentVerticalPadding)
            }
        }
    }

    /// Circular countdown timer ring shown when the current step has a `timerMinutes` value.
    private func timerView(minutes: Int) -> some View {
        VStack(spacing: UI.CookMode.timerSpacing) {
            ZStack {
                Circle()
                    .stroke(theme.surface, lineWidth: UI.CookMode.timerLineWidth)
                    .frame(width: UI.V2.cookModeTimerSize, height: UI.V2.cookModeTimerSize)

                Circle()
                    .trim(from: 0, to: viewModel.timerProgress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: UI.CookMode.timerLineWidth, lineCap: .round))
                    .frame(width: UI.V2.cookModeTimerSize, height: UI.V2.cookModeTimerSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: UI.CookMode.titleInfoSpacing) {
                    Text(viewModel.timerDisplayText())
                        .font(UI.Fonts.timerDisplay)
                        .foregroundStyle(theme.text1)
                        .accessibilityLabel(String(format: Strings.Accessibility.timerRemaining, viewModel.timerDisplayText()))
                    Text(Strings.CookMode.timerRemaining)
                        .font(UI.Fonts.tinyCaption)
                        .foregroundStyle(theme.text2)
                        .accessibilityHidden(true)
                }
            }

            Button {
                viewModel.toggleTimer()
            } label: {
                HStack(spacing: UI.CookMode.timerButtonSpacing) {
                    Image(systemName: viewModel.timerRunning ? Icons.CookMode.pause : Icons.CookMode.play)
                    Text(viewModel.timerRunning ? Strings.CookMode.pause : Strings.CookMode.startTimer)
                        .font(UI.Fonts.bodySemibold)
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, UI.CookMode.timerButtonHorizontalPadding)
                .padding(.vertical, UI.CookMode.timerButtonVerticalPadding)
                .background(theme.accentSoft, in: Capsule())
            }
        }
    }

    // MARK: - Feedback Overlay

    /// Full-screen semi-transparent overlay containing the post-cook feedback card.
    private var feedbackOverlay: some View {
        ZStack {
            Color.black.opacity(UI.CookMode.feedbackOverlayOpacity)
                .ignoresSafeArea()
            feedbackCard
                .padding(.horizontal, UI.CookMode.feedbackCardHorizontalPadding)
        }
        .accessibilityIdentifier(AccessibilityID.CookMode.feedbackOverlay)
    }

    private var feedbackCard: some View {
        VStack(spacing: UI.CookMode.feedbackCardSpacing) {
            Text(Strings.CookMode.howWasIt)
                .font(UI.Fonts.sectionTitle)
                .foregroundStyle(theme.text1)
            feedbackStars
            feedbackButtons
        }
        .padding(UI.CookMode.feedbackCardPadding)
        .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadiusXL))
    }

    private var feedbackStars: some View {
        HStack(spacing: UI.CookMode.feedbackStarSpacing) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    viewModel.feedbackRating = star
                } label: {
                    Image(systemName: star <= viewModel.feedbackRating ? "star.fill" : "star")
                        .font(.system(size: UI.CookMode.feedbackStarSize))
                        .foregroundStyle(star <= viewModel.feedbackRating ? theme.gold : theme.text3)
                }
                .animation(UI.Anim.springDefault, value: viewModel.feedbackRating)
                .accessibilityIdentifier(AccessibilityID.CookMode.star(star - 1))
            }
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: UI.CookMode.feedbackButtonSpacing) {
            Button { viewModel.skipFeedback() } label: {
                Text(Strings.CookMode.skipRating)
                    .font(UI.Fonts.bodySemibold)
                    .foregroundStyle(theme.text2)
                    .frame(maxWidth: .infinity)
                    .frame(height: UI.CookMode.feedbackButtonHeight)
                    .background(theme.surface, in: Capsule())
            }
            .accessibilityIdentifier(AccessibilityID.CookMode.skipRating)
            Button { viewModel.submitFeedback() } label: {
                Text(Strings.CookMode.submit)
                    .font(UI.Fonts.buttonLabel)
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: UI.CookMode.feedbackButtonHeight)
                    .background(
                        LinearGradient(colors: [theme.accent, theme.rose], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .accessibilityIdentifier(AccessibilityID.CookMode.submitButton)
        }
    }

    // MARK: - Navigation Buttons

    /// Prev / Next / Finish navigation row at the bottom of the screen.
    private var navigationButtons: some View {
        HStack(spacing: UI.CookMode.navigationSpacing) {
            Button {
                withAnimation(UI.Anim.springNav) {
                    viewModel.goPrevious()
                }
            } label: {
                Image(systemName: Icons.CookMode.previous)
                    .font(UI.Fonts.iconBold)
                    .foregroundStyle(!viewModel.isFirstStep ? theme.text1 : theme.text3)
                    .frame(width: UI.CookMode.navigationButtonSize, height: UI.CookMode.navigationButtonSize)
                    .background(theme.surface, in: Circle())
            }
            .disabled(viewModel.isFirstStep)
            .accessibilityIdentifier(AccessibilityID.CookMode.previousButton)
            .accessibilityLabel(Strings.Accessibility.previousStep)

            Button {
                withAnimation(UI.Anim.springDefault) {
                    if viewModel.isLastStep {
                        viewModel.finish()
                    } else {
                        viewModel.markDone()
                    }
                }
            } label: {
                HStack(spacing: UI.CookMode.doneButtonSpacing) {
                    Image(systemName: viewModel.completedSteps.contains(viewModel.currentStep)
                          ? "checkmark.circle.fill" : Icons.CookMode.checkmark)
                        .font(UI.Fonts.iconBold)
                    Text(viewModel.isLastStep ? Strings.CookMode.finish : Strings.CookMode.done)
                        .font(UI.Fonts.buttonLabel)
                }
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: UI.CookMode.navigationButtonSize)
                .background(
                    LinearGradient(colors: [theme.accent, theme.rose], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .neonGlow(theme.accent, radius: UI.Common.neonRadiusSmall)
            }
            .accessibilityIdentifier(AccessibilityID.CookMode.doneButton)

            Button {
                withAnimation(UI.Anim.springNav) {
                    viewModel.goNext()
                }
            } label: {
                Image(systemName: Icons.CookMode.next)
                    .font(UI.Fonts.iconBold)
                    .foregroundStyle(!viewModel.isLastStep ? theme.text1 : theme.text3)
                    .frame(width: UI.CookMode.navigationButtonSize, height: UI.CookMode.navigationButtonSize)
                    .background(theme.surface, in: Circle())
            }
            .disabled(viewModel.isLastStep)
            .accessibilityIdentifier(AccessibilityID.CookMode.nextButton)
            .accessibilityLabel(Strings.Accessibility.nextStep)
        }
        .padding(.horizontal, UI.CookMode.horizontalPadding)
        .padding(.bottom, UI.CookMode.bottomPadding)
    }
}
