defmodule PlatformWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PlatformWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :container_class, :string,
    default: "mx-auto max-w-2xl space-y-4",
    doc: "CSS classes for the main content container width/padding"

  attr :active_nav, :string,
    default: nil,
    doc: "the active navigation item: \"home\" | \"docs\" | nil"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="site-header">
      <div class="site-header__inner">
        <%!-- Logo --%>
        <div class="site-header__logo-wrapper">
          <.link
            href={if @current_scope && @current_scope.organization, do: ~p"/portal", else: ~p"/"}
            class="site-header__logo"
          >
            <img
              src={~p"/images/logo.svg"}
              alt="OpenLLP"
              class="site-header__logo-img site-header__logo-img--light"
            />
            <img
              src={~p"/images/logo-light.svg"}
              alt="OpenLLP"
              class="site-header__logo-img site-header__logo-img--dark"
            />
          </.link>
        </div>

        <%!-- Centered Navigation (only for authenticated users) --%>
        <%= if @current_scope && @current_scope.organization do %>
          <nav class="site-nav">
            <.link
              href={~p"/portal"}
              class={["site-nav__tab", @active_nav == "home" && "site-nav__tab--active"]}
            >
              Home
            </.link>
            <.link
              href={~p"/docs"}
              class={["site-nav__tab", @active_nav == "docs" && "site-nav__tab--active"]}
            >
              Docs
            </.link>
          </nav>
        <% end %>

        <%!-- Right Actions --%>
        <div class="site-header__actions">
          <%= if @current_scope && @current_scope.organization do %>
            <div class="relative">
              <button
                type="button"
                class="profile-avatar"
                style={"background-color: #{avatar_color(@current_scope.organization)}"}
                phx-click={
                  JS.toggle(
                    to: "#profile-menu",
                    in:
                      {"transition-all ease-out duration-200", "opacity-0 -translate-y-2 scale-95",
                       "opacity-100 translate-y-0 scale-100"},
                    out:
                      {"transition-all ease-in duration-150", "opacity-100 translate-y-0 scale-100",
                       "opacity-0 -translate-y-2 scale-95"}
                  )
                }
                aria-haspopup="menu"
                aria-expanded="false"
              >
                {profile_initial(@current_scope.organization)}
              </button>

              <div
                id="profile-menu"
                class="profile-menu__panel"
                phx-click-away={
                  JS.hide(
                    to: "#profile-menu",
                    transition:
                      {"transition-all ease-in duration-150", "opacity-100 translate-y-0 scale-100",
                       "opacity-0 -translate-y-2 scale-95"}
                  )
                }
                phx-window-keydown={
                  JS.hide(
                    to: "#profile-menu",
                    transition:
                      {"transition-all ease-in duration-150", "opacity-100 translate-y-0 scale-100",
                       "opacity-0 -translate-y-2 scale-95"}
                  )
                }
                phx-key="escape"
                style="display: none;"
              >
                <%!-- Header with org info --%>
                <div class="profile-menu__header">
                  <div
                    class="profile-menu__avatar"
                    style={"background-color: #{avatar_color(@current_scope.organization)}"}
                  >
                    {profile_initial(@current_scope.organization)}
                  </div>
                  <div class="profile-menu__info">
                    <div class="profile-menu__name">
                      {@current_scope.organization.name || "Organization"}
                    </div>
                  </div>
                </div>

                <div class="profile-menu__divider"></div>

                <%!-- Settings link --%>
                <.link navigate={~p"/settings"} class="profile-menu__link">
                  <.icon name="hero-cog-6-tooth" class="size-4" />
                  <span>Settings</span>
                </.link>

                <%!-- Theme toggle --%>
                <div class="profile-menu__link profile-menu__link--with-action">
                  <span class="profile-menu__link-label">
                    <.icon name="hero-moon" class="size-4" />
                    <span>Theme</span>
                  </span>
                  <.theme_toggle />
                </div>
              </div>
            </div>
          <% else %>
            <.theme_toggle />
          <% end %>
        </div>
      </div>
    </header>

    <main class="px-4 sm:px-6 lg:px-8">
      <div class={@container_class}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.site_footer />

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the portal app layout with a collapsible sidebar.

  Used for authenticated portal pages (dashboard, logs, settings, etc.)

  ## Examples

      <Layouts.portal_app flash={@flash} current_scope={@current_scope} active_nav="home">
        <h1>Dashboard Content</h1>
      </Layouts.portal_app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_scope, :map, required: true, doc: "the current scope with organization"
  attr :active_nav, :string, default: "home", doc: "the active navigation item"

  attr :container_class, :string,
    default: "mx-auto max-w-5xl",
    doc: "CSS classes for the main content container"

  slot :inner_block, required: true

  def portal_app(assigns) do
    ~H"""
    <div class="portal-layout" id="portal-layout" phx-hook="SidebarToggle">
      <.sidebar current_scope={@current_scope} active_nav={@active_nav} />

      <%!-- Mobile header with hamburger --%>
      <header class="portal-mobile-header">
        <button
          type="button"
          class="portal-mobile-menu-btn"
          aria-label="Open menu"
          phx-click={
            JS.add_class("sidebar--open", to: "#sidebar")
            |> JS.add_class("sidebar-overlay--visible", to: "#sidebar-overlay")
          }
        >
          <.icon name="hero-bars-3" class="size-6" />
        </button>
        <.link href={~p"/portal"} class="portal-mobile-logo">
          <img src={~p"/images/logo.svg"} alt="OpenLLP" class="h-6 dark:hidden" />
          <img src={~p"/images/logo-light.svg"} alt="OpenLLP" class="h-6 hidden dark:block" />
        </.link>
      </header>

      <%!-- Mobile overlay --%>
      <div
        id="sidebar-overlay"
        class="sidebar-overlay"
        phx-click={
          JS.remove_class("sidebar--open", to: "#sidebar")
          |> JS.remove_class("sidebar-overlay--visible", to: "#sidebar-overlay")
        }
      >
      </div>

      <main class="portal-main">
        <div class={@container_class}>
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the collapsible sidebar for portal pages.
  """
  attr :current_scope, :map, required: true
  attr :active_nav, :string, default: "home"

  def sidebar(assigns) do
    ~H"""
    <aside id="sidebar" class="sidebar" aria-label="Main navigation">
      <%!-- Header: Logo + Toggle --%>
      <div class="sidebar-header">
        <.link href={~p"/portal"} class="sidebar-logo">
          <img
            src={~p"/images/logo.svg"}
            alt="OpenLLP"
            class="sidebar-logo-img sidebar-logo-img--light"
          />
          <img
            src={~p"/images/logo-light.svg"}
            alt="OpenLLP"
            class="sidebar-logo-img sidebar-logo-img--dark"
          />
        </.link>
        <button
          type="button"
          class="sidebar-toggle"
          aria-label="Toggle sidebar"
          aria-expanded="true"
          phx-click={JS.dispatch("sidebar:toggle")}
        >
          <.icon name="hero-chevron-left" class="sidebar-toggle-icon" />
        </button>
      </div>

      <%!-- Navigation --%>
      <nav class="sidebar-nav">
        <.sidebar_link
          href={~p"/portal"}
          icon="hero-home"
          label="Dashboard"
          active={@active_nav == "home"}
        />
        <.sidebar_link
          href={~p"/docs"}
          icon="hero-book-open"
          label="Documentation"
          active={@active_nav == "docs"}
        />
        <.sidebar_link
          href={~p"/settings"}
          icon="hero-cog-6-tooth"
          label="Settings"
          active={@active_nav == "settings"}
        />
      </nav>

      <%!-- Footer: Profile --%>
      <div class="sidebar-footer">
        <div class="sidebar-profile">
          <button
            type="button"
            class="sidebar-profile-btn"
            phx-click={
              JS.toggle(
                to: "#sidebar-profile-menu",
                in:
                  {"transition-all ease-out duration-150", "opacity-0 translate-y-2",
                   "opacity-100 translate-y-0"},
                out:
                  {"transition-all ease-in duration-100", "opacity-100 translate-y-0",
                   "opacity-0 translate-y-2"}
              )
            }
          >
            <div
              class="sidebar-avatar"
              style={"background-color: #{avatar_color(@current_scope.organization)}"}
            >
              {profile_initial(@current_scope.organization)}
            </div>
            <span class="sidebar-profile-name">
              {@current_scope.organization.name || "Organization"}
            </span>
          </button>

          <div
            id="sidebar-profile-menu"
            class="sidebar-dropdown"
            style="display: none;"
            phx-click-away={
              JS.hide(
                to: "#sidebar-profile-menu",
                transition:
                  {"transition-all ease-in duration-100", "opacity-100 translate-y-0",
                   "opacity-0 translate-y-2"}
              )
            }
          >
            <div class="sidebar-dropdown-header"></div>
            <.link navigate={~p"/settings"} class="sidebar-dropdown-item">
              <.icon name="hero-cog-6-tooth" class="size-4" />
              <span>Settings</span>
            </.link>
            <%!-- Theme toggle --%>
            <div class="sidebar-dropdown-item sidebar-dropdown-item--theme">
              <div class="sidebar-dropdown-theme-label">
                <.icon name="hero-moon" class="size-4" />
                <span>Theme</span>
              </div>
              <.theme_toggle />
            </div>
          </div>
        </div>
      </div>

      <%!-- Mobile close button --%>
      <button
        type="button"
        class="sidebar-close-mobile"
        aria-label="Close menu"
        phx-click={
          JS.remove_class("sidebar--open", to: "#sidebar")
          |> JS.remove_class("sidebar-overlay--visible", to: "#sidebar-overlay")
        }
      >
        <.icon name="hero-x-mark" class="size-5" />
      </button>
    </aside>
    """
  end

  @doc """
  Renders a sidebar navigation link.
  """
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  def sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={["sidebar-link", @active && "sidebar-link--active"]}
      data-label={@label}
      aria-current={@active && "page"}
    >
      <.icon name={@icon} class="sidebar-link-icon" />
      <span class="sidebar-link-label">{@label}</span>
    </.link>
    """
  end

  @doc """
  Renders the site footer with links, social icons, and copyright.
  """
  def site_footer(assigns) do
    ~H"""
    <footer class="site-footer">
      <%!-- Logo + Copyright (left) --%>
      <div class="site-footer__left">
        <img
          src={~p"/images/logo.svg"}
          alt="OpenLLP"
          class="site-footer__logo site-footer__logo--light"
        />
        <img
          src={~p"/images/logo-light.svg"}
          alt="OpenLLP"
          class="site-footer__logo site-footer__logo--dark"
        />
        <span class="site-footer__copy">© {Date.utc_today().year} OpenLLP</span>
      </div>
    </footer>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides a single-button dark/light toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <button
      id="theme-toggle"
      type="button"
      class="theme-toggle-single"
      data-phx-theme="dark"
      phx-hook="ThemeToggle"
      aria-label={gettext("Switch to dark mode")}
    >
      <span class="theme-toggle-single__icon" aria-hidden="true">☾</span>
    </button>
    """
  end

  defp profile_initial(nil), do: "?"

  defp profile_initial(%{name: name, email: email}) do
    cond do
      is_binary(name) && String.trim(name) != "" ->
        name |> String.trim() |> String.first() |> String.upcase()

      is_binary(email) && email != "" ->
        email |> String.first() |> String.upcase()

      true ->
        "?"
    end
  end

  @doc """
  Generates a soft pastel background color based on the organization.
  Uses a hash of the name/email to create a consistent hue.
  """
  def avatar_color(nil), do: "hsl(0, 70%, 85%)"

  def avatar_color(%{name: name, email: email}) do
    # Use name or email to generate a consistent hash
    seed =
      cond do
        is_binary(name) && String.trim(name) != "" -> name
        is_binary(email) && email != "" -> email
        true -> "default"
      end

    # Generate a hue (0-360) from the string hash
    hue = :erlang.phash2(seed, 360)

    # Soft pastel: moderate saturation, high lightness
    "hsl(#{hue}, 65%, 80%)"
  end
end
