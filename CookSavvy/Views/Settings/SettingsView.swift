//
//  SettingsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
            List {
                // Subscription Plan Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: UI.Settings.planInfoSpacing) {
                            Text(viewModel.currentPlan.displayName)
                                .font(.headline)
                            Text(viewModel.currentPlan.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: Icons.Settings.planCheckmark)
                            .foregroundColor(.green)
                    }
                    
                    if viewModel.currentPlan != .ai {
                        Button {
                            viewModel.showUpgrade()
                        } label: {
                            HStack {
                                Image(systemName: Icons.Settings.crown)
                                    .foregroundColor(.yellow)
                                Text(Strings.Settings.upgradePlan)
                                Spacer()
                                Image(systemName: Icons.Settings.chevronRight)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(Strings.Settings.subscriptionHeader)
                }
                
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.localSourceEnabled },
                        set: { _ in viewModel.toggleLocalSource() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.Settings.localRecipes)
                            Text(Strings.Settings.offlineDatabase)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.apiSourceEnabled },
                        set: { _ in viewModel.toggleApiSource() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.Settings.onlineRecipes)
                            Text(Strings.Settings.apiSource)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!viewModel.canAccessSource(.online))
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.aiSourceEnabled },
                        set: { _ in viewModel.toggleAiSource() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.Settings.aiRecipes)
                            Text(Strings.Settings.aiGeneratedRecipes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!viewModel.canAccessSource(.ai))
                } header: {
                    Text(Strings.Settings.recipeSourcesHeader)
                } footer: {
                    Text(Strings.Settings.recipeSourcesFooter)
                }

                // Database Statistics Section
                Section {
                    HStack {
                        Text(Strings.Settings.totalRecipes)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(Strings.Settings.favoriteRecipes)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.favoriteCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(Strings.Settings.recentRecipes)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recentRecipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(Strings.Settings.statisticsHeader)
                }

                // Data Management Section
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

                // App Info Section
                Section {
                    HStack {
                        Text(Strings.Settings.versionLabel)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(Strings.Settings.buildLabel)
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(Strings.Settings.appInfoHeader)
                }
            }
            .navigationTitle(Strings.Settings.navigationTitle)
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
    }
}

#Preview {
    let dbInterface = DBInterface()
    return SettingsView(
        viewModel: SettingsViewModel(
            userDataService: UserDataService(dbInterface: dbInterface),
            dbInterface: dbInterface,
            subscriptionService: MockSubscriptionService(),
            coordinator: nil
        )
    )
}
