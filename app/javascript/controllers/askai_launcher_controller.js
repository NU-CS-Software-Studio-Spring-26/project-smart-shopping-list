import { Controller } from "@hotwired/stimulus"

// Opens the global "Ask AI" slide-out panel from anywhere on the page by
// triggering its launcher button (see shared/_ask_ai_widget). The element
// links to the full Ask AI page as a no-JS fallback; here we intercept the
// click and pop the panel open instead.
export default class extends Controller {
  open(event) {
    const fab = document.getElementById("ask-ai-widget")?.querySelector(".pt-askai-fab")
    if (fab) {
      event.preventDefault()
      fab.click()
    }
  }
}
