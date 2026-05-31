import { Controller } from "@hotwired/stimulus"

// Live password-requirement feedback for the signup and reset forms.
// Toggles `is-met` on each [data-rule] checklist item as the user types, and
// shows whether the confirmation matches — so problems surface immediately
// instead of after submitting and waiting for a server round-trip.
//
// Rule keys mirror User::PASSWORD_REQUIREMENTS (the server-side source of
// truth). Email-containment and common-password checks stay server-only.
export default class extends Controller {
  static targets = ["password", "confirmation", "rule", "match"]
  static values = { minLength: { type: Number, default: 8 } }

  connect() {
    this.check()
  }

  check() {
    const pwd = this.hasPasswordTarget ? this.passwordTarget.value : ""
    this.ruleTargets.forEach((el) => {
      el.classList.toggle("is-met", this.passes(el.dataset.rule, pwd))
    })
    this.checkMatch()
  }

  checkMatch() {
    if (!this.hasMatchTarget || !this.hasConfirmationTarget || !this.hasPasswordTarget) return

    const confirm = this.confirmationTarget.value
    if (confirm.length === 0) {
      this.matchTarget.hidden = true
      return
    }

    const matches = this.passwordTarget.value === confirm
    this.matchTarget.hidden = false
    this.matchTarget.classList.toggle("is-met", matches)
    this.matchTarget.textContent = matches ? "Passwords match" : "Passwords don't match yet"
  }

  passes(rule, pwd) {
    switch (rule) {
      case "length":
        return pwd.length >= this.minLengthValue
      case "special":
        return /[^A-Za-z0-9]/.test(pwd)
      case "no_repeats":
        return pwd.length > 0 && !/(.)\1{2,}/.test(pwd)
      default:
        return false
    }
  }
}
