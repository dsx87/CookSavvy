//
//  UpgradeView.swift
//  CookSavvy
//

import SwiftUI

/// Concrete paywall view implementation hosting plan cards and purchase CTA.
struct UpgradeView: View {
    @ObservedObject var viewModel: UpgradeViewModel
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: UI.Upgrade.headerSpacing) {
                headerView
                
                ForEach(viewModel.availableOptions, id: \.self) { option in
                    planCard(for: option)
                }
                
                restoreButton

                Text(Strings.Upgrade.autoRenew)
                    .font(.caption)
                    .foregroundStyle(theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                legalLinks
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
        .alert(Strings.Settings.restoreFailed, isPresented: restoreErrorBinding) {
            Button(Strings.Common.ok, role: .cancel) { }
        } message: {
            Text(viewModel.restoreError ?? Strings.Upgrade.unknownError)
        }
    }

    /// Drives the restore-failure alert from the view model's optional `restoreError`.
    private var restoreErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.restoreError != nil },
            set: { if !$0 { viewModel.restoreError = nil } }
        )
    }

    /// "Restore Purchases" action required on the paywall (Guideline 3.1.1).
    private var restoreButton: some View {
        Button {
            Task { await viewModel.restorePurchases() }
        } label: {
            if viewModel.isRestoringPurchases {
                ProgressView()
            } else {
                Text(Strings.Settings.restorePurchases)
                    .font(.subheadline)
            }
        }
        .disabled(viewModel.isRestoringPurchases)
    }

    /// Terms of Use + Privacy Policy links shown at the point of sale (Guideline 3.1.2).
    private var legalLinks: some View {
        HStack(spacing: UI.Upgrade.headerInnerSpacing) {
            Button(Strings.Legal.termsOfUse) { viewModel.openTermsOfUse() }
            Text("•")
                .foregroundStyle(theme.text3)
            Button(Strings.Legal.privacyPolicy) { viewModel.openPrivacyPolicy() }
        }
        .font(.caption)
    }
    
    /// Builds a plan card wired to the view model purchase action and accessibility ids.
    private func planCard(for option: PremiumSubscriptionOption) -> some View {
        PlanCard(
            plan: option.associatedPlan,
            optionTitle: viewModel.optionTitle(for: option),
            badgeText: viewModel.optionBadgeText(for: option),
            features: viewModel.featureDescription(for: option.associatedPlan),
            priceText: viewModel.priceText(for: option),
            savingsText: viewModel.savingsText(for: option),
            isPromoted: option.isPromoted,
            currentBadgeText: viewModel.currentBadgeText(for: option),
            isLoading: viewModel.isLoading,
            subscribeButtonID: subscribeButtonID(for: option),
            buttonTitle: viewModel.purchaseButtonText(for: option),
            onSelect: {
                Task {
                    await viewModel.purchase(option)
                }
            }
        )
        .accessibilityIdentifier(planAccessibilityID(for: option))
    }

    private var headerView: some View {
        VStack(spacing: UI.Upgrade.headerInnerSpacing) {
            Image(systemName: Icons.Upgrade.crown)
                .font(.system(size: UI.Upgrade.headerIconSize))
                .foregroundStyle(.yellow.gradient)
            
            Text(Strings.Upgrade.unlockTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(viewModel.headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(theme.text2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private func planAccessibilityID(for option: PremiumSubscriptionOption) -> String {
        switch option {
        case .yearly:
            return AccessibilityID.Upgrade.premiumPlan
        case .monthly:
            return AccessibilityID.Upgrade.monthlyPlan
        }
    }

    private func subscribeButtonID(for option: PremiumSubscriptionOption) -> String {
        switch option {
        case .yearly:
            return AccessibilityID.Upgrade.subscribeButton
        case .monthly:
            return AccessibilityID.Upgrade.monthlySubscribeButton
        }
    }
}

/// Reusable visual card representing one subscription plan on the upgrade screen.
struct PlanCard: View {
    let plan: SubscriptionPlan
    let optionTitle: String
    let badgeText: String?
    let features: [String]
    let priceText: String
    let savingsText: String?
    let isPromoted: Bool
    let currentBadgeText: String?
    let isLoading: Bool
    let subscribeButtonID: String
    let buttonTitle: String
    let onSelect: () -> Void
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: UI.Upgrade.contentSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: UI.Upgrade.planCardSpacing) {
                    HStack(spacing: UI.Common.mediumSpacing) {
                        Text(plan.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.text1)

                        if let badgeText {
                            Text(badgeText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, UI.Upgrade.promotedBadgePaddingH)
                                .padding(.vertical, UI.Upgrade.promotedBadgePaddingV)
                                .background(theme.accentSoft)
                                .cornerRadius(UI.Upgrade.promotedBadgeCornerRadius)
                        }
                    }
                    
                    Text(optionTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.text2)

                    Text(priceText)
                        .font(.subheadline)
                        .foregroundStyle(theme.text2)
                }
                
                Spacer()
                
                if let currentBadgeText {
                    Text(currentBadgeText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.mint)
                        .padding(.horizontal, UI.Upgrade.currentBadgePaddingH)
                        .padding(.vertical, UI.Upgrade.currentBadgePaddingV)
                        .background(theme.mintSoft)
                        .cornerRadius(UI.Upgrade.currentBadgeCornerRadius)
                }
            }

            if let savingsText {
                Text(savingsText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.mint)
                    .padding(.horizontal, UI.Upgrade.savingsPaddingH)
                    .padding(.vertical, UI.Upgrade.savingsPaddingV)
                    .background(theme.mintSoft)
                    .cornerRadius(UI.Upgrade.savingsCornerRadius)
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
            
            if currentBadgeText == nil {
                Button {
                    onSelect()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(buttonTitle)
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
                .accessibilityIdentifier(subscribeButtonID)
            }
        }
        .padding()
        .background(theme.card)
        .cornerRadius(UI.Upgrade.cardCornerRadius)
        .overlay {
            if isPromoted {
                RoundedRectangle(cornerRadius: UI.Upgrade.cardCornerRadius, style: .continuous)
                    .stroke(theme.accent, lineWidth: UI.Upgrade.promotedBorderWidth)
            }
        }
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
