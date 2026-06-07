//
//  UpgradeViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

@MainActor
final class UpgradeViewModelTests: XCTestCase {

    private var sut: UpgradeViewModel!
    private var subscriptionService: MockSubscriptionService!
    private var analyticsService: MockAnalyticsService!
    private var didDismiss = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        subscriptionService = MockSubscriptionService()
        analyticsService = MockAnalyticsService()
        didDismiss = false
        sut = UpgradeViewModel(
            subscriptionService: subscriptionService,
            analyticsService: analyticsService,
            onDismiss: { [weak self] in
                self?.didDismiss = true
            }
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        subscriptionService = nil
        analyticsService = nil
        try super.tearDownWithError()
    }

    func testAvailableOptionsPromoteAnnualBeforeMonthly() {
        XCTAssertEqual(sut.availableOptions, [.yearly, .monthly])
    }

    func testLoadPricesLoadsMonthlyAndYearlyPrices() async {
        await sut.loadPrices()

        XCTAssertEqual(sut.priceByOption[.monthly], "$4.99")
        XCTAssertEqual(sut.priceByOption[.yearly], "$39.99")
    }

    func testPriceTextFormatsMonthlyAndYearlyBillingPeriods() async {
        await sut.loadPrices()

        XCTAssertEqual(sut.priceText(for: .monthly), "7 days free, then $4.99/month")
        XCTAssertEqual(sut.priceText(for: .yearly), "$39.99/year")
    }

    func testAnnualSavingsUsesTwelveMonthlyPayments() async throws {
        await sut.loadPrices()

        let savings = try XCTUnwrap(sut.annualSavingsAmount())
        XCTAssertEqual(NSDecimalNumber(decimal: savings), NSDecimalNumber(string: "19.89"))
        XCTAssertEqual(sut.savingsText(for: .yearly), "Save $19.89 per year")
    }

    func testAnnualSavingsPreservesLocalizedDecimalSeparator() async {
        subscriptionService.priceByOption[.monthly] = "4,99 €"
        subscriptionService.priceByOption[.yearly] = "39,99 €"
        subscriptionService.priceAmountByOption[.monthly] = Decimal(string: "4.99") ?? .zero
        subscriptionService.priceAmountByOption[.yearly] = Decimal(string: "39.99") ?? .zero

        await sut.loadPrices()

        XCTAssertEqual(sut.savingsText(for: .yearly), "Save 19,89 € per year")
    }

    func testPurchasingMonthlyGrantsPremium() async {
        await sut.purchase(.monthly)

        XCTAssertEqual(subscriptionService.currentPlan, .premium)
        XCTAssertTrue(subscriptionService.currentSubscriptionStatus.isOnFreeTrial)
        XCTAssertTrue(didDismiss)
    }

    func testPurchasingYearlyGrantsPremium() async {
        await sut.purchase(.yearly)

        XCTAssertEqual(subscriptionService.currentPlan, .premium)
        XCTAssertTrue(didDismiss)
    }

    func testProductIdentifierMappingTreatsBothProductsAsPremium() {
        XCTAssertEqual(
            PremiumSubscriptionOption.option(for: "com.cooksavvy.subscription.premium")?.associatedPlan,
            .premium
        )
        XCTAssertEqual(
            PremiumSubscriptionOption.option(for: "com.cooksavvy.subscription.premium.yearly")?.associatedPlan,
            .premium
        )
    }

    func testMockPricesMatchStoreKitConfiguration() async {
        let monthlyPrice = await subscriptionService.price(for: .monthly)
        let yearlyPrice = await subscriptionService.price(for: .yearly)
        let monthlyAmount = await subscriptionService.priceAmount(for: .monthly)
        let yearlyAmount = await subscriptionService.priceAmount(for: .yearly)

        XCTAssertEqual(monthlyPrice, "$4.99")
        XCTAssertEqual(yearlyPrice, "$39.99")
        XCTAssertEqual(monthlyAmount, Decimal(string: "4.99"))
        XCTAssertEqual(yearlyAmount, Decimal(string: "39.99"))
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
        let visibleCopy = ([Strings.Upgrade.trialEligibleSubtitle] + sut.featureDescription(for: .premium))
            .joined(separator: " ")
            .lowercased()

        for forbiddenTerm in ["ai", "api", "source", "sources"] {
            XCTAssertFalse(
                visibleCopy.contains(forbiddenTerm),
                "Upgrade outcome copy should not include technical term: \(forbiddenTerm)"
            )
        }
    }

    func testEligibleMonthlyCardUsesTrialCTA() {
        XCTAssertEqual(sut.purchaseButtonText(for: .monthly), Strings.Upgrade.tryFreeForSevenDays)
        XCTAssertEqual(sut.optionBadgeText(for: .monthly), Strings.Upgrade.freeTrialBadge)
    }

    func testActiveTrialUsesTrialHeaderAndBadge() async {
        let trialStatus = SubscriptionStatus.premium(
            option: .monthly,
            isEligibleForMonthlyTrial: false,
            isOnFreeTrial: true,
            trialExpirationDate: Date(timeIntervalSince1970: 1_800_000_000)
        )
        subscriptionService.setSubscriptionStatus(trialStatus)
        sut = UpgradeViewModel(
            subscriptionService: subscriptionService,
            analyticsService: analyticsService,
            onDismiss: {}
        )

        await sut.loadPrices()

        XCTAssertEqual(sut.headerSubtitle, Strings.Upgrade.trialActiveSubtitle)
        XCTAssertEqual(sut.currentBadgeText(for: .monthly), Strings.Upgrade.trialActive)
        XCTAssertEqual(
            sut.priceText(for: .monthly),
            "Free until \(trialStatus.formattedTrialEndDate ?? ""), then $4.99/month"
        )
    }

    // MARK: - Restore Purchases (paywall — Guideline 3.1.1)

    func testRestorePurchasesSuccessCallsServiceAndClearsError() async {
        await sut.restorePurchases()

        XCTAssertEqual(subscriptionService.restoreCallCount, 1)
        XCTAssertNil(sut.restoreError)
        XCTAssertFalse(sut.isRestoringPurchases)
    }

    func testRestorePurchasesFailureSetsRestoreError() async {
        subscriptionService.restorePurchasesError = SubscriptionError.noPurchasesToRestore

        await sut.restorePurchases()

        XCTAssertEqual(subscriptionService.restoreCallCount, 1)
        XCTAssertNotNil(sut.restoreError)
        XCTAssertFalse(sut.isRestoringPurchases)
    }
}
