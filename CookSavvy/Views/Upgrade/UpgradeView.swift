//
//  UpgradeView.swift
//  CookSavvy
//

import SwiftUI

struct UpgradeView: View {
    @ObservedObject var viewModel: UpgradeViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: UI.Upgrade.headerSpacing) {
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
        VStack(spacing: UI.Upgrade.headerInnerSpacing) {
            Image(systemName: Icons.Upgrade.crown)
                .font(.system(size: UI.Upgrade.headerIconSize))
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
        VStack(alignment: .leading, spacing: UI.Upgrade.contentSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: UI.Upgrade.planCardSpacing) {
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
                        .padding(.horizontal, UI.Upgrade.currentBadgePaddingH)
                        .padding(.vertical, UI.Upgrade.currentBadgePaddingV)
                        .background(Color.green.opacity(UI.Upgrade.currentBadgeBgOpacity))
                        .cornerRadius(UI.Upgrade.currentBadgeCornerRadius)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: UI.Upgrade.featureSpacing) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: UI.Upgrade.featureSpacing) {
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
                    .cornerRadius(UI.Upgrade.subscribeCornerRadius)
                }
                .disabled(isLoading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(UI.Upgrade.cardCornerRadius)
        .shadow(color: .black.opacity(UI.Upgrade.shadowOpacity), radius: UI.Upgrade.shadowRadius, x: 0, y: UI.Upgrade.shadowY)
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
