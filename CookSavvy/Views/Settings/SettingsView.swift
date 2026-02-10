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
                        Image(systemName: UI.Settings.planCheckmarkIcon)
                            .foregroundColor(.green)
                    }
                    
                    if viewModel.currentPlan != .ai {
                        Button {
                            viewModel.showUpgrade()
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade Plan")
                                Spacer()
                                Image(systemName: "chevron.right")
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
                            Text("Restore Purchases")
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
                            Text("Manage Subscription")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(UI.Settings.subscriptionHeaderTitle)
                }
                
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.localSourceEnabled },
                        set: { _ in viewModel.toggleLocalSource() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local Recipes")
                            Text("Offline database")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.apiSourceEnabled },
                        set: { _ in viewModel.toggleApiSource() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Online Recipes")
                            Text("API source")
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
                            Text("AI Recipes")
                            Text("AI-generated recipes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!viewModel.canAccessSource(.ai))
                } header: {
                    Text("Recipe Sources")
                } footer: {
                    Text("Select which sources to use when searching for recipes. At least one source must be enabled.")
                }

                // Database Statistics Section
                Section {
                    HStack {
                        Text(UI.Settings.totalRecipesLabel)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(UI.Settings.favoriteRecipesLabel)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.favoriteCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(UI.Settings.recentRecipesLabel)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recentRecipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(UI.Settings.statisticsHeaderTitle)
                }

                // Data Management Section
                Section {
                    Button(role: .destructive) {
                        viewModel.showClearRecentAlert = true
                    } label: {
                        HStack {
                            Image(systemName: UI.Settings.trashIcon)
                            Text(UI.Settings.clearRecentButtonTitle)
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.recentRecipeCount == 0)

                    Button(role: .destructive) {
                        viewModel.showClearFavoritesAlert = true
                    } label: {
                        HStack {
                            Image(systemName: UI.Settings.trashIcon)
                            Text(UI.Settings.clearFavoritesButtonTitle)
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.favoriteCount == 0)
                } header: {
                    Text(UI.Settings.dataManagementHeaderTitle)
                } footer: {
                    Text(UI.Settings.dataManagementFooterText)
                }

                // App Info Section
                Section {
                    HStack {
                        Text(UI.Settings.versionLabel)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(UI.Settings.buildLabel)
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(UI.Settings.appInfoHeaderTitle)
                }
            }
            .navigationTitle(UI.Settings.navigationTitle)
            .task {
                await viewModel.loadSettings()
            }
            .refreshable {
                await viewModel.loadSettings()
            }
            .alert(UI.Settings.clearRecentAlertTitle, isPresented: $viewModel.showClearRecentAlert) {
                Button(UI.Settings.alertCancelTitle, role: .cancel) { }
                Button(UI.Settings.alertClearTitle, role: .destructive) {
                    Task {
                        await viewModel.clearRecentData()
                    }
                }
            } message: {
                Text(UI.Settings.clearRecentAlertMessage)
            }
            .alert(UI.Settings.clearFavoritesAlertTitle, isPresented: $viewModel.showClearFavoritesAlert) {
                Button(UI.Settings.alertCancelTitle, role: .cancel) { }
                Button(UI.Settings.alertClearTitle, role: .destructive) {
                    Task {
                        await viewModel.clearFavorites()
                    }
                }
            } message: {
                Text(UI.Settings.clearFavoritesAlertMessage)
            }
            .alert("Restore Failed", isPresented: .init(
                get: { viewModel.restoreError != nil },
                set: { if !$0 { viewModel.restoreError = nil } }
            )) {
                Button("OK", role: .cancel) { }
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
