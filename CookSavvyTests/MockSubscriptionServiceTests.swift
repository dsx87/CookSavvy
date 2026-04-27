import XCTest
@testable import CookSavvy

@MainActor
final class MockSubscriptionServiceTests: XCTestCase {

    private var analyticsService: MockAnalyticsService!
    private var sut: MockSubscriptionService!

    override func setUp() {
        super.setUp()
        analyticsService = MockAnalyticsService()
        sut = MockSubscriptionService(analyticsService: analyticsService)
    }

    override func tearDown() {
        sut = nil
        analyticsService = nil
        super.tearDown()
    }

    func testMonthlyTrialPurchaseTracksTrialStarted() async throws {
        try await sut.purchase(.monthly)

        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.trialStarted])
        XCTAssertEqual(analyticsService.trackedEvents.first?.1["product_id"], PremiumSubscriptionOption.monthly.productIdentifier)
    }

    func testTransitionFromTrialToPaidTracksTrialConverted() {
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

    func testTransitionFromTrialToFreeTracksTrialExpired() {
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
