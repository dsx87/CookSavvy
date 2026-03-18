//
//  UpgradeView.swift
//  CookSavvy
//

import SwiftUI

struct UpgradeView: View {
    @ObservedObject var viewModel: UpgradeViewModel
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: UI.Upgrade.headerSpacing) {
                headerView
                
                ForEach(viewModel.availablePlans, id: \.self) { plan in
                    planCard(for: plan)
                }
                
                Text(Strings.Upgrade.autoRenew)
                    .font(.caption)
                    .foregroundStyle(theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .background(theme.bg)
        .navigationTitle(Strings.Upgrade.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(Strings.Upgrade.done) {
                    viewModel.dismiss()
                }
            }
        }
        .task {
            viewModel.trackScreenViewed()
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
                .foregroundStyle(theme.text2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private func planCard(for plan: SubscriptionPlan) -> some View {
        let card = PlanCard(
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

        if plan == .premium {
            return AnyView(card.accessibilityIdentifier(AccessibilityID.Upgrade.premiumPlan))
        }

        return AnyView(card)
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let features: [String]
    let priceText: String
    let isCurrentPlan: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: UI.Upgrade.contentSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: UI.Upgrade.planCardSpacing) {
                    Text(plan.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.text1)
                    
                    Text(priceText)
                        .font(.subheadline)
                        .foregroundStyle(theme.text2)
                }
                
                Spacer()
                
                if isCurrentPlan {
                    Text(Strings.Upgrade.current)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.mint)
                        .padding(.horizontal, UI.Upgrade.currentBadgePaddingH)
                        .padding(.vertical, UI.Upgrade.currentBadgePaddingV)
                        .background(theme.mintSoft)
                        .cornerRadius(UI.Upgrade.currentBadgeCornerRadius)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: UI.Upgrade.featureSpacing) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: UI.Upgrade.featureSpacing) {
                        Image(systemName: Icons.Upgrade.checkmark)
                            .foregroundStyle(theme.mint)
                            .font(.subheadline)
                        Text(feature)
                            .font(.subheadline)
                            .foregroundStyle(theme.text1)
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
                    .background(
                        LinearGradient(
                            colors: [theme.accent, theme.sky],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: UI.Upgrade.subscribeCornerRadius, style: .continuous)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: UI.Upgrade.subscribeCornerRadius, style: .continuous))
                }
                .disabled(isLoading)
                .accessibilityIdentifier(AccessibilityID.Upgrade.subscribeButton)
            }
        }
        .padding()
        .background(theme.card)
        .cornerRadius(UI.Upgrade.cardCornerRadius)
        .shadow(color: .black.opacity(UI.Upgrade.shadowOpacity), radius: UI.Upgrade.shadowRadius, x: 0, y: UI.Upgrade.shadowY)
    }
    
}

#Preview {
    UpgradeView(
        viewModel: UpgradeViewModel(
            subscriptionService: MockSubscriptionService(),
            analyticsService: MockAnalyticsService(),
            onDismiss: {}
        )
    )
}
