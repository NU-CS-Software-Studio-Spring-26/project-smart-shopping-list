import { Controller } from "@hotwired/stimulus"

// Toggles the global "Ask AI" slide-out panel (see shared/_ask_ai_widget).
// The panel form targets a Turbo Frame, so answers load inline; this
// controller manages open/close, focus, the Escape dismiss, and lets the
// user drag the panel around the page by its header handle.
export default class extends Controller {
  static targets = ["panel", "fab", "input", "handle"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    this.onDragMove = this.onDragMove.bind(this)
    this.onDragEnd = this.onDragEnd.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.onDragEnd()
  }

  open() {
    this.panelTarget.hidden = false
    this.fabTarget.setAttribute("aria-expanded", "true")
    // Defer focus so the element is visible before we move focus to it.
    requestAnimationFrame(() => this.inputTarget?.focus())
  }

  close() {
    this.panelTarget.hidden = true
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

  // ---- Dragging --------------------------------------------------------
  // Pointer-based so it works for mouse and touch. While dragging we pin the
  // panel with explicit top/left (clearing the default bottom/right anchor)
  // so it can be parked in any corner or edge of the viewport.
  dragStart(event) {
    // Ignore the close button and anything interactive inside the handle.
    if (event.target.closest("button")) return
    event.preventDefault()

    const rect = this.panelTarget.getBoundingClientRect()
    this.dragOffsetX = event.clientX - rect.left
    this.dragOffsetY = event.clientY - rect.top

    // Switch to top/left positioning anchored at the current spot.
    this.panelTarget.style.right = "auto"
    this.panelTarget.style.bottom = "auto"
    this.panelTarget.style.left = `${rect.left}px`
    this.panelTarget.style.top = `${rect.top}px`
    this.panelTarget.classList.add("is-dragging")

    window.addEventListener("pointermove", this.onDragMove)
    window.addEventListener("pointerup", this.onDragEnd)
  }

  onDragMove(event) {
    const width = this.panelTarget.offsetWidth
    const height = this.panelTarget.offsetHeight
    const margin = 8
    let left = event.clientX - this.dragOffsetX
    let top = event.clientY - this.dragOffsetY

    // Keep the panel within the viewport.
    left = Math.max(margin, Math.min(left, window.innerWidth - width - margin))
    top = Math.max(margin, Math.min(top, window.innerHeight - height - margin))

    this.panelTarget.style.left = `${left}px`
    this.panelTarget.style.top = `${top}px`
  }

  onDragEnd() {
    this.panelTarget?.classList.remove("is-dragging")
    window.removeEventListener("pointermove", this.onDragMove)
    window.removeEventListener("pointerup", this.onDragEnd)
  }
}
