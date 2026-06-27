//
//  ShoppingListViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class ShoppingListViewModelTests: XCTestCase {

    var mockService: MockShoppingListService!

    @MainActor
    override func setUp() async throws {
        mockService = MockShoppingListService()
    }

    @MainActor
    override func tearDown() async throws {
        mockService = nil
    }

    @MainActor
    private func makeViewModel() -> ShoppingListViewModel {
        ShoppingListViewModel(
            shoppingListService: mockService,
            logger: MockLogger(),
            onDismiss: {}
        )
    }

    @MainActor
    func testLoadPopulatesItems() async {
        mockService.seed(names: ["Butter", "Milk"], recipeTitle: "Cake")
        let vm = makeViewModel()
        // Wait for init Task { await loadItems() } to complete
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertEqual(vm.items[0].name, "Butter")
    }

    @MainActor
    func testToggleUpdatesState() async {
        mockService.seed(names: ["Egg"])
        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }

        let item = vm.items[0]
        XCTAssertFalse(item.isChecked)

        await vm.toggleItem(item)
        XCTAssertTrue(vm.items[0].isChecked)
    }

    @MainActor
    func testRemoveRemovesFromArray() async {
        mockService.seed(names: ["Flour", "Sugar"])
        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }

        let item = vm.items[0]
        await vm.removeItem(item)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertFalse(vm.items.contains { $0.id == item.id })
    }

    @MainActor
    func testClearCompleted() async {
        mockService.seed(names: ["Apple", "Banana"])
        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }

        // Toggle first item to checked
        await vm.toggleItem(vm.items[0])
        XCTAssertTrue(vm.hasCompletedItems)

        await vm.clearCompleted()
        XCTAssertFalse(vm.hasCompletedItems)
        XCTAssertEqual(vm.items.count, 1)
    }

    @MainActor
    func testLoadSetsErrorMessageWhenFetchingItemsFails() async {
        mockService.shouldThrow = TestError.stub

        let vm = makeViewModel()
        await vm.loadItems()

        XCTAssertEqual(vm.errorMessage, Strings.Errors.shoppingListLoadFailed)
    }

    @MainActor
    func testToggleSetsErrorMessageWhenUpdateFails() async {
        mockService.seed(names: ["Egg"])
        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }
        mockService.shouldThrow = TestError.stub

        await vm.toggleItem(vm.items[0])

        XCTAssertEqual(vm.errorMessage, Strings.Errors.shoppingListActionFailed)
    }
}

private enum TestError: Error {
    case stub
}
