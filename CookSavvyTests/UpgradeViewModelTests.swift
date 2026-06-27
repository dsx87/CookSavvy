//
//  UpgradeViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class UpgradeViewModelTests: XCTestCase {

    private var sut: UpgradeViewModel!
    private var subscriptionService: MockSubscriptionService!
    private var analyticsService: MockAnalyticsService!
    private var didDismiss = false

    @MainActor
    override func setUp() async throws {
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

    @MainActor
    override func tearDown() async throws {
        sut = nil
        subscriptionService = nil
        analyticsService = nil
    }

    @MainActor
    func testAvailableOptionsPromoteAnnualBeforeMonthly() async {
        XCTAssertEqual(sut.availableOptions, [.yearly, .monthly])
    }

    @MainActor
    func testLoadPricesLoadsMonthlyAndYearlyPrices() async {
        await sut.loadPrices()

        XCTAssertEqual(sut.priceByOption[.monthly], "$4.99")
        XCTAssertEqual(sut.priceByOption[.yearly], "$39.99")
    }

    @MainActor
    func testPriceTextFormatsMonthlyAndYearlyBillingPeriods() async {
        await sut.loadPrices()

        XCTAssertEqual(sut.priceText(for: .monthly), "7 days free, then $4.99/month")
        XCTAssertEqual(sut.priceText(for: .yearly), "$39.99/year")
    }

    @MainActor
    func testAnnualSavingsUsesTwelveMonthlyPayments() async throws {
        await sut.loadPrices()

        let savings = try XCTUnwrap(sut.annualSavingsAmount())
        XCTAssertEqual(NSDecimalNumber(decimal: savings), NSDecimalNumber(string: "19.89"))
        XCTAssertEqual(sut.savingsText(for: .yearly), "Save $19.89 per year")
    }

    @MainActor
    func testAnnualSavingsPreservesLocalizedDecimalSeparator() async {
        subscriptionService.priceByOption[.monthly] = "4,99 €"
        subscriptionService.priceByOption[.yearly] = "39,99 €"
        subscriptionService.priceAmountByOption[.monthly] = Decimal(string: "4.99") ?? .zero
        subscriptionService.priceAmountByOption[.yearly] = Decimal(string: "39.99") ?? .zero

        await sut.loadPrices()

        XCTAssertEqual(sut.savingsText(for: .yearly), "Save 19,89 € per year")
    }

    @MainActor
    func testPurchasingMonthlyGrantsPremium() async {
        await sut.purchase(.monthly)

        XCTAssertEqual(subscriptionService.currentPlan, .premium)
        XCTAssertTrue(subscriptionService.currentSubscriptionStatus.isOnFreeTrial)
        XCTAssertTrue(didDismiss)
    }

    @MainActor
    func testPurchasingYearlyGrantsPremium() async {
        await sut.purchase(.yearly)

        XCTAssertEqual(subscriptionService.currentPlan, .premium)
        XCTAssertTrue(didDismiss)
    }

    @MainActor
    func testPurchasingMonthlyTracksUpgradePurchasedWithProductId() async {
        await sut.purchase(.monthly)

        let purchaseEvents = analyticsService.trackedEvents.filter { $0.0 == .upgradePurchased }
        XCTAssertEqual(purchaseEvents.count, 1)
        XCTAssertEqual(purchaseEvents.first?.1, ["product_id": PremiumSubscriptionOption.monthly.productIdentifier])
    }

    @MainActor
    func testPurchasingYearlyTracksUpgradePurchasedWithProductId() async {
        await sut.purchase(.yearly)

        let purchaseEvents = analyticsService.trackedEvents.filter { $0.0 == .upgradePurchased }
        XCTAssertEqual(purchaseEvents.count, 1)
        XCTAssertEqual(purchaseEvents.first?.1, ["product_id": PremiumSubscriptionOption.yearly.productIdentifier])
    }

    @MainActor
    func testProductIdentifierMappingTreatsBothProductsAsPremium() async {
        XCTAssertEqual(
            PremiumSubscriptionOption.option(for: "com.cooksavvy.subscription.premium")?.associatedPlan,
            .premium
        )
        XCTAssertEqual(
            PremiumSubscriptionOption.option(for: "com.cooksavvy.subscription.premium.yearly")?.associatedPlan,
            .premium
        )
    }

    @MainActor
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

    @MainActor
    func testPremiumFeatureDescriptionsUseOutcomeCopy() async {
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

    @MainActor
    func testVisibleUpgradeOutcomeCopyAvoidsTechnicalSellingTerms() async {
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

    @MainActor
    func testEligibleMonthlyCardUsesTrialCTA() async {
        XCTAssertEqual(sut.purchaseButtonText(for: .monthly), Strings.Upgrade.tryFreeForSevenDays)
        XCTAssertEqual(sut.optionBadgeText(for: .monthly), Strings.Upgrade.freeTrialBadge)
    }

    @MainActor
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

    @MainActor
    func testRestorePurchasesSuccessCallsServiceAndClearsError() async {
        await sut.restorePurchases()

        XCTAssertEqual(subscriptionService.restoreCallCount, 1)
        XCTAssertNil(sut.restoreError)
        XCTAssertFalse(sut.isRestoringPurchases)
    }

    @MainActor
    func testRestorePurchasesFailureSetsRestoreError() async {
        subscriptionService.restorePurchasesError = SubscriptionError.noPurchasesToRestore

        await sut.restorePurchases()

        XCTAssertEqual(subscriptionService.restoreCallCount, 1)
        XCTAssertNotNil(sut.restoreError)
        XCTAssertFalse(sut.isRestoringPurchases)
    }
}
