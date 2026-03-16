//
//  ShoppingListViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

@MainActor
final class ShoppingListViewModelTests: XCTestCase {

    var mockService: MockShoppingListService!

    override func setUp() {
        super.setUp()
        mockService = MockShoppingListService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    private func makeViewModel() -> ShoppingListViewModel {
        ShoppingListViewModel(
            shoppingListService: mockService,
            onDismiss: {}
        )
    }

    func testLoadPopulatesItems() async {
        mockService.seed(names: ["Butter", "Milk"], recipeTitle: "Cake")
        let vm = makeViewModel()
        // Wait for init Task { await loadItems() } to complete
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertEqual(vm.items[0].name, "Butter")
    }

    func testToggleUpdatesState() async {
        mockService.seed(names: ["Egg"])
        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }

        let item = vm.items[0]
        XCTAssertFalse(item.isChecked)

        await vm.toggleItem(item)
        XCTAssertTrue(vm.items[0].isChecked)
    }

    func testRemoveRemovesFromArray() async {
        mockService.seed(names: ["Flour", "Sugar"])
        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }

        let item = vm.items[0]
        await vm.removeItem(item)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertFalse(vm.items.contains { $0.id == item.id })
    }

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
}
