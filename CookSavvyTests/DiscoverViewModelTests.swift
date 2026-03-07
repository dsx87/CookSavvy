import XCTest
@testable import CookSavvy

@MainActor
final class DiscoverViewModelTests: XCTestCase {

    func testFilteredEnabledSourcesRemovesPremiumSourcesWithoutAccess() {
        let filtered = DiscoverViewModel.filteredEnabledSources(
            [.offline, .online, .ai],
            canAccessOnline: false,
            canAccessAI: false
        )

        XCTAssertEqual(filtered, [.offline])
    }

    func testFilteredEnabledSourcesKeepsAccessiblePremiumSources() {
        let filtered = DiscoverViewModel.filteredEnabledSources(
            [.offline, .online, .ai],
            canAccessOnline: true,
            canAccessAI: false
        )

        XCTAssertEqual(filtered, [.offline, .online])
    }

    func testShouldWaitForRecipeImportOnlyForOfflineOnlySearches() {
        XCTAssertTrue(DiscoverViewModel.shouldWaitForRecipeImport(for: [.offline]))
        XCTAssertFalse(DiscoverViewModel.shouldWaitForRecipeImport(for: [.offline, .online]))
        XCTAssertFalse(DiscoverViewModel.shouldWaitForRecipeImport(for: [.online]))
    }
}
