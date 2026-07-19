// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/platform"
import topbar from "../vendor/topbar"

// Prism.js for syntax highlighting
import "../vendor/prism.min.js"

// Auto-scroll hook for logs page
let Hooks = {}

Hooks.AutoScroll = {
  mounted() {
    this.userScrolled = false
    // Initial scroll to bottom on mount
    requestAnimationFrame(() => this.scrollToBottom())

    // Observe for new messages - don't auto-scroll, just notify if user has scrolled
    this.observer = new MutationObserver(() => {
      // New message arrived - if user hasn't scrolled, stay at bottom
      // If user has scrolled up, they'll see the "New messages" indicator
    })
    this.observer.observe(this.el, { childList: true, subtree: true })

    // Detect user scroll (scrolling UP means away from newest at bottom)
    this.el.addEventListener("scroll", () => {
      const maxScroll = this.el.scrollHeight - this.el.clientHeight
      const distanceFromBottom = maxScroll - this.el.scrollTop

      // If user scrolls up (away from bottom), mark as user-scrolled
      if (distanceFromBottom > 100 && !this.userScrolled) {
        this.userScrolled = true
        this.pushEvent("user-scrolled", {})
      }
      // If user scrolls back to bottom, reset
      if (distanceFromBottom < 50) {
        this.userScrolled = false
      }
    })

    // Listen for scroll-to-bottom event from LiveView
    this.handleEvent("scroll-to-bottom", () => {
      this.userScrolled = false
      this.scrollToBottom()
    })
  },

  updated() {
    // Don't auto-scroll on updates - user controls scroll position
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

Hooks.ExpandableMessage = {
  mounted() {
    const toggle = this.el.querySelector(".message-expand-toggle")
    const body = this.el.querySelector(".message-body")
    const fade = this.el.querySelector(".message-body-fade")
    const content = this.el.querySelector(".message-content")

    if (toggle && body && content) {
      // Check if content is actually truncated
      const isOverflowing = () => {
        // Temporarily remove clamp to measure full height
        body.classList.remove("clamped")
        body.classList.add("expanded")
        const fullHeight = content.scrollHeight
        body.classList.remove("expanded")
        body.classList.add("clamped")
        const clampedHeight = content.clientHeight
        return fullHeight > clampedHeight + 5 // 5px tolerance
      }

      // Initial check - hide button/fade if not needed
      if (!isOverflowing()) {
        toggle.style.display = "none"
        if (fade) fade.style.display = "none"
        body.classList.remove("clamped")
      } else {
        toggle.style.display = ""
        if (fade) fade.style.display = ""
      }

      toggle.addEventListener("click", (e) => {
        e.preventDefault()
        const isExpanded = body.classList.contains("expanded")

        if (isExpanded) {
          // Collapse
          body.classList.remove("expanded")
          body.classList.add("clamped")
          if (fade) fade.style.display = ""
          toggle.textContent = "Show full ↓"
          toggle.setAttribute("aria-expanded", "false")
        } else {
          // Expand
          body.classList.remove("clamped")
          body.classList.add("expanded")
          if (fade) fade.style.display = "none"
          toggle.textContent = "Collapse ↑"
          toggle.setAttribute("aria-expanded", "true")
        }
      })
    }
  }
}

Hooks.SyntaxHighlight = {
  mounted() {
    if (window.Prism) {
      Prism.highlightAllUnder(this.el)
    }
  },
  updated() {
    if (window.Prism) {
      Prism.highlightAllUnder(this.el)
    }
  }
}

Hooks.PasswordToggle = {
  mounted() {
    const btn = this.el.querySelector('[data-toggle-password]')
    const input = this.el.querySelector('input[type="password"], input[type="text"]')
    const eyeShow = this.el.querySelector('.eye-show')
    const eyeHide = this.el.querySelector('.eye-hide')

    if (btn && input) {
      btn.addEventListener('click', () => {
        const isPassword = input.type === 'password'
        input.type = isPassword ? 'text' : 'password'
        eyeShow.classList.toggle('hidden', isPassword)
        eyeHide.classList.toggle('hidden', !isPassword)
      })
    }
  }
}

Hooks.NavIndicator = {
  mounted() {
    // Small delay to ensure layout is complete
    requestAnimationFrame(() => this.updateIndicator())
  },
  updated() {
    this.updateIndicator()
  },
  updateIndicator() {
    const activeTab = this.el.querySelector('[data-active="true"]')
    const indicator = this.el.querySelector('.site-nav__indicator')

    if (activeTab && indicator) {
      indicator.style.left = `${activeTab.offsetLeft}px`
      indicator.style.width = `${activeTab.offsetWidth}px`
    } else if (indicator) {
      // No active tab, hide indicator
      indicator.style.width = '0px'
    }
  }
}

Hooks.CopyCode = {
  mounted() {
    this.el.addEventListener("click", () => {
      const code = this.el.dataset.code
      navigator.clipboard.writeText(code).then(() => {
        const iconEl = this.el.querySelector(".copy-icon")
        const textEl = this.el.querySelector(".copy-text")

        if (iconEl && textEl) {
          // Store original content
          const originalIcon = iconEl.innerHTML
          const originalText = textEl.textContent

          // Show "Copied" state
          iconEl.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-3.5"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd" /></svg>'
          textEl.textContent = "Copied"

          // Restore after 2 seconds
          setTimeout(() => {
            iconEl.innerHTML = originalIcon
            textEl.textContent = originalText
          }, 2000)
        }
      })
    })
  }
}

Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()

      // Support both direct content and target element
      let text = this.el.dataset.content
      if (!text) {
        const targetId = this.el.dataset.copyTarget
        const targetEl = document.getElementById(targetId)
        if (targetEl) {
          text = targetEl.textContent || targetEl.innerText
        }
      }

      if (text) {
        navigator.clipboard.writeText(text).then(() => {
          // Notify LiveView so the icon swaps to checkmark
          this.pushEvent("copy_key", {})
          // Brief visual feedback on title
          const originalTitle = this.el.getAttribute("title")
          this.el.setAttribute("title", "Copied!")
          setTimeout(() => {
            this.el.setAttribute("title", originalTitle || "Copy message")
          }, 1500)
        })
      }
    })
  }
}


Hooks.Quickstart = {
    mounted() {
        this.handleClick = this.handleClick.bind(this)
        this.updateCodeBlocks = this.updateCodeBlocks.bind(this)
        this.el.addEventListener("click", this.handleClick)
        if (this.el.classList.contains("docs-tab--active")) {
            this.updateCodeBlocks()
        }
    },

    destroyed() {
        this.el.removeEventListener("click", this.handleClick)
    },

    handleClick(event) {
        event.preventDefault()
        this.updateCodeBlocks()
    },

    updateCodeBlocks() {
        const active = document.documentElement.getElementsByClassName("docs-tab--active").item(0)
        if (active) {
            active.classList.remove("docs-tab--active")
            active.classList.add("docs-tab--inactive")
        }
        this.el.classList.remove("docs-tab--inactive")
        this.el.classList.add("docs-tab--active")
        const codeBlocks = document.documentElement.getElementsByClassName("code-block")
        for (let i = 0; i < codeBlocks.length; i++) {
            const block = codeBlocks.item(i)
            if (block.dataset.static === "true") continue
            block.classList.add('hidden')
        }
        const ids = [
            this.el.dataset.install,
            this.el.dataset.config,
            this.el.dataset.handler,
            this.el.dataset.connect,
            this.el.dataset.example
        ].filter(Boolean)
        ids.forEach((id) => {
            const node = document.getElementById(id)
            if (node) node.classList.remove('hidden')
        })
        if (window.Prism && typeof window.Prism.highlightAllUnder === "function") {
            window.Prism.highlightAllUnder(document)
        }
    },
}

Hooks.ThemeToggle = {
  mounted() {
    this.handleClick = this.handleClick.bind(this)
    this.el.addEventListener("click", this.handleClick)
    this.updateVisual()
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
  },

  handleClick(event) {
    event.preventDefault()
    const next = this.nextTheme()
    this.el.dataset.phxTheme = next
    this.el.dispatchEvent(new Event("phx:set-theme", {bubbles: true}))
    this.updateVisual(next)
  },

  nextTheme() {
    const current = document.documentElement.getAttribute("data-active-theme")
    if (current === "dark") return "light"
    return "dark"
  },

  updateVisual(nextTheme) {
    const active = nextTheme || document.documentElement.getAttribute("data-active-theme") || "light"
    const icon = this.el.querySelector(".theme-toggle-single__icon")

    if (!icon) return

    if (active === "dark") {
      icon.textContent = "☀"
      this.el.setAttribute("aria-label", "Switch to light mode")
    } else {
      icon.textContent = "☾"
      this.el.setAttribute("aria-label", "Switch to dark mode")
    }
  },
}

Hooks.HeroCarousel = {
  items: [
    { word: "Games", icon: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875s-2.25.84-2.25 1.875c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 0 1-.657.643 48.39 48.39 0 0 1-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 0 1-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 0 0-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 0 1-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 0 0 .657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 0 1-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 0 0 5.427-.63 48.05 48.05 0 0 0 .582-4.717.532.532 0 0 0-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.96.401v0a.656.656 0 0 0 .658-.663 48.422 48.422 0 0 0-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 0 1-.61-.58v0Z" /></svg>' },
    { word: "Agents", icon: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 0 0 2.25-2.25V6.75a2.25 2.25 0 0 0-2.25-2.25H6.75A2.25 2.25 0 0 0 4.5 6.75v10.5a2.25 2.25 0 0 0 2.25 2.25Zm.75-12h9v9h-9v-9Z" /></svg>' },
    { word: "Commerce", icon: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 0 0-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 0 0-16.536-1.84M7.5 14.25 5.106 5.272M6 20.25a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Zm12.75 0a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z" /></svg>' },
    { word: "Applications", icon: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z" /></svg>' }
  ],
  itemIndex: 0,
  activeSlot: 0,

  mounted() {
    // Double-buffer: two stacked elements for crossfade without reflow
    this.wordEls = this.el.querySelectorAll(".hero-carousel__word")
    this.iconEls = this.el.querySelectorAll(".hero-carousel__icon")

    // Initialize first item immediately (same code path as rotation)
    // This ensures server-rendered content matches JS-controlled content exactly
    const firstItem = this.items[0]
    this.wordEls[0].textContent = firstItem.word
    this.iconEls[0].innerHTML = firstItem.icon

    this.interval = setInterval(() => this.rotate(), 3000)
  },

  rotate() {
    // Move to next item
    this.itemIndex = (this.itemIndex + 1) % this.items.length
    const item = this.items[this.itemIndex]

    // Determine current and next slots (0 or 1)
    const currentSlot = this.activeSlot
    const nextSlot = 1 - this.activeSlot

    // Set content on the hidden (next) elements
    this.wordEls[nextSlot].textContent = item.word
    this.iconEls[nextSlot].innerHTML = item.icon

    // Crossfade: exit current, enter next
    this.wordEls[currentSlot].classList.remove("hero-carousel__word--active")
    this.wordEls[currentSlot].classList.add("hero-carousel__word--exit")
    this.iconEls[currentSlot].classList.remove("hero-carousel__icon--active")
    this.iconEls[currentSlot].classList.add("hero-carousel__icon--exit")

    this.wordEls[nextSlot].classList.add("hero-carousel__word--active")
    this.iconEls[nextSlot].classList.add("hero-carousel__icon--active")

    // Clean up exit class after transition
    setTimeout(() => {
      this.wordEls[currentSlot].classList.remove("hero-carousel__word--exit")
      this.iconEls[currentSlot].classList.remove("hero-carousel__icon--exit")
    }, 400)

    // Swap active slot
    this.activeSlot = nextSlot
  },

  destroyed() {
    clearInterval(this.interval)
  }
}


Hooks.OrgNudge = {
  mounted() {
    if (sessionStorage.getItem("org_nudge_dismissed")) {
      // Already dismissed — tell the server so it stops rendering it
      this.pushEvent("dismiss_org_nudge", {})
    } else {
      // Not dismissed — reveal it (starts hidden via CSS to prevent flash)
      this.el.style.display = ""
    }
  }
}

Hooks.DismissNudge = {
  mounted() {
    this.el.addEventListener("click", () => {
      sessionStorage.setItem("org_nudge_dismissed", "true")
    })
  }
}


Hooks.SidebarToggle = {
  mounted() {
    const sidebar = document.getElementById("sidebar")
    if (!sidebar) return

    // Read persisted state before first paint
    const isCollapsed = localStorage.getItem("sidebar_collapsed") === "true"
    if (isCollapsed) {
      sidebar.setAttribute("data-collapsed", "true")
    }

    // Update toggle button aria-expanded
    this.updateAriaExpanded(sidebar)

    // Listen for toggle events
    window.addEventListener("sidebar:toggle", () => {
      const currentCollapsed = sidebar.getAttribute("data-collapsed") === "true"
      const newCollapsed = !currentCollapsed

      if (newCollapsed) {
        sidebar.setAttribute("data-collapsed", "true")
      } else {
        sidebar.removeAttribute("data-collapsed")
      }

      // Persist state
      localStorage.setItem("sidebar_collapsed", newCollapsed.toString())
      this.updateAriaExpanded(sidebar)
    })

    // Handle escape key to close mobile menu
    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        sidebar.classList.remove("sidebar--open")
        const overlay = document.getElementById("sidebar-overlay")
        if (overlay) {
          overlay.classList.remove("sidebar-overlay--visible")
        }
      }
    })
  },

  updateAriaExpanded(sidebar) {
    const toggleBtn = sidebar.querySelector(".sidebar-toggle")
    if (toggleBtn) {
      const isCollapsed = sidebar.getAttribute("data-collapsed") === "true"
      toggleBtn.setAttribute("aria-expanded", (!isCollapsed).toString())
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
