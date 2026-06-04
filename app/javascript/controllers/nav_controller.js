import { Controller } from "@hotwired/stimulus"

// Toggles the mobile header nav. On narrow viewports the nav is hidden
// behind a hamburger button; tapping it adds `is-open` so the CSS can
// reveal the menu. Closes again on Escape or when a link is tapped so
// users land on the new page without a lingering open panel.
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    const open = this.menuTarget.classList.toggle("is-open")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
    }
  }

  close() {
    this.menuTarget.classList.remove("is-open")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
