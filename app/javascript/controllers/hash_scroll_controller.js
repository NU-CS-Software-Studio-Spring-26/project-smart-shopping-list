import { Controller } from "@hotwired/stimulus"

// Scroll to #signup-form only when explicitly linked (header/footer Sign up).
// Avoids janky auto-scroll on the default sign-in landing page.
export default class extends Controller {
  static targets = ["anchor"]

  scroll(event) {
    const link = event.currentTarget
    const url = new URL(link.href, window.location.origin)

    if (!url.hash || url.hash !== "#signup-form") return
    if (url.pathname !== window.location.pathname) return

    event.preventDefault()
    this.scrollToElement(url.hash)
    window.history.replaceState(null, "", `${url.pathname}${url.hash}`)
  }

  scrollToHash() {
    const hash = window.location.hash
    if (hash !== "#signup-form") return
    this.scrollToElement(hash)
  }

  scrollToElement(hash) {
    const el = document.querySelector(hash)
    if (!el) return

    // If the form is already on screen (mobile layout), don't animate.
    const rect = el.getBoundingClientRect()
    const headerOffset = 72
    const alreadyVisible = rect.top >= headerOffset && rect.top < window.innerHeight * 0.35
    if (alreadyVisible) {
      el.focus({ preventScroll: true })
      return
    }

    const instant = window.matchMedia("(max-width: 640px), (prefers-reduced-motion: reduce)").matches
    requestAnimationFrame(() => {
      el.scrollIntoView({ behavior: instant ? "auto" : "smooth", block: "start" })
      el.focus({ preventScroll: true })
    })
  }
}
