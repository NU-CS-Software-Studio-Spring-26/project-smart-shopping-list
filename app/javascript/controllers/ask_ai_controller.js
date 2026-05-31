import { Controller } from "@hotwired/stimulus"

// Toggles the global "Ask AI" slide-out panel (see shared/_ask_ai_widget).
// The panel form targets a Turbo Frame, so answers load inline; this
// controller only manages open/close, focus, and the Escape/overlay dismiss.
export default class extends Controller {
  static targets = ["panel", "overlay", "fab", "input"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  open() {
    this.panelTarget.hidden = false
    this.overlayTarget.hidden = false
    this.fabTarget.setAttribute("aria-expanded", "true")
    // Defer focus so the element is visible before we move focus to it.
    requestAnimationFrame(() => this.inputTarget?.focus())
  }

  close() {
    this.panelTarget.hidden = true
    this.overlayTarget.hidden = true
    this.fabTarget.setAttribute("aria-expanded", "false")
    this.fabTarget.focus()
  }

  // Keep focus in the input after a question is submitted into the frame.
  submitting() {
    requestAnimationFrame(() => this.inputTarget?.focus())
  }

  onKeydown(event) {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close()
    }
  }
}
