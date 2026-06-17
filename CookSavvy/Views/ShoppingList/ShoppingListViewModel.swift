//
//  ShoppingListViewModel.swift
//  CookSavvy
//

import Foundation
import Observation

/// ViewModel backing the Shopping List sheet (premium feature).
///
/// Maintains a flat list of `ShoppingItem` values and a grouped view for display.
/// Supports toggling checked state, swipe-to-delete, and clearing all completed items.
/// All mutations are persisted immediately via `ShoppingListServiceProtocol`.
@Observable final class ShoppingListViewModel {
    // MARK: - Observable State

    /// All shopping items; used as the source of truth for `groupedItems`.
    var items: [ShoppingItem] = []
    /// `true` while items are being loaded from the service.
    var isLoading = false
    /// Non-`nil` when any action fails; drives the error alert.
    var errorMessage: String?

    // MARK: - Computed

    /// Items grouped by recipe title, with recipe-less items last; within each group sorted by add date.
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

    /// `true` when at least one item is checked (enabling the "Clear Done" button).
    var hasCompletedItems: Bool { items.contains { $0.isChecked } }

    // MARK: - Private

    private let shoppingListService: ShoppingListServiceProtocol
    private let logger: any LoggerProtocol
    private let onDismiss: () -> Void

    // MARK: - Init

    /// Creates the shopping list view model and immediately loads persisted items.
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

    /// Fetches all shopping items from the service, replacing the current list.
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

    /// Toggles the checked state of an item and persists the change.
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

    /// Deletes an item from the list and the persistence layer.
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

    /// Removes all checked items from both the list and the persistence layer.
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

    /// Returns a VoiceOver label for the item's checkbox: "Check <name>" or "Uncheck <name>".
    func checkboxAccessibilityLabel(for item: ShoppingItem) -> String {
        item.isChecked
            ? String(format: Strings.Accessibility.uncheckItem, item.name)
            : String(format: Strings.Accessibility.checkItem, item.name)
    }

    /// Dismisses the shopping list sheet.
    func dismiss() {
        onDismiss()
    }

    /// Clears the currently displayed error message.
    func dismissError() {
        errorMessage = nil
    }
}
