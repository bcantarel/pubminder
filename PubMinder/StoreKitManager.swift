import StoreKit
import SwiftUI

// MARK: - StoreKitManager
//
// Manages the single non-consumable IAP that unlocks preprint sources
// (bioRxiv, medRxiv, arXiv). PubMed search remains free.
//
// Product ID: com.pubminder.preprints
// You must register this exact string in App Store Connect →
// Your App → In-App Purchases → Create → Non-Consumable.
//
// Usage:
//   1. Add as @StateObject in PubMinderApp, inject via .environmentObject(store)
//   2. Read store.isPremium to gate premium UI / feeds
//   3. Call store.purchase() from the upgrade sheet's buy button
//   4. Call store.restorePurchases() from the restore button

@MainActor
final class StoreKitManager: ObservableObject {

    // The product ID must exactly match what you enter in App Store Connect.
    nonisolated static let premiumProductID = "com.pubminder.preprints"

    // MARK: Published state

    /// True once a verified, non-expired purchase has been confirmed.
    @Published private(set) var isPremium: Bool = false

    /// The StoreKit Product loaded from App Store Connect.
    /// nil until loadProducts() completes (or if the product isn't found).
    @Published private(set) var product: Product?

    /// Set when a purchase or restore call fails. Cleared before each new attempt.
    @Published var purchaseError: String?

    /// True while a purchase or restore is in flight.
    @Published private(set) var isWorking: Bool = false

    /// True while the product list is being fetched from the App Store.
    @Published private(set) var isLoadingProducts: Bool = false

    // MARK: Private

    private var transactionListener: Task<Void, Error>?

    // MARK: Init / deinit

    init() {
        // Start listening for transactions BEFORE anything else so we never miss
        // a purchase that completes outside the app (e.g. family sharing, Ask-to-Buy).
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchaseStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    /// Load the premium product from the App Store.
    /// Called automatically on init; can be called again to retry on failure.
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            product = products.first
            if product == nil {
                purchaseError = "Product not found in App Store. Check your internet connection and try again."
            }
        } catch {
            purchaseError = "Could not load product: \(error.localizedDescription)"
        }
    }

    /// Initiate a purchase of the premium unlock.
    func purchase() async {
        if product == nil {
            await loadProducts()
        }
        guard let product else { return }
        purchaseError = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // Set isPremium immediately from the verified transaction rather than
                // waiting for updatePurchaseStatus(), which queries currentEntitlements —
                // that async sequence can lag briefly after a fresh purchase and would
                // reset isPremium to false before the entitlement propagates.
                isPremium = true
                await transaction.finish()
            case .userCancelled:
                break   // User dismissed the sheet — nothing to do
            case .pending:
                // Ask-to-Buy, parental controls, or payment method issue —
                // the transaction will arrive via the listener when approved.
                purchaseError = "Your purchase is pending. You'll receive a notification when it's approved."
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Restore previously purchased products (required by App Store guidelines).
    /// Calls AppStore.sync() which reconciles the receipt and fires Transaction.updates.
    func restorePurchases() async {
        purchaseError = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await updatePurchaseStatus()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    /// Walk currentEntitlements and set isPremium if a valid purchase is found.
    func updatePurchaseStatus() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumProductID,
               transaction.revocationDate == nil {
                found = true
                break
            }
        }
        isPremium = found
    }

    /// Runs in the background for the app's lifetime; handles any transaction update
    /// (renewal, refund revocation, family sharing grant, etc.).
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    if transaction.productID == StoreKitManager.premiumProductID {
                        if transaction.revocationDate == nil {
                            // Active entitlement: set isPremium directly without scanning
                            // currentEntitlements, which can lag behind a fresh transaction
                            // and would otherwise race-reset isPremium to false.
                            await self.setPremium(true)
                        } else {
                            // Revocation/refund: full scan to properly clear the entitlement.
                            await self.updatePurchaseStatus()
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
    }

    /// Unwrap a VerificationResult, throwing if the JWS signature is invalid.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
