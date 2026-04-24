//
//  UpgradeViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

@MainActor
final class UpgradeViewModelTests: XCTestCase {

    private var sut: UpgradeViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = UpgradeViewModel(
            subscriptionService: MockSubscriptionService(),
            analyticsService: MockAnalyticsService(),
            onDismiss: {}
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    func testPremiumFeatureDescriptionsUseOutcomeCopy() {
        XCTAssertEqual(
            sut.featureDescription(for: .premium),
            [
                "Scan your fridge in seconds",
                "Never miss an ingredient",
                "Build shopping lists from missing items",
                "Get smarter dinner suggestions"
            ]
        )
    }

    func testVisibleUpgradeOutcomeCopyAvoidsTechnicalSellingTerms() {
        let visibleCopy = ([Strings.Upgrade.unlockSubtitle] + sut.featureDescription(for: .premium))
            .joined(separator: " ")
            .lowercased()

        for forbiddenTerm in ["ai", "api", "source", "sources"] {
            XCTAssertFalse(
                visibleCopy.contains(forbiddenTerm),
                "Upgrade outcome copy should not include technical term: \(forbiddenTerm)"
            )
        }
    }
}
