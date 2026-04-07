import XCTest
@testable import CookSavvy

final class AnalyticsServiceTests: XCTestCase {

    var mockService: MockAnalyticsService!

    override func setUp() {
        super.setUp()
        mockService = MockAnalyticsService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    func testTrackEventWithNoProperties() {
        mockService.track(.recipeSearchPerformed)

        XCTAssertEqual(mockService.trackedEvents.count, 1)
        XCTAssertEqual(mockService.trackedEvents[0].0, .recipeSearchPerformed)
        XCTAssertTrue(mockService.trackedEvents[0].1.isEmpty)
    }

    func testTrackEventWithProperties() {
        mockService.track(.recipeSearchPerformed, properties: ["sources": "offline", "ingredientCount": "3"])

        XCTAssertEqual(mockService.trackedEvents.count, 1)
        XCTAssertEqual(mockService.trackedEvents[0].0, .recipeSearchPerformed)
        XCTAssertEqual(mockService.trackedEvents[0].1["sources"], "offline")
        XCTAssertEqual(mockService.trackedEvents[0].1["ingredientCount"], "3")
    }

    func testTrackMultipleEvents() {
        mockService.track(.onboardingCompleted)
        mockService.track(.recipeViewed)
        mockService.track(.recipeCooked)

        XCTAssertEqual(mockService.trackedEvents.count, 3)
        XCTAssertEqual(mockService.trackedEvents[0].0, .onboardingCompleted)
        XCTAssertEqual(mockService.trackedEvents[1].0, .recipeViewed)
        XCTAssertEqual(mockService.trackedEvents[2].0, .recipeCooked)
    }

    func testAllEventsHaveRawValues() {
        let events: [AnalyticsEvent] = [
            .appOpened, .onboardingCompleted, .onboardingSkipped,
            .onboardingCameraScanCompleted, .onboardingTypeInsteadTapped,
            .cameraScanStarted, .recipeSearchPerformed, .recipeViewed,
            .recipeFavorited, .recipeCooked, .upgradeScreenViewed,
            .upgradePurchased, .upgradeDismissed, .scanLimitHit
        ]
        for event in events {
            XCTAssertFalse(event.rawValue.isEmpty)
        }
    }
}
