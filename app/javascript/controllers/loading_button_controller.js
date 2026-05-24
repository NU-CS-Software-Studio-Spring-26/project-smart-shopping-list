import { Controller } from "@hotwired/stimulus"

// Drop-in submit-button loading state for forms whose response can take a
// few seconds (e.g. the AI assistant which calls OpenRouter). On form
// submit we disable the button and swap its label to the busy text so the
// user knows the request is in flight. Restoring happens automatically
// when the next page renders.
//
// Wire on the FORM:
//   data-controller="loading-button"
//   data-action="submit->loading-button#busy"
// And on the SUBMIT input/button:
//   data-loading-button-target="submit" data-busy-label="Thinking…"
export default class extends Controller {
  static targets = ["submit"]

  busy() {
    this.submitTargets.forEach((el) => {
      el.dataset.originalLabel = el.value || el.textContent
      const busyLabel = el.dataset.busyLabel || "Loading…"
      if (el.tagName === "INPUT") {
        el.value = busyLabel
      } else {
        el.textContent = busyLabel
      }
      el.disabled = true
      el.classList.add("is-busy")
    })
  }
}
