import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "apple-purchase"
  static values = { endpoint: String, accountToken: String }

  purchase(event) {
    const button = event.currentTarget
    button.disabled = true

    this.send("purchase", {
      productId: button.dataset.productId,
      appAccountToken: this.accountTokenValue
    }, async (message) => {
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
        if (response.ok) {
          this.send("finish", { transactionId: message.data.transactionId })
          window.location.reload()
        }
      } finally {
        button.disabled = false
      }
    })
  }
}
