import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["price", "priceHint", "url", "urlHint"]

  explainPrice() {
    const value = Number.parseFloat(this.priceTarget.value)

    if (Number.isNaN(value)) {
      this.priceTarget.setCustomValidity("")
      this.setHint(this.priceHintTarget, "Enter the price you saw before tax and shipping.")
    } else if (value <= 0) {
      this.priceTarget.setCustomValidity("Price must be greater than 0.")
      this.setHint(this.priceHintTarget, "Price must be greater than 0.", true)
    } else {
      this.priceTarget.setCustomValidity("")
      this.setHint(this.priceHintTarget, `Recording $${value.toFixed(2)}.`)
    }
  }

  validateUrl() {
    if (!this.hasUrlTarget || this.urlTarget.value.trim() === "") {
      this.urlTarget.setCustomValidity("")
      this.setHint(this.urlHintTarget, "Direct link to this product on the store's website.")
      return
    }

    try {
      const url = new URL(this.urlTarget.value)
      const valid = ["http:", "https:"].includes(url.protocol)
      this.urlTarget.setCustomValidity(valid ? "" : "Use a URL that starts with http:// or https://")
      this.setHint(this.urlHintTarget, valid ? `Linked to ${url.hostname.replace(/^www\./, "")}.` : "Use a URL that starts with http:// or https://", !valid)
    } catch (_error) {
      this.urlTarget.setCustomValidity("Enter a complete URL.")
      this.setHint(this.urlHintTarget, "Enter a complete URL, including https://", true)
    }
  }

  setHint(element, message, error = false) {
    element.textContent = message
    element.classList.toggle("is-error", error)
  }
}
