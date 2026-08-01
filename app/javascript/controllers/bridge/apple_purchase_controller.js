import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Drives StoreKit from the web side. The native component runs the purchase and
// hands back the signed transaction; Rails verifies and grants it before we ask
// StoreKit to finish it, so a transaction we failed to record stays in the queue
// and is offered again on the next launch.
//
// Used only by the Pro paywall now. It served a Credits sheet selling consumable
// packs too, until individual credits stopped being sold; the endpoint stays a
// value rather than a constant because which grant a transaction can buy is
// decided entirely by the endpoint it is posted to.
export default class extends BridgeComponent {
  static component = "apple-purchase"
  static values = { endpoint: String, accountToken: String }

  purchase(event) {
    this.#run(event.currentTarget, "purchase", {
      productId: event.currentTarget.dataset.productId,
      appAccountToken: this.accountTokenValue
    })
  }

  // Subscriptions only. StoreKit already knows about an entitlement bought on
  // another device or before a reinstall; this is how it reaches our database.
  restore(event) {
    this.#run(event.currentTarget, "restore", { appAccountToken: this.accountTokenValue })
  }

  #run(button, event, payload) {
    button.disabled = true

    this.send(event, payload, async (message) => {
      try {
        if (!message.data?.signedTransaction) return

        const response = await fetch(this.endpointValue, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
          },
          body: JSON.stringify({ signed_transaction: message.data.signedTransaction })
        })
        if (!response.ok) return

        // Only now: an unrecorded transaction must stay unfinished so StoreKit
        // re-delivers it rather than dropping a purchase we never granted.
        this.send("finish", { transactionId: message.data.transactionId })

        // Pro answers with its confirmation screen; the reload is the fallback
        // for a response that names no destination.
        const body = await response.json().catch(() => ({}))
        if (body.redirect) {
          window.location.href = body.redirect
        } else {
          window.location.reload()
        }
      } finally {
        button.disabled = false
      }
    })
  }
}
