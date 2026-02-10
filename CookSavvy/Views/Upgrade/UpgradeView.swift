//
//  UpgradeView.swift
//  CookSavvy
//

import SwiftUI

struct UpgradeView: View {
    @ObservedObject var viewModel: UpgradeViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                ForEach(viewModel.availablePlans, id: \.self) { plan in
                    PlanCard(
                        plan: plan,
                        features: viewModel.featureDescription(for: plan),
                        priceText: viewModel.priceText(for: plan),
                        isCurrentPlan: viewModel.currentPlan == plan,
                        isLoading: viewModel.isLoading,
                        onSelect: {
                            Task {
                                await viewModel.purchase(plan)
                            }
                        }
                    )
                }
                
                Text(Strings.Upgrade.autoRenew)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(Strings.Upgrade.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(Strings.Upgrade.done) {
                    viewModel.dismiss()
                }
            }
        }
        .task {
            await viewModel.loadPrices()
        }
        .alert(Strings.Upgrade.purchaseFailed, isPresented: $viewModel.showErrorAlert) {
            Button(Strings.Common.ok, role: .cancel) { }
        } message: {
            Text(viewModel.purchaseError ?? Strings.Upgrade.unknownError)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: Icons.Upgrade.crown)
                .font(.system(size: 50))
                .foregroundStyle(.yellow.gradient)
            
            Text(Strings.Upgrade.unlockTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(Strings.Upgrade.unlockSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let features: [String]
    let priceText: String
    let isCurrentPlan: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(priceText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isCurrentPlan {
                    Text(Strings.Upgrade.current)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: Icons.Upgrade.checkmark)
                            .foregroundColor(.green)
                            .font(.subheadline)
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }
            
            if !isCurrentPlan {
                Button {
                    onSelect()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(Strings.Upgrade.subscribe)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(plan == .ai ? Color.purple : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
}

#Preview {
    UpgradeView(
        viewModel: UpgradeViewModel(
            subscriptionService: MockSubscriptionService(),
            onDismiss: {}
        )
    )
}
