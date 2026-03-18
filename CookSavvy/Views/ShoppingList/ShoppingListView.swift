//
//  ShoppingListView.swift
//  CookSavvy
//

import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationView {
            content
                .navigationTitle(Strings.ShoppingList.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(Strings.Common.cancel) { viewModel.dismiss() }
                            .foregroundStyle(theme.accent)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if viewModel.hasCompletedItems {
                            Button(Strings.ShoppingList.clearDone) {
                                Task { await viewModel.clearCompleted() }
                            }
                            .foregroundStyle(theme.rose)
                            .font(UI.Fonts.captionSemibold)
                            .accessibilityIdentifier(AccessibilityID.ShoppingList.clearDone)
                        }
                    }
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.items.isEmpty {
            emptyState
        } else {
            itemsList
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        List {
            ForEach(viewModel.groupedItems, id: \.title) { group in
                Section(header: groupHeader(group.title)) {
                    ForEach(group.items, id: \.id) { item in
                        itemRow(item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
    }

    private func groupHeader(_ title: String?) -> some View {
        Group {
            if let title {
                Text(title)
                    .font(UI.Fonts.captionBold)
                    .foregroundStyle(theme.text2)
                    .textCase(nil)
            }
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: UI.ShoppingList.checkboxSpacing) {
            Button {
                Task { await viewModel.toggleItem(item) }
            } label: {
                Image(systemName: item.isChecked ? Icons.ShoppingList.checkCircleFill : Icons.ShoppingList.circle)
                    .font(UI.Fonts.iconSemibold)
                    .foregroundStyle(item.isChecked ? theme.mint : theme.text3)
                    .frame(width: UI.ShoppingList.checkboxSize, height: UI.ShoppingList.checkboxSize)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.ShoppingList.checkbox(item.name))
            .accessibilityLabel(viewModel.checkboxAccessibilityLabel(for: item))

            Text(item.name)
                .font(UI.Fonts.bodyScaled)
                .foregroundStyle(item.isChecked ? theme.text3 : theme.text1)
                .strikethrough(item.isChecked, color: theme.text3)
                .accessibilityHidden(true)
        }
        .padding(.vertical, UI.ShoppingList.rowVerticalPadding)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.removeItem(item) }
            } label: {
                Image(systemName: Icons.ShoppingList.trash)
            }
        }
        .accessibilityIdentifier(AccessibilityID.ShoppingList.item(item.name))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: UI.ShoppingList.emptyStateSpacing) {
            Image(systemName: Icons.ShoppingList.cart)
                .font(.system(size: UI.ShoppingList.emptyIconSize))
                .foregroundStyle(theme.text3)
            Text(Strings.ShoppingList.emptyTitle)
                .font(UI.Fonts.title)
                .foregroundStyle(theme.text1)
            Text(Strings.ShoppingList.emptySubtitle)
                .font(UI.Fonts.body)
                .foregroundStyle(theme.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, UI.ShoppingList.horizontalPadding)
        }
        .accessibilityIdentifier(AccessibilityID.ShoppingList.emptyState)
    }
}
