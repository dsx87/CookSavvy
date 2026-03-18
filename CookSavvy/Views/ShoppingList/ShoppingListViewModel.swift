//
//  ShoppingListViewModel.swift
//  CookSavvy
//

import Foundation

@MainActor
final class ShoppingListViewModel: ObservableObject {

    // MARK: - Published

    @Published var items: [ShoppingItem] = []
    @Published var isLoading = false

    // MARK: - Computed

    var groupedItems: [(title: String?, items: [ShoppingItem])] {
        var groups: [String?: [ShoppingItem]] = [:]
        for item in items {
            groups[item.recipeTitle, default: []].append(item)
        }
        return groups
            .sorted { lhs, rhs in
                switch (lhs.key, rhs.key) {
                case (nil, _): return false
                case (_, nil): return true
                case (let a?, let b?): return a < b
                }
            }
            .map { ($0.key, $0.value.sorted { $0.addedAt < $1.addedAt }) }
    }

    var hasCompletedItems: Bool { items.contains { $0.isChecked } }

    // MARK: - Private

    private let shoppingListService: ShoppingListServiceProtocol
    private let onDismiss: () -> Void

    // MARK: - Init

    init(shoppingListService: ShoppingListServiceProtocol, onDismiss: @escaping () -> Void) {
        self.shoppingListService = shoppingListService
        self.onDismiss = onDismiss
        Task { await loadItems() }
    }

    // MARK: - Public Methods

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await shoppingListService.getItems()
        } catch {
            print("❌ Failed to load shopping items: \(error)")
        }
    }

    func toggleItem(_ item: ShoppingItem) async {
        do {
            let newState = try await shoppingListService.toggleItem(item)
            if let index = items.firstIndex(of: item) {
                items[index].isChecked = newState
            }
        } catch {
            print("❌ Failed to toggle shopping item: \(error)")
        }
    }

    func removeItem(_ item: ShoppingItem) async {
        do {
            try await shoppingListService.removeItem(item)
            items.removeAll { $0.id == item.id }
        } catch {
            print("❌ Failed to remove shopping item: \(error)")
        }
    }

    func clearCompleted() async {
        do {
            try await shoppingListService.clearCompleted()
            items.removeAll { $0.isChecked }
        } catch {
            print("❌ Failed to clear completed items: \(error)")
        }
    }

    func checkboxAccessibilityLabel(for item: ShoppingItem) -> String {
        item.isChecked
            ? String(format: Strings.Accessibility.uncheckItem, item.name)
            : String(format: Strings.Accessibility.checkItem, item.name)
    }

    func dismiss() {
        onDismiss()
    }
}
