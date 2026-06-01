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
    this.onResizeMove = this.onResizeMove.bind(this)
    this.onResizeEnd = this.onResizeEnd.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.onDragEnd()
    this.onResizeEnd()
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

  // ---- Resizing --------------------------------------------------------
  // Each handle carries a data-direction made of compass letters (n/s/e/w).
  // We pin the panel to left/top/width/height at the start, then grow or
  // shrink the relevant edges as the pointer moves.
  static MIN_WIDTH = 300
  static MIN_HEIGHT = 240

  resizeStart(event) {
    event.preventDefault()
    event.stopPropagation()

    this.resizeDir = event.currentTarget.dataset.direction || ""
    const rect = this.panelTarget.getBoundingClientRect()
    this.resizeStartX = event.clientX
    this.resizeStartY = event.clientY
    this.startLeft = rect.left
    this.startTop = rect.top
    this.startWidth = rect.width
    this.startHeight = rect.height

    // Pin to explicit geometry so width/height/top/left all drive layout.
    this.panelTarget.style.right = "auto"
    this.panelTarget.style.bottom = "auto"
    this.panelTarget.style.left = `${rect.left}px`
    this.panelTarget.style.top = `${rect.top}px`
    this.panelTarget.style.width = `${rect.width}px`
    this.panelTarget.style.height = `${rect.height}px`
    this.panelTarget.style.maxHeight = "none"
    this.panelTarget.classList.add("is-resizing")

    window.addEventListener("pointermove", this.onResizeMove)
    window.addEventListener("pointerup", this.onResizeEnd)
  }

  onResizeMove(event) {
    const dir = this.resizeDir
    const dx = event.clientX - this.resizeStartX
    const dy = event.clientY - this.resizeStartY
    const minW = this.constructor.MIN_WIDTH
    const minH = this.constructor.MIN_HEIGHT
    const margin = 8

    let left = this.startLeft
    let top = this.startTop
    let width = this.startWidth
    let height = this.startHeight

    if (dir.includes("e")) {
      width = Math.min(this.startWidth + dx, window.innerWidth - this.startLeft - margin)
    }
    if (dir.includes("w")) {
      // Don't let the left edge cross the right edge (min width) or the viewport.
      const maxDx = this.startWidth - minW
      const clampedDx = Math.max(Math.min(dx, maxDx), margin - this.startLeft)
      left = this.startLeft + clampedDx
      width = this.startWidth - clampedDx
    }
    if (dir.includes("s")) {
      height = Math.min(this.startHeight + dy, window.innerHeight - this.startTop - margin)
    }
    if (dir.includes("n")) {
      const maxDy = this.startHeight - minH
      const clampedDy = Math.max(Math.min(dy, maxDy), margin - this.startTop)
      top = this.startTop + clampedDy
      height = this.startHeight - clampedDy
    }

    this.panelTarget.style.left = `${left}px`
    this.panelTarget.style.top = `${top}px`
    this.panelTarget.style.width = `${Math.max(width, minW)}px`
    this.panelTarget.style.height = `${Math.max(height, minH)}px`
  }

  onResizeEnd() {
    this.panelTarget?.classList.remove("is-resizing")
    window.removeEventListener("pointermove", this.onResizeMove)
    window.removeEventListener("pointerup", this.onResizeEnd)
  }
}
