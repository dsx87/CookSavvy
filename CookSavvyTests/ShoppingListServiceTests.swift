//
//  ShoppingListServiceTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class ShoppingListServiceTests: XCTestCase {

    var db: DBInterface!
    var service: ShoppingListService!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        db = try DBInterface(inMemory: true)
        service = ShoppingListService(dbInterface: db)
    }

    @MainActor
    override func tearDown() async throws {
        service = nil
        db = nil
        try await super.tearDown()
    }

    @MainActor
    func testAddItemsWithRecipeTitle() async throws {
        let added = try await service.addItems(["Garlic", "Onion"], recipeTitle: "Pasta")
        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(added[0].name, "Garlic")
        XCTAssertEqual(added[0].recipeTitle, "Pasta")
        XCTAssertEqual(added[1].name, "Onion")
    }

    @MainActor
    func testAddItemsWithoutRecipeTitle() async throws {
        let added = try await service.addItems(["Salt"], recipeTitle: nil)
        XCTAssertEqual(added.count, 1)
        XCTAssertNil(added[0].recipeTitle)
    }

    @MainActor
    func testToggleItem() async throws {
        let added = try await service.addItems(["Butter"], recipeTitle: nil)
        let item = added[0]
        XCTAssertFalse(item.isChecked)

        let newState = try await service.toggleItem(item)
        XCTAssertTrue(newState)

        let items = try await service.getItems()
        XCTAssertTrue(items.first(where: { $0.id == item.id })?.isChecked == true)
    }

    @MainActor
    func testRemoveItem() async throws {
        let added = try await service.addItems(["Egg"], recipeTitle: nil)
        let item = added[0]

        try await service.removeItem(item)

        let items = try await service.getItems()
        XCTAssertTrue(items.isEmpty)
    }

    @MainActor
    func testClearCompleted() async throws {
        _ = try await service.addItems(["Apple", "Banana"], recipeTitle: nil)
        let allItems = try await service.getItems()

        // Check the first item
        _ = try await service.toggleItem(allItems[0])

        try await service.clearCompleted()

        let remaining = try await service.getItems()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertFalse(remaining[0].isChecked)
    }

    @MainActor
    func testClearCompletedWhenNoneChecked() async throws {
        _ = try await service.addItems(["Apple", "Banana"], recipeTitle: nil)

        try await service.clearCompleted()

        let remaining = try await service.getItems()
        XCTAssertEqual(remaining.count, 2)
    }

    @MainActor
    func testEmptyListOps() async throws {
        let items = try await service.getItems()
        XCTAssertTrue(items.isEmpty)

        // clearCompleted on empty list should not throw
        try await service.clearCompleted()
    }
}
