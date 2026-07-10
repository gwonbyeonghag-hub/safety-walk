import SwiftUI
import StoreKit

/// Single-sheet paywall (WO-10). Presented only from the two gates (RA new-creation,
/// report export). Tone = "기록 도구", not marketing: navy primary, **no risk colors**, no
/// "unlimited/premium" hype. Shows the two Pro actions, both subscription options at
/// StoreKit `displayPrice` (never hard-coded), 구매 복원, and the reassurance that existing
/// records stay viewable after expiry. Terms/Privacy come from `LegalLinks`.
struct PaywallView: View {

    @Environment(ProStore.self) private var proStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    reassurance
                    productOptions
                    restoreButton
                    legalLinks
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(LocalizationKey.paywallClose.localized)
                        .accessibilityIdentifier("paywall_close")
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundStyle(.tint)              // navy — app/brand, not a risk color
                .accessibilityHidden(true)
            Text(LocalizationKey.paywallTitle.localized)
                .font(.largeTitle.weight(.bold))
            Text(LocalizationKey.paywallTagline.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Benefits (the two gated actions, stated plainly)

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("square.and.pencil", LocalizationKey.paywallBenefitAssessment.localized)
            benefitRow("square.and.arrow.up", LocalizationKey.paywallBenefitExport.localized)
        }
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text).font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private var reassurance: some View {
        Text(LocalizationKey.paywallReassurance.localized)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Subscription options (prices from StoreKit displayPrice)

    @ViewBuilder
    private var productOptions: some View {
        if proStore.products.isEmpty {
            Text(LocalizationKey.paywallUnavailable.localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 12) {
                if let monthly = proStore.monthly {
                    productButton(monthly, label: LocalizationKey.paywallMonthly.localized)
                }
                if let yearly = proStore.yearly {
                    productButton(yearly, label: LocalizationKey.paywallYearly.localized)
                }
            }
        }
    }

    private func productButton(_ product: Product, label: String) -> some View {
        Button {
            Task { if await proStore.purchase(product) { dismiss() } }
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text(product.displayPrice).monospacedDigit()
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.borderedProminent)   // navy primary
        .disabled(proStore.isPurchasing)
        .accessibilityIdentifier("paywall_buy_\(product.id.hasSuffix(".yearly") ? "yearly" : "monthly")")
    }

    // MARK: - Restore + legal

    private var restoreButton: some View {
        Button {
            Task { await proStore.restore(); if proStore.isPro { dismiss() } }
        } label: {
            Text(LocalizationKey.paywallRestore.localized)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .disabled(proStore.isPurchasing)
        .accessibilityIdentifier("paywall_restore")
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            legalLink(LocalizationKey.paywallTerms.localized, url: LegalLinks.terms)
            legalLink(LocalizationKey.paywallPrivacy.localized, url: LegalLinks.privacy)
            Spacer(minLength: 0)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func legalLink(_ title: String, url: URL?) -> some View {
        if let url {
            Link(title, destination: url).foregroundStyle(.tint)
        } else {
            // Placeholder until the owner sets LegalLinks (WO-6) — never a dead link.
            Text(title).foregroundStyle(.tertiary)
        }
    }
}
