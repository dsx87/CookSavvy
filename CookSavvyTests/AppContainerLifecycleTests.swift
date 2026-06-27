//
//  AppContainerLifecycleTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class AppContainerLifecycleTests: XCTestCase {

    @MainActor
    func testHandleSceneBecameActiveRefreshesSubscription() async throws {
        let container = try AppContainer.makeInMemory()
        let subscription = try XCTUnwrap(container.subscriptionService as? MockSubscriptionService)

        XCTAssertEqual(subscription.refreshCallCount, 0)
        await container.handleSceneBecameActive()
        XCTAssertEqual(subscription.refreshCallCount, 1)
    }

    @MainActor
    func testMakeInMemoryProvidesMockSubstitutionService() async throws {
        let container = try AppContainer.makeInMemory()
        XCTAssertTrue(container.substitutionService is MockSubstitutionService)
    }
}
