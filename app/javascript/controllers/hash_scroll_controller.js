import { Controller } from "@hotwired/stimulus"

// Scroll to in-page anchors after Turbo navigations and when a hash link
// targets the current page (e.g. header "Sign up" on /registration/new).
export default class extends Controller {
  connect() {
    this.scrollToHash()
  }

  scroll(event) {
    const link = event.currentTarget
    const url = new URL(link.href, window.location.origin)

    if (url.pathname !== window.location.pathname || !url.hash) return

    event.preventDefault()
    this.scrollToElement(url.hash)
    window.history.replaceState(null, "", `${url.pathname}${url.hash}`)
  }

  scrollToHash() {
    if (!window.location.hash) return
    this.scrollToElement(window.location.hash)
  }

  scrollToElement(hash) {
    const el = document.querySelector(hash)
    if (!el) return

    requestAnimationFrame(() => {
      el.scrollIntoView({ behavior: "smooth", block: "start" })
      el.focus({ preventScroll: true })
    })
  }
}
