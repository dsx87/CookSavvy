//
//  SettingsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(userDataService: UserDataService, dbInterface: DBInterfaceProtocol) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                userDataService: userDataService,
                dbInterface: dbInterface
            )
        )
    }

    /// Convenience init for testing
    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                // Subscription Plan Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentPlan.displayName)
                                .font(.headline)
                            Text(viewModel.currentPlan.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if viewModel.currentPlan == .free {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("Subscription Plan")
                }

                // Database Statistics Section
                Section {
                    HStack {
                        Text("Total Recipes")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Favorite Recipes")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.favoriteCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Recent Recipes")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(viewModel.recentRecipeCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Statistics")
                }

                // Data Management Section
                Section {
                    Button(role: .destructive) {
                        viewModel.showClearRecentAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Recent Data")
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.recentRecipeCount == 0)

                    Button(role: .destructive) {
                        viewModel.showClearFavoritesAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Favorites")
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.favoriteCount == 0)
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Clearing data cannot be undone")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadSettings()
            }
            .refreshable {
                await viewModel.loadSettings()
            }
            .alert("Clear Recent Data?", isPresented: $viewModel.showClearRecentAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await viewModel.clearRecentData()
                    }
                }
            } message: {
                Text("This will clear all recent ingredients, recipes, and searches. This action cannot be undone.")
            }
            .alert("Clear Favorites?", isPresented: $viewModel.showClearFavoritesAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await viewModel.clearFavorites()
                    }
                }
            } message: {
                Text("This will remove all favorited recipes. This action cannot be undone.")
            }
        }
    }
}

#Preview {
    let dbInterface = DBInterface()
    return SettingsView(
        userDataService: UserDataService(dbInterface: dbInterface),
        dbInterface: dbInterface
    )
}
