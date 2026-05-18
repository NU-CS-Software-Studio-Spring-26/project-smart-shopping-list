import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 350 } }

  queue() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submitNow(), this.delayValue)
  }

  submitNow() {
    if (this.element.requestSubmit) {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
