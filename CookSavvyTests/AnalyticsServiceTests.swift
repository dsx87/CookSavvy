import XCTest
@testable import CookSavvy

final class AnalyticsServiceTests: XCTestCase {

    var mockService: MockAnalyticsService!

    @MainActor
    override func setUp() async throws {
        mockService = MockAnalyticsService()
    }

    @MainActor
    override func tearDown() async throws {
        mockService = nil
    }

    @MainActor
    func testTrackEventWithNoProperties() async {
        mockService.track(.recipeSearchPerformed)

        XCTAssertEqual(mockService.trackedEvents.count, 1)
        XCTAssertEqual(mockService.trackedEvents[0].0, .recipeSearchPerformed)
        XCTAssertTrue(mockService.trackedEvents[0].1.isEmpty)
    }

    @MainActor
    func testTrackEventWithProperties() async {
        mockService.track(.recipeSearchPerformed, properties: ["sources": "offline", "ingredientCount": "3"])

        XCTAssertEqual(mockService.trackedEvents.count, 1)
        XCTAssertEqual(mockService.trackedEvents[0].0, .recipeSearchPerformed)
        XCTAssertEqual(mockService.trackedEvents[0].1["sources"], "offline")
        XCTAssertEqual(mockService.trackedEvents[0].1["ingredientCount"], "3")
    }

    @MainActor
    func testTrackMultipleEvents() async {
        mockService.track(.onboardingCompleted)
        mockService.track(.recipeViewed)
        mockService.track(.recipeCooked)

        XCTAssertEqual(mockService.trackedEvents.count, 3)
        XCTAssertEqual(mockService.trackedEvents[0].0, .onboardingCompleted)
        XCTAssertEqual(mockService.trackedEvents[1].0, .recipeViewed)
        XCTAssertEqual(mockService.trackedEvents[2].0, .recipeCooked)
    }

    @MainActor
    func testAllEventsHaveRawValues() async {
        let events: [AnalyticsEvent] = [
            .appOpened, .onboardingCompleted, .onboardingSkipped,
            .onboardingCameraScanCompleted, .onboardingTypeInsteadTapped,
            .cameraScanStarted, .recipeSearchPerformed, .recipeViewed,
            .recipeFavorited, .recipeCooked, .upgradeScreenViewed,
            .upgradePurchased, .upgradeDismissed, .trialStarted,
            .trialConverted, .trialExpired, .scanLimitHit,
            .anonymousAuthCompleted, .signInWithAppleStarted,
            .signInWithAppleCompleted, .signInWithAppleFailed,
            .signOutCompleted
        ]
        for event in events {
            XCTAssertFalse(event.rawValue.isEmpty)
        }
    }
}
