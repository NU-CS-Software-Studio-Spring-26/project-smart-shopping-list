// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

// Register the service worker so PriceTracker is installable as a PWA.
// Scope "/" so it controls the whole app. The SW itself lives in /public
// so it ships unfingerprinted at the path the browser expects.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("/service_worker.js", { scope: "/" })
      .catch((err) => console.warn("Service worker registration failed:", err));
  });
}

