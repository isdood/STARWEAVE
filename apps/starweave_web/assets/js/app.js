// We import the CSS which is extracted to its own file by esbuild.
// See the CSS config in your config/config.exs.
import "../css/app.css"

// Phoenix LiveView hooks
import { LiveSocket } from "phoenix_live_view"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

// Initialize LiveView
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Phoenix.Socket, {
  params: { _csrf_token: csrfToken },
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) { window.Alpine.clone(from, to) }
    }
  }
})

// Connect to LiveView
window.addEventListener("phx:page-loading-start", info => {
  // Handle page loading start
  const loadingIndicator = document.getElementById("loading-indicator")
  if (loadingIndicator) loadingIndicator.classList.remove("hidden")
})

window.addEventListener("phx:page-loading-stop", info => {
  // Handle page loading stop
  const loadingIndicator = document.getElementById("loading-indicator")
  if (loadingIndicator) loadingIndicator.classList.add("hidden")
  
  // Auto-scroll to bottom of message container
  const messageContainer = document.querySelector(".message-container")
  if (messageContainer) {
    messageContainer.scrollTop = messageContainer.scrollHeight
  }
})

// Auto-resize textarea
document.addEventListener("input", function(e) {
  if (e.target && e.target.matches("textarea")) {
    e.target.style.height = 'auto';
    e.target.style.height = (e.target.scrollHeight) + 'px';
  }
})

// Connect to LiveView socket
window.liveSocket = liveSocket
window.addEventListener("phx:update", () => {
  // Handle LiveView updates
  const messageContainer = document.querySelector(".message-container")
  if (messageContainer) {
    messageContainer.scrollTop = messageContainer.scrollHeight
  }
})

// Connect to socket
liveSocket.connect()
