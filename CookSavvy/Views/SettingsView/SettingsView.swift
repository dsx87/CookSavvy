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
                        VStack(alignment: .leading, spacing: UIConstants.settingsPlanInfoSpacing) {
                            Text(viewModel.currentPlan.displayName)
                                .font(.headline)
                            Text(viewModel.currentPlan.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if viewModel.currentPlan == .free {
                            Image(systemName: UIConstants.settingsPlanCheckmarkIconName)
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text(UIConstants.settingsSubscriptionHeaderTitle)
                }

                // Database Statistics Section
                Section {
                    HStack {
                        Text(UIConstants.settingsTotalRecipesLabel)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(UIConstants.settingsFavoriteRecipesLabel)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.favoriteCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(UIConstants.settingsRecentRecipesLabel)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recentRecipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(UIConstants.settingsStatisticsHeaderTitle)
                }

                // Data Management Section
                Section {
                    Button(role: .destructive) {
                        viewModel.showClearRecentAlert = true
                    } label: {
                        HStack {
                            Image(systemName: UIConstants.settingsTrashIconName)
                            Text(UIConstants.settingsClearRecentButtonTitle)
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.recentRecipeCount == 0)

                    Button(role: .destructive) {
                        viewModel.showClearFavoritesAlert = true
                    } label: {
                        HStack {
                            Image(systemName: UIConstants.settingsTrashIconName)
                            Text(UIConstants.settingsClearFavoritesButtonTitle)
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.favoriteCount == 0)
                } header: {
                    Text(UIConstants.settingsDataManagementHeaderTitle)
                } footer: {
                    Text(UIConstants.settingsDataManagementFooterText)
                }

                // App Info Section
                Section {
                    HStack {
                        Text(UIConstants.settingsVersionLabel)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(UIConstants.settingsBuildLabel)
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(UIConstants.settingsAppInfoHeaderTitle)
                }
            }
            .navigationTitle(UIConstants.settingsNavigationTitle)
            .task {
                await viewModel.loadSettings()
            }
            .refreshable {
                await viewModel.loadSettings()
            }
            .alert(UIConstants.settingsClearRecentAlertTitle, isPresented: $viewModel.showClearRecentAlert) {
                Button(UIConstants.settingsAlertCancelTitle, role: .cancel) { }
                Button(UIConstants.settingsAlertClearTitle, role: .destructive) {
                    Task {
                        await viewModel.clearRecentData()
                    }
                }
            } message: {
                Text(UIConstants.settingsClearRecentAlertMessage)
            }
            .alert(UIConstants.settingsClearFavoritesAlertTitle, isPresented: $viewModel.showClearFavoritesAlert) {
                Button(UIConstants.settingsAlertCancelTitle, role: .cancel) { }
                Button(UIConstants.settingsAlertClearTitle, role: .destructive) {
                    Task {
                        await viewModel.clearFavorites()
                    }
                }
            } message: {
                Text(UIConstants.settingsClearFavoritesAlertMessage)
            }
    }
}

#Preview {
    let dbInterface = DBInterface()
    return SettingsView(
        viewModel: SettingsViewModel(
            userDataService: UserDataService(dbInterface: dbInterface),
            dbInterface: dbInterface
        )
    )
}
