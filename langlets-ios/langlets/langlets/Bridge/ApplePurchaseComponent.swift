import HotwireNative
import StoreKit

/// Runs consumable credit purchases through StoreKit. Rails verifies and grants
/// the signed transaction before the web side asks us to finish it.
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
}
