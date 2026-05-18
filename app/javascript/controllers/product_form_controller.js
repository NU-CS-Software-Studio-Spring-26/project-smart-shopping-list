import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "urlHint", "targetPrice", "targetHint"]

  validateUrl() {
    if (!this.hasUrlTarget || this.urlTarget.value.trim() === "") {
      this.setHint(this.urlHintTarget, "")
      this.urlTarget.setCustomValidity("")
      return
    }

    try {
      const url = new URL(this.urlTarget.value)
      const valid = ["http:", "https:"].includes(url.protocol)
      this.urlTarget.setCustomValidity(valid ? "" : "Use a URL that starts with http:// or https://")
      this.setHint(this.urlHintTarget, valid ? `Tracking source: ${url.hostname.replace(/^www\./, "")}` : "Use a URL that starts with http:// or https://", !valid)
    } catch (_error) {
      this.urlTarget.setCustomValidity("Enter a complete product URL.")
      this.setHint(this.urlHintTarget, "Enter a complete product URL, including https://", true)
    }
  }

  explainTargetPrice() {
    if (!this.hasTargetPriceTarget || !this.hasTargetHintTarget) return

    const value = Number.parseFloat(this.targetPriceTarget.value)
    if (Number.isNaN(value)) {
      this.setHint(this.targetHintTarget, "Leave blank to skip alerts. You can change this later.")
    } else if (value <= 0) {
      this.targetPriceTarget.setCustomValidity("Target price must be greater than 0.")
      this.setHint(this.targetHintTarget, "Target price must be greater than 0.", true)
      return
    } else {
      this.setHint(this.targetHintTarget, `We'll alert you when this product reaches $${value.toFixed(2)} or less.`)
    }

    this.targetPriceTarget.setCustomValidity("")
  }

  setHint(element, message, error = false) {
    if (!element) return

    element.textContent = message
    element.classList.toggle("is-error", error)
  }
}
