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
            if viewModel.isAuthAvailable {
                accountSection
            }
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
                Task { await viewModel.clearRecentData() }
            }
        } message: {
            Text(Strings.Settings.clearRecentAlertMessage)
        }
        .alert(Strings.Settings.clearFavoritesAlertTitle, isPresented: $viewModel.showClearFavoritesAlert) {
            Button(Strings.Common.cancel, role: .cancel) { }
            Button(Strings.Settings.alertClear, role: .destructive) {
                Task { await viewModel.clearFavorites() }
            }
        } message: {
            Text(Strings.Settings.clearFavoritesAlertMessage)
        }
        .alert(Strings.Settings.restoreFailed, isPresented: restoreErrorBinding) {
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
        .alert(Strings.Auth.signOutConfirmTitle, isPresented: $viewModel.showSignOutConfirmation) {
            Button(Strings.Common.cancel, role: .cancel) { }
            Button(Strings.Auth.signOut, role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } message: {
            Text(Strings.Auth.signOutConfirmMessage)
        }
    }

    // MARK: - Alert Bindings

    private var restoreErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.restoreError != nil },
            set: { if !$0 { viewModel.restoreError = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            if viewModel.isSignedInWithApple {
                signedInAccountContent
            } else {
                signInRow
            }
        } header: {
            Text(Strings.Auth.accountHeader)
        } footer: {
            if viewModel.isAnonymous {
                Text(Strings.Auth.signInSubtitle)
            }
        }
    }

    private var signInRow: some View {
        Button {
            Task { await viewModel.signInWithApple() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: Icons.Auth.applelogo)
                    .font(.title3)
                Text(viewModel.isSigningIn ? Strings.Auth.signingIn : Strings.Auth.signInWithApple)
                    .font(UI.Fonts.bodySemibold)
                Spacer()
                if viewModel.isSigningIn {
                    ProgressView()
                }
            }
            .frame(height: UI.Auth.signInButtonHeight)
        }
        .disabled(viewModel.isSigningIn)
    }

    @ViewBuilder private var signedInAccountContent: some View {
        HStack(spacing: 12) {
            Image(systemName: Icons.Auth.checkmarkShield)
                .font(.title3)
                .foregroundStyle(theme.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.Auth.signedInAs)
                    .font(UI.Fonts.bodySemibold)
                if let userId = viewModel.currentUserId {
                    Text(userId)
                        .font(UI.Fonts.caption)
                        .foregroundStyle(theme.text2)
                        .lineLimit(1)
                }
            }
        }

        Button(role: .destructive) {
            viewModel.showSignOutConfirmation = true
        } label: {
            Label(Strings.Auth.signOut, systemImage: Icons.Auth.signOut)
        }
    }

    // MARK: - Appearance

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
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.inline)
        } header: {
            Text(Strings.Settings.appearanceHeader)
        } footer: {
            Text(Strings.Settings.appearanceFooter)
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section {
            planInfoRow
            if viewModel.currentPlan != .premium {
                upgradeRow
            }
            restorePurchasesRow
            manageSubscriptionRow
        } header: {
            Text(Strings.Settings.subscriptionHeader)
        }
    }

    private var planInfoRow: some View {
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
    }

    private var upgradeRow: some View {
        Button { viewModel.showUpgrade() } label: {
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

    private var restorePurchasesRow: some View {
        Button {
            Task { await viewModel.restorePurchases() }
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
    }

    private var manageSubscriptionRow: some View {
        Button { viewModel.openManageSubscriptions() } label: {
            HStack {
                Text(Strings.Settings.manageSubscription)
                Spacer()
                Image(systemName: Icons.Settings.manageSubscription)
                    .foregroundStyle(theme.text3)
            }
        }
    }

    // MARK: - Dietary

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

    // MARK: - Stats

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

    // MARK: - Data Management

    private var dataManagementSection: some View {
        Section {
            clearRecentRow
            clearFavoritesRow
        } header: {
            Text(Strings.Settings.dataManagementHeader)
        } footer: {
            Text(Strings.Settings.dataManagementFooter)
        }
    }

    private var clearRecentRow: some View {
        Button(role: .destructive) {
            viewModel.showClearRecentAlert = true
        } label: {
            Label(Strings.Settings.clearRecentButton, systemImage: Icons.Settings.trash)
        }
        .disabled(viewModel.isLoading || viewModel.recentRecipeCount == 0)
        .accessibilityIdentifier(AccessibilityID.Settings.clearRecent)
    }

    private var clearFavoritesRow: some View {
        Button(role: .destructive) {
            viewModel.showClearFavoritesAlert = true
        } label: {
            Label(Strings.Settings.clearFavoritesButton, systemImage: Icons.Settings.trash)
        }
        .disabled(viewModel.isLoading || viewModel.favoriteCount == 0)
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        Section {
            infoRow(label: Strings.Settings.versionLabel, value: viewModel.appVersion)
                .accessibilityIdentifier(AccessibilityID.Settings.versionLabel)
            infoRow(label: Strings.Settings.buildLabel, value: viewModel.buildNumber)
        } header: {
            Text(Strings.Settings.appInfoHeader)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(theme.text2)
        }
    }
}

#if DEBUG
#Preview {
    if let dbInterface = try? DBInterface() {
        let authService = MockAuthService(initialState: .signedIn(userId: "mock-user"))
        let analyticsService = MockAnalyticsService()
        SettingsView(
            viewModel: SettingsViewModel(
                userDataService: UserDataService(dbInterface: dbInterface),
                dbInterface: dbInterface,
                subscriptionService: MockSubscriptionService(),
                dietaryPreferences: DietaryPreferences(),
                authService: authService,
                analyticsService: analyticsService,
                signInWithAppleAction: SignInWithAppleAction(
                    authService: authService,
                    analyticsService: analyticsService,
                    logger: LoggingService().makeLogger(category: .authService),
                    appleSignInManager: MockAppleSignInManager()
                ),
                logger: LoggingService().makeLogger(category: .settingsViewModel),
                coordinator: nil
            )
        )
    }
}
#endif
