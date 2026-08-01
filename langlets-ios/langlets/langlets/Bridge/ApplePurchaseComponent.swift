import HotwireNative
import StoreKit

/// Runs credit and Langlets Pro purchases through StoreKit. Rails verifies and
/// grants the signed transaction before the web side asks us to finish it.
///
/// The component is deliberately product-agnostic: it buys whichever product id
/// the page names and hands the signed transaction back. What that transaction
/// is worth is decided on the server, by the endpoint the web side posts it to.
@MainActor
final class ApplePurchaseComponent: BridgeComponent {
    nonisolated override class var name: String { "apple-purchase" }

    private struct PurchaseMessage: Decodable {
        let productId: String
        let appAccountToken: UUID
    }

    private struct FinishMessage: Decodable {
        let transactionId: String
    }

    private var pendingTransactions: [UInt64: Transaction] = [:]

    override func onReceive(message: HotwireNative.Message) {
        switch message.event {
        case "purchase":
            guard let data: PurchaseMessage = message.data() else { return }
            Task { await purchase(data, replyingTo: message.event) }
        case "restore":
            Task { await restore(replyingTo: message.event) }
        case "finish":
            guard let data: FinishMessage = message.data(),
                  let transactionId = UInt64(data.transactionId),
                  let transaction = pendingTransactions.removeValue(forKey: transactionId) else { return }
            Task { await transaction.finish() }
        default:
            break
        }
    }

    private func purchase(_ data: PurchaseMessage, replyingTo event: String) async {
        do {
            guard let product = try await Product.products(for: [data.productId]).first else {
                _ = try? await reply(to: event, with: ["error": "product_unavailable"])
                return
            }

            let result = try await product.purchase(options: [.appAccountToken(data.appAccountToken)])
            guard case let .success(verification) = result,
                  case let .verified(transaction) = verification else {
                _ = try? await reply(to: event, with: ["error": "purchase_not_completed"])
                return
            }

            pendingTransactions[transaction.id] = transaction
            _ = try? await reply(to: event, with: [
                "signedTransaction": verification.jwsRepresentation,
                "transactionId": String(transaction.id)
            ])
        } catch {
            _ = try? await reply(to: event, with: ["error": "purchase_failed"])
        }
    }

    /// Re-sends the current subscription entitlement so the server can rebuild
    /// state it does not have: a reinstall, a second device, or a purchase whose
    /// POST never reached us. Required by App Review for auto-renewable
    /// subscriptions, and the only way back to Pro after a fresh install.
    ///
    /// `currentEntitlements` yields at most one row per subscription group, and
    /// it is already the renewed transaction rather than the original — so the
    /// server receives a current expiry, not the one first purchased.
    private func restore(replyingTo event: String) async {
        // Pulls anything StoreKit is still holding for this Apple Account,
        // including a purchase finished on another device.
        try? await AppStore.sync()

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productType == .autoRenewable else { continue }

            // Restores are not finished here: the transaction is already
            // finished from the purchase that created it, and re-finishing is a
            // no-op. Rails still gets the JWS it needs.
            _ = try? await reply(to: event, with: [
                "signedTransaction": result.jwsRepresentation,
                "transactionId": String(transaction.id)
            ])
            return
        }

        _ = try? await reply(to: event, with: ["error": "nothing_to_restore"])
    }
}
