// We import the CSS which is extracted to its own file by esbuild.
// See the CSS config in your config/config.exs.
import "../css/app.css"

// Import Phoenix and LiveView
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import "phoenix_html"

// LiveView Hooks
const Hooks = {
  AutoResize: {
    mounted() { this.resize() },
    updated() { this.resize() },
    resize() {
      const el = this.el
      if (!el) return
      if (el.tagName && el.tagName.toLowerCase() === 'textarea') {
        try {
          el.style.height = 'auto'
          el.style.height = `${el.scrollHeight}px`
        } catch (e) {
          console.error("AutoResize hook error:", e)
        }
      }
    }
  }
}

// Wait for the DOM to be fully loaded before initializing LiveView
document.addEventListener("DOMContentLoaded", function() {
  // Get CSRF token
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

  if (!csrfToken) {
    console.error("CSRF token not found. LiveView will not be available.")
    return
  }

  try {
    // Initialize LiveView with the Phoenix Socket constructor (not an instance)
    const liveSocket = new LiveSocket("/live", Socket, {
      params: {_csrf_token: csrfToken},
      hooks: Hooks,
      dom: {
        onBeforeElUpdated(from, to) {
          if (from._x_dataStack) {
            try {
              window.Alpine && window.Alpine.clone(from, to)
            } catch (e) {
              console.error("Alpine clone error:", e)
            }
          }
        }
      }
    })

    // Connect to LiveView
    liveSocket.connect()

    // Expose liveSocket on window for debugging
    window.liveSocket = liveSocket

    // Handle page loading events
    window.addEventListener("phx:page-loading-start", () => {
      const loadingIndicator = document.getElementById("loading-indicator")
      if (loadingIndicator) {
        try { loadingIndicator.classList.remove("hidden") } catch {}
      }
    })

    window.addEventListener("phx:page-loading-stop", () => {
      const loadingIndicator = document.getElementById("loading-indicator")
      if (loadingIndicator) {
        try { loadingIndicator.classList.add("hidden") } catch {}
      }

      // Auto-scroll to bottom of message container
      const messageContainer = document.querySelector(".message-container")
      if (messageContainer) {
        try { messageContainer.scrollTop = messageContainer.scrollHeight } catch {}
      }
    })

    // Auto-resize textarea
    document.addEventListener("input", function(e) {
      if (e.target && e.target.matches("textarea")) {
        try {
          e.target.style.height = 'auto'
          e.target.style.height = (e.target.scrollHeight) + 'px'
        } catch (e) {
          console.error("Error resizing textarea:", e)
        }
      }
    })

    // Handle LiveView updates
    window.addEventListener("phx:update", () => {
      const messageContainer = document.querySelector(".message-container")
      if (messageContainer) {
        try { messageContainer.scrollTop = messageContainer.scrollHeight } catch {}
      }
    })

    console.log("LiveView initialized successfully")
  } catch (error) {
    console.error("Error initializing LiveView:", error)
  }
})

// Realtime: Phoenix Channels basic wire-up
try {
  const socket = new Socket("/socket", { params: { user_id: "anon" } })
  socket.connect()
  const channel = socket.channel("pattern:lobby", {})

  channel.join()
    .receive("ok", resp => {
      console.log("Joined pattern:lobby", resp)
      channel.push("ping", { hello: "world" })
        .receive("ok", resp => console.log("ping ok:", resp))
        .receive("error", err => console.error("ping error:", err))
    })
    .receive("error", resp => console.error("Join failed", resp))
    .receive("timeout", () => console.error("Join timeout"))

  channel.on("pattern_recognized", payload => {
    console.log("pattern_recognized:", payload)
  })

  channel.on("pattern_learned", payload => {
    console.log("pattern_learned:", payload)
  })

  window.starweaveSocket = socket
  window.starweaveChannel = channel
} catch (e) {
  console.error("Error wiring Phoenix Channels:", e)
}
