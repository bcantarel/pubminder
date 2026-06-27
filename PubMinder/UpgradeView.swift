import SwiftUI
import StoreKit

// MARK: - UpgradeView
//
// Paywall sheet shown when a free-tier user tries to access preprint sources.
// Presents the premium feature list, the one-time price, a purchase button,
// and a "Restore Purchase" button (required by App Store guidelines).

struct UpgradeView: View {
    @EnvironmentObject var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Hero ─────────────────────────────────────────────
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("See more. Read smarter.")
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                        Text("One preprint subject is included free. Pro unlocks everything.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // ── Feature list ─────────────────────────────────────
                    VStack(spacing: 0) {
                        UpgradeFeatureRow(
                            icon: "square.grid.2x2.fill", color: .green,
                            title: "Unlimited preprint subjects",
                            detail: "bioRxiv, medRxiv, and arXiv — all fields, no limits"
                        )
                        Divider().padding(.leading, 52)
                        UpgradeFeatureRow(
                            icon: "brain.head.profile", color: .purple,
                            title: "AI summaries",
                            detail: "Every paper summarized on-device or via Groq"
                        )
                        Divider().padding(.leading, 52)
                        UpgradeFeatureRow(
                            icon: "bell.fill", color: .orange,
                            title: "Daily digest",
                            detail: "Your papers delivered at a time you choose"
                        )
                        Divider().padding(.leading, 52)
                        UpgradeFeatureRow(
                            icon: "checkmark.seal.fill", color: .blue,
                            title: "One-time purchase",
                            detail: "Pay once, yours forever — no subscription"
                        )
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // ── Purchase button ───────────────────────────────────
                    VStack(spacing: 12) {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            HStack(spacing: 8) {
                                if store.isWorking || store.isLoadingProducts {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "lock.open.fill")
                                }
                                if store.isLoadingProducts {
                                    Text("Loading…")
                                        .fontWeight(.semibold)
                                } else if let product = store.product {
                                    Text("Unlock for \(product.displayPrice)")
                                        .fontWeight(.semibold)
                                } else {
                                    Text("Tap to Retry")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(store.isWorking || store.isLoadingProducts)
                        .padding(.horizontal)

                        // Restore purchases (required by App Store guidelines)
                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchase")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(store.isWorking)

                        Text("One-time purchase. No subscription. Syncs across all your devices via iCloud.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase Issue", isPresented: Binding(
                get: { store.purchaseError != nil },
                set: { if !$0 { store.purchaseError = nil } }
            )) {
                Button("OK") { store.purchaseError = nil }
            } message: {
                Text(store.purchaseError ?? "")
            }
            // Auto-dismiss as soon as the purchase goes through
            .onChange(of: store.isPremium) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}

// MARK: - Feature row

private struct UpgradeFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    UpgradeView()
        .environmentObject(StoreKitManager())
}
