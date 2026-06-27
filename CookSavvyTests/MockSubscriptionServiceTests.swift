import XCTest
@testable import CookSavvy

final class MockSubscriptionServiceTests: XCTestCase {

    private var analyticsService: MockAnalyticsService!
    private var sut: MockSubscriptionService!

    @MainActor
    override func setUp() async throws {
        analyticsService = MockAnalyticsService()
        sut = MockSubscriptionService(analyticsService: analyticsService)
    }

    @MainActor
    override func tearDown() async throws {
        sut = nil
        analyticsService = nil
    }

    @MainActor
    func testMonthlyTrialPurchaseTracksTrialStarted() async throws {
        try await sut.purchase(.monthly)

        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.trialStarted])
        XCTAssertEqual(analyticsService.trackedEvents.first?.1["product_id"], PremiumSubscriptionOption.monthly.productIdentifier)
    }

    @MainActor
    func testTransitionFromTrialToPaidTracksTrialConverted() async {
        sut.setSubscriptionStatus(
            .premium(
                option: .monthly,
                isEligibleForMonthlyTrial: false,
                isOnFreeTrial: true,
                trialExpirationDate: Date()
            )
        )
        analyticsService.trackedEvents.removeAll()

        sut.setSubscriptionStatus(.premium(option: .monthly))

        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.trialConverted])
        XCTAssertEqual(analyticsService.trackedEvents.first?.1["product_id"], PremiumSubscriptionOption.monthly.productIdentifier)
    }

    @MainActor
    func testTransitionFromTrialToFreeTracksTrialExpired() async {
        sut.setSubscriptionStatus(
            .premium(
                option: .monthly,
                isEligibleForMonthlyTrial: false,
                isOnFreeTrial: true,
                trialExpirationDate: Date()
            )
        )
        analyticsService.trackedEvents.removeAll()

        sut.setSubscriptionStatus(.free())

        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.trialExpired])
        XCTAssertEqual(analyticsService.trackedEvents.first?.1["product_id"], PremiumSubscriptionOption.monthly.productIdentifier)
    }
}
