//
//  AppContainerLifecycleTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

@MainActor
final class AppContainerLifecycleTests: XCTestCase {

    func testHandleSceneBecameActiveRefreshesSubscription() async throws {
        let container = try AppContainer.makeInMemory()
        let subscription = try XCTUnwrap(container.subscriptionService as? MockSubscriptionService)

        XCTAssertEqual(subscription.refreshCallCount, 0)
        await container.handleSceneBecameActive()
        XCTAssertEqual(subscription.refreshCallCount, 1)
    }
}
