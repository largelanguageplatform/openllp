defmodule PlatformWeb.HomeLive.SetupApiKey do
  use PlatformWeb, :live_view

  alias Platform.Agent

  @moduledoc """
  First-time API key setup page.

  Displays a split-layout with hero on left and API key generation card on right.
  Users must generate an API key before accessing the dashboard.
  """

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    # If user already has keys, redirect to dashboard
    if Agent.has_api_key?(scope) do
      {:ok, push_navigate(socket, to: ~p"/portal")}
    else
      socket =
        socket
        |> assign(key: nil)
        |> assign(copied?: false)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="split-layout">
      <%!-- Theme toggle in top right --%>
      <div class="split-layout__header">
        <Layouts.theme_toggle />
      </div>

      <div class="split-layout__left">
        <%!-- Floating origami decorations --%>
        <div class="origami-container" aria-hidden="true">
          <.origami_crane class="origami-shape origami-crane-1" />
          <.origami_spaceship class="origami-shape origami-ship-1" />
          <.origami_robot class="origami-shape origami-robot-1" />
          <.origami_star class="origami-shape origami-star-1" />
          <.origami_crane class="origami-shape origami-crane-2" />
        </div>

        <%!-- Brand hero: Logo + "Almost there" --%>
        <div class="brand-hero">
          <img
            src={~p"/images/logo-light.svg"}
            alt="OpenLLP"
            class="brand-hero__logo"
          />
          <p class="brand-hero__text">
            <.rocket_icon class="brand-hero__rocket" />
            <span>Almost there ...</span>
          </p>
        </div>
      </div>

      <div class="split-layout__right">
        <div class="api-key-card">
          <%!-- Flash error display --%>
          <div :if={@flash[:error]} class="feedback feedback--error" style="margin-bottom: 1rem;">
            <.icon name="hero-exclamation-circle" class="size-4" />
            <span>{@flash[:error]}</span>
          </div>

          <%= if @key == nil do %>
            <.generate_key_view />
          <% else %>
            <.show_key_view key={@key} copied?={@copied?} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp generate_key_view(assigns) do
    ~H"""
    <h1>Generate Your API Key</h1>
    <p class="subtext">
      Before accessing the dashboard, you need to create an API key.
      This key authenticates your agents with the platform.
    </p>

    <form phx-submit="generate_key" id="generate-key-form">
      <button type="submit" class="btn-primary btn-full" phx-disable-with="Generating...">
        <.icon name="hero-key" class="size-5" />
        <span>Generate API Key</span>
      </button>
    </form>
    """
  end

  defp show_key_view(assigns) do
    ~H"""
    <h1>Your API Key</h1>
    <p class="subtext">
      Copy this key now. You won't be able to see it again.
    </p>

    <div class="api-key-display">
      <code id="api-key-value">{@key}</code>
      <button
        type="button"
        class={["copy-btn", @copied? && "copied"]}
        phx-hook="CopyToClipboard"
        id="copy-key-btn"
        data-copy-target="api-key-value"
        aria-label={if @copied?, do: "Copied", else: "Copy to clipboard"}
      >
        <.icon name={if @copied?, do: "hero-check", else: "hero-clipboard"} class="size-4" />
      </button>
    </div>

    <div class="warning-text">
      <.icon name="hero-exclamation-triangle" class="size-5" />
      <span>Store this key securely. It cannot be retrieved later.</span>
    </div>

    <.link navigate={~p"/portal"} class="btn-primary btn-full">
      Continue to Dashboard
    </.link>
    """
  end

  # Event handlers

  def handle_event("generate_key", _params, socket) do
    # Use the authenticated scope from socket, NOT form params (security)
    scope = socket.assigns.current_scope

    case Agent.generate_api_key(scope) do
      {:ok, api_key} ->
        {:noreply, assign(socket, key: api_key.key)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate API key. Please try again.")}
    end
  end

  def handle_event("copy_key", _params, socket) do
    {:noreply, assign(socket, copied?: true)}
  end
end
