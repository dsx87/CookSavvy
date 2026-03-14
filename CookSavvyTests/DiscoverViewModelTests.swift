import XCTest
@testable import CookSavvy

final class RecipeSourceTypeTests: XCTestCase {

    func testAccessibleRemovesPremiumSourcesWithoutAccess() {
        let result = RecipeSourceType.accessible(
            from: [.offline, .online, .ai],
            canAccessOnline: false,
            canAccessAI: false
        )

        XCTAssertEqual(result, [.offline])
    }

    func testAccessibleKeepsGrantedPremiumSources() {
        let result = RecipeSourceType.accessible(
            from: [.offline, .online, .ai],
            canAccessOnline: true,
            canAccessAI: false
        )

        XCTAssertEqual(result, [.offline, .online])
    }

    func testRequiresDatabaseReadyOnlyForOfflineOnly() {
        XCTAssertTrue(RecipeSourceType.requiresDatabaseReady([.offline]))
        XCTAssertFalse(RecipeSourceType.requiresDatabaseReady([.offline, .online]))
        XCTAssertFalse(RecipeSourceType.requiresDatabaseReady([.online]))
    }
}
