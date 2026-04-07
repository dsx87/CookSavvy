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
    @Published var errorMessage: String?

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
    private let logger: any LoggerProtocol
    private let onDismiss: () -> Void

    // MARK: - Init

    init(
        shoppingListService: ShoppingListServiceProtocol,
        logger: any LoggerProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.shoppingListService = shoppingListService
        self.logger = logger
        self.onDismiss = onDismiss
        Task { await loadItems() }
    }

    // MARK: - Public Methods

    func loadItems() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await shoppingListService.getItems()
        } catch {
            logger.error("Failed to load shopping items: \(String(describing: error))")
            errorMessage = Strings.Errors.shoppingListLoadFailed
        }
    }

    func toggleItem(_ item: ShoppingItem) async {
        errorMessage = nil
        do {
            let newState = try await shoppingListService.toggleItem(item)
            if let index = items.firstIndex(of: item) {
                items[index].isChecked = newState
            }
        } catch {
            logger.error("Failed to toggle shopping item: \(String(describing: error))")
            errorMessage = Strings.Errors.shoppingListActionFailed
        }
    }

    func removeItem(_ item: ShoppingItem) async {
        errorMessage = nil
        do {
            try await shoppingListService.removeItem(item)
            items.removeAll { $0.id == item.id }
        } catch {
            logger.error("Failed to remove shopping item: \(String(describing: error))")
            errorMessage = Strings.Errors.shoppingListActionFailed
        }
    }

    func clearCompleted() async {
        errorMessage = nil
        do {
            try await shoppingListService.clearCompleted()
            items.removeAll { $0.isChecked }
        } catch {
            logger.error("Failed to clear completed shopping items: \(String(describing: error))")
            errorMessage = Strings.Errors.shoppingListActionFailed
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

    func dismissError() {
        errorMessage = nil
    }
}
