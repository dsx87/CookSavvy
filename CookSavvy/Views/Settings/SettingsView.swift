//
//  SettingsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
            List {
                appearanceSection
                subscriptionSection
                dietarySection
                statsSection
                dataManagementSection
                appInfoSection
            }
            .navigationTitle(Strings.Settings.navigationTitle)
            .tint(theme.accent)
            .task {
                await viewModel.loadSettings()
            }
            .refreshable {
                await viewModel.loadSettings()
            }
            .alert(Strings.Settings.clearRecentAlertTitle, isPresented: $viewModel.showClearRecentAlert) {
                Button(Strings.Common.cancel, role: .cancel) { }
                Button(Strings.Settings.alertClear, role: .destructive) {
                    Task {
                        await viewModel.clearRecentData()
                    }
                }
            } message: {
                Text(Strings.Settings.clearRecentAlertMessage)
            }
            .alert(Strings.Settings.clearFavoritesAlertTitle, isPresented: $viewModel.showClearFavoritesAlert) {
                Button(Strings.Common.cancel, role: .cancel) { }
                Button(Strings.Settings.alertClear, role: .destructive) {
                    Task {
                        await viewModel.clearFavorites()
                    }
                }
            } message: {
                Text(Strings.Settings.clearFavoritesAlertMessage)
            }
            .alert(Strings.Settings.restoreFailed, isPresented: .init(
                get: { viewModel.restoreError != nil },
                set: { if !$0 { viewModel.restoreError = nil } }
            )) {
                Button(Strings.Common.ok, role: .cancel) { }
            } message: {
                Text(viewModel.restoreError ?? "")
            }
            .alert(Strings.Errors.errorAlertTitle, isPresented: errorBinding) {
                Button(Strings.Common.ok, role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissError()
                }
            }
        )
    }

    private var appearanceSection: some View {
        Section {
            Picker(
                Strings.Settings.appearancePickerLabel,
                selection: Binding(
                    get: { viewModel.themePreference },
                    set: { viewModel.updateThemePreference($0) }
                )
            ) {
                ForEach(ThemePreference.allCases) { preference in
                    Text(preference.displayName)
                        .tag(preference)
                }
            }
            .pickerStyle(.inline)
        } header: {
            Text(Strings.Settings.appearanceHeader)
        } footer: {
            Text(Strings.Settings.appearanceFooter)
        }
    }

    private var subscriptionSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: UI.Settings.planInfoSpacing) {
                    Text(viewModel.currentPlan.displayName)
                        .font(.headline)
                    Text(viewModel.currentPlan.description)
                        .font(.caption)
                        .foregroundStyle(theme.text2)
                }
                Spacer()
                Image(systemName: Icons.Settings.planCheckmark)
                    .foregroundStyle(theme.mint)
            }
            .accessibilityIdentifier(AccessibilityID.Settings.subscriptionSection)

            if viewModel.currentPlan != .premium {
                Button {
                    viewModel.showUpgrade()
                } label: {
                    HStack {
                        Image(systemName: Icons.Settings.crown)
                            .foregroundStyle(theme.gold)
                        Text(Strings.Settings.upgradePlan)
                        Spacer()
                        Image(systemName: Icons.Settings.chevronRight)
                            .foregroundStyle(theme.text3)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Settings.upgradeButton)
            }

            Button {
                Task {
                    await viewModel.restorePurchases()
                }
            } label: {
                HStack {
                    Text(Strings.Settings.restorePurchases)
                    Spacer()
                    if viewModel.isRestoringPurchases {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isRestoringPurchases)

            Button {
                viewModel.openManageSubscriptions()
            } label: {
                HStack {
                    Text(Strings.Settings.manageSubscription)
                    Spacer()
                    Image(systemName: Icons.Settings.manageSubscription)
                        .foregroundStyle(theme.text3)
                }
            }
        } header: {
            Text(Strings.Settings.subscriptionHeader)
        }
    }

    private var dietarySection: some View {
        Section {
            ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                Toggle(isOn: Binding(
                    get: { viewModel.isDietaryRestrictionActive(restriction) },
                    set: { _ in viewModel.toggleDietaryRestriction(restriction) }
                )) {
                    Label(restriction.displayName, systemImage: restriction.icon)
                }
            }
        } header: {
            Text(Strings.Dietary.sectionTitle)
        } footer: {
            Text(Strings.Dietary.sectionFooter)
        }
    }

    private var statsSection: some View {
        Section {
            statRow(label: Strings.Settings.totalRecipes, value: viewModel.recipeCount)
            statRow(label: Strings.Settings.favoriteRecipes, value: viewModel.favoriteCount)
            statRow(label: Strings.Settings.recentRecipes, value: viewModel.recentRecipeCount)
        } header: {
            Text(Strings.Settings.statisticsHeader)
        }
    }

    private func statRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            if viewModel.isLoading {
                ProgressView()
            } else {
                Text("\(value)")
                    .foregroundStyle(theme.text2)
            }
        }
    }

    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showClearRecentAlert = true
            } label: {
                HStack {
                    Image(systemName: Icons.Settings.trash)
                    Text(Strings.Settings.clearRecentButton)
                }
            }
            .disabled(viewModel.isLoading || viewModel.recentRecipeCount == 0)
            .accessibilityIdentifier(AccessibilityID.Settings.clearRecent)

            Button(role: .destructive) {
                viewModel.showClearFavoritesAlert = true
            } label: {
                HStack {
                    Image(systemName: Icons.Settings.trash)
                    Text(Strings.Settings.clearFavoritesButton)
                }
            }
            .disabled(viewModel.isLoading || viewModel.favoriteCount == 0)
        } header: {
            Text(Strings.Settings.dataManagementHeader)
        } footer: {
            Text(Strings.Settings.dataManagementFooter)
        }
    }

    private var appInfoSection: some View {
        Section {
            HStack {
                Text(Strings.Settings.versionLabel)
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundStyle(theme.text2)
            }
            .accessibilityIdentifier(AccessibilityID.Settings.versionLabel)

            HStack {
                Text(Strings.Settings.buildLabel)
                Spacer()
                Text(viewModel.buildNumber)
                    .foregroundStyle(theme.text2)
            }
        } header: {
            Text(Strings.Settings.appInfoHeader)
        }
    }
}

#Preview {
    let dbInterface = DBInterface()
    return SettingsView(
        viewModel: SettingsViewModel(
            userDataService: UserDataService(dbInterface: dbInterface),
            dbInterface: dbInterface,
            subscriptionService: MockSubscriptionService(),
            dietaryPreferences: DietaryPreferences(),
            logger: LoggingService().makeLogger(category: .settingsViewModel),
            coordinator: nil
        )
    )
}
