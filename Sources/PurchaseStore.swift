import SwiftUI
import StoreKit

@MainActor @Observable
final class PurchaseStore {
    static let identifiers = ["com.oanarinaldi.wakemeup.plus.monthly", "com.oanarinaldi.wakemeup.plus.yearly"]
    private(set) var products: [Product] = []
    private(set) var hasPlus = false
    var busy = false
    var message: String?
    private var observer: Task<Void, Never>?
    init() {
        observer = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.refresh(); await transaction.finish()
                }
            }
        }
    }
    func load() async {
        await refresh()
        do { products = try await Product.products(for: Self.identifiers).sorted { $0.price < $1.price }
            if products.isEmpty { message = "Subscriptions are currently unavailable. Your free alarms and movements are ready to use." }
        } catch { message = "Could not load Apple’s prices. Please try again. \(error.localizedDescription)" }
    }
    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.identifiers.contains(transaction.productID), transaction.revocationDate == nil, let expires = transaction.expirationDate, expires > .now { entitled = true }
        }
        hasPlus = entitled
    }
    func buy(_ product: Product) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refresh(); await transaction.finish(); message = "Welcome to Wake Me Up Plus."
            case .success(.unverified(_, let error)): message = "Apple could not verify this purchase: \(error.localizedDescription)"
            case .pending: message = "Your purchase is pending Apple’s approval."
            case .userCancelled: break
            @unknown default: message = "Purchase was not completed. Please try again."
            }
        } catch { message = error.localizedDescription }
    }
    func restore() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = hasPlus ? "Your Plus subscription is restored." : "No active Plus subscription was found for this Apple Account." }
        catch { message = error.localizedDescription }
    }
}
