//
//  OnboardingViewModel.swift
//  CookSavvy
//

import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {

    struct Page {
        let title: String
        let subtitle: String
        let symbolName: String
    }

    let pages: [Page] = [
        Page(
            title: Strings.Onboarding.page1Title,
            subtitle: Strings.Onboarding.page1Subtitle,
            symbolName: "fork.knife.circle"
        ),
        Page(
            title: Strings.Onboarding.page2Title,
            subtitle: Strings.Onboarding.page2Subtitle,
            symbolName: "camera.viewfinder"
        ),
        Page(
            title: Strings.Onboarding.page3Title,
            subtitle: Strings.Onboarding.page3Subtitle,
            symbolName: "timer"
        )
    ]

    @Published var currentPage: Int = 0

    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func nextPage() {
        if currentPage < pages.count - 1 {
            currentPage += 1
        } else {
            complete()
        }
    }

    func skip() {
        complete()
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }
}
