defmodule PlatformWeb.HomeLive.Settings do
  use PlatformWeb, :live_view

  alias Platform.Account
  alias Platform.Agent

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.portal_app
      flash={@flash}
      current_scope={@current_scope}
      active_nav="settings"
      container_class="mx-auto max-w-2xl"
    >
      <div class="text-center">
        <.header>
          Settings
          <:subtitle>Manage your organization and API keys</:subtitle>
        </.header>
      </div>

      <.settings_nav live_action={@live_action} />

      <%!-- Profile tab: Organization Name --%>
      <div :if={@live_action == :profile} class="space-y-6">
        <div class="settings-card">
          <div class="settings-card__header">
            <div>
              <h2 class="settings-card__title">Organization Name</h2>
              <p class="settings-card__subtitle">Your organization's display name</p>
            </div>
          </div>
          <div class="settings-card__body">
            <.form for={@name_form} id="name_form" phx-submit="update_name" phx-change="validate_name">
              <.input
                field={@name_form[:name]}
                type="text"
                placeholder="e.g., Acme Corp"
                required
              />
              <p class="settings-card__helper">Shown in the portal.</p>
              <.button variant="primary" phx-disable-with="Saving...">Save Name</.button>
              <.inline_feedback feedback={@name_feedback} />
            </.form>
          </div>
        </div>
      </div>

      <%!-- API Keys tab --%>
      <div :if={@live_action == :api_keys} class="space-y-6">
        <div class="settings-card">
          <div class="settings-card__header">
            <div>
              <h2 class="settings-card__title">API Key</h2>
              <p class="settings-card__subtitle">Authenticate your agents with the platform</p>
            </div>
          </div>
          <div class="settings-card__body">
            <%!-- One-time key reveal after generation --%>
            <div :if={@newly_generated_key} class="api-key-reveal">
              <div class="feedback feedback--success">
                <.icon name="hero-check-circle" class="size-4" />
                <span>New API key generated!</span>
              </div>

              <div class="api-key-display" style="margin: 1rem 0;">
                <code id="api-key-value">{@newly_generated_key}</code>
                <button
                  type="button"
                  class={["copy-btn", @key_copied && "copied"]}
                  phx-hook="CopyToClipboard"
                  id="copy-key-btn"
                  data-copy-target="api-key-value"
                  aria-label={if @key_copied, do: "Copied", else: "Copy to clipboard"}
                >
                  <.icon
                    name={if @key_copied, do: "hero-check", else: "hero-clipboard"}
                    class="size-4"
                  />
                </button>
              </div>

              <div class="warning-text" style="margin-bottom: 1rem;">
                <.icon name="hero-exclamation-triangle" class="size-5" />
                <span>Copy this key now. You won't be able to see it again.</span>
              </div>

              <.button variant="secondary" phx-click="dismiss_key_reveal">
                Done
              </.button>
            </div>

            <%!-- Normal view: show existing key info or generate button --%>
            <div :if={!@newly_generated_key}>
              <%= if @api_keys != [] do %>
                <% api_key = List.first(@api_keys) %>
                <div class="api-key-info">
                  <div class="api-key-row">
                    <span class="api-key-label">Current key:</span>
                    <code class="api-key-prefix">{redact_key(api_key.hashed_key)}</code>
                  </div>
                  <div class="api-key-row">
                    <span class="api-key-label">Created:</span>
                    <span>{format_date(api_key.inserted_at)}</span>
                  </div>
                </div>

                <div class="warning-text" style="margin: 1rem 0;">
                  <.icon name="hero-exclamation-triangle" class="size-5" />
                  <span>Regenerating will invalidate your current key immediately.</span>
                </div>

                <.button
                  variant="danger"
                  phx-click="regenerate_api_key"
                  data-confirm="Are you sure? This will invalidate your current API key immediately. Any agents using the old key will stop working."
                >
                  <.icon name="hero-arrow-path" class="size-4" /> Regenerate Key
                </.button>
              <% else %>
                <p class="settings-card__helper" style="margin-bottom: 1rem;">
                  No API key generated yet. Generate one to authenticate your agents.
                </p>

                <.button variant="primary" phx-click="generate_api_key">
                  <.icon name="hero-key" class="size-4" /> Generate API Key
                </.button>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.portal_app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    organization = socket.assigns.current_scope.organization
    scope = socket.assigns.current_scope

    name_changeset = Account.change_organization_name(organization, %{})

    socket =
      socket
      |> assign(:name_form, to_form(name_changeset))
      |> assign(:name_feedback, nil)
      |> assign(:api_keys, Agent.list_api_keys(scope))
      |> assign(:newly_generated_key, nil)
      |> assign(:key_copied, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_name", params, socket) do
    %{"organization" => organization_params} = params

    name_form =
      socket.assigns.current_scope.organization
      |> Account.change_organization_name(organization_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, name_form: name_form)}
  end

  def handle_event("update_name", params, socket) do
    %{"organization" => organization_params} = params
    organization = socket.assigns.current_scope.organization

    case Account.update_organization_name(organization, organization_params) do
      {:ok, updated_org} ->
        name_form =
          updated_org
          |> Account.change_organization_name(%{})
          |> to_form()

        {:noreply,
         socket
         |> assign(:name_form, name_form)
         |> assign(:name_feedback, {:success, "Organization name updated"})}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:name_form, to_form(changeset, action: :insert))
         |> assign(:name_feedback, {:error, "Failed to update name"})}
    end
  end

  # API Key event handlers

  def handle_event("generate_api_key", _, socket) do
    scope = socket.assigns.current_scope

    case Agent.generate_api_key(scope) do
      {:ok, api_key} ->
        {:noreply,
         socket
         |> assign(:api_keys, [api_key])
         |> assign(:newly_generated_key, api_key.key)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate API key. Please try again.")}
    end
  end

  def handle_event("regenerate_api_key", _, socket) do
    scope = socket.assigns.current_scope

    # Delete existing keys and generate a new one
    Agent.delete_api_keys(scope)

    case Agent.generate_api_key(scope) do
      {:ok, api_key} ->
        {:noreply,
         socket
         |> assign(:api_keys, [api_key])
         |> assign(:newly_generated_key, api_key.key)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to regenerate API key. Please try again.")}
    end
  end

  def handle_event("dismiss_key_reveal", _, socket) do
    {:noreply,
     socket
     |> assign(:newly_generated_key, nil)
     |> assign(:key_copied, false)}
  end

  def handle_event("copy_key", _, socket) do
    {:noreply, assign(socket, :key_copied, true)}
  end

  # Inline feedback component
  defp inline_feedback(assigns) do
    ~H"""
    <div
      :if={@feedback}
      class={[
        "feedback",
        elem(@feedback, 0) == :success && "feedback--success",
        elem(@feedback, 0) == :error && "feedback--error"
      ]}
    >
      <.icon :if={elem(@feedback, 0) == :success} name="hero-check-circle" class="size-4" />
      <.icon :if={elem(@feedback, 0) == :error} name="hero-exclamation-circle" class="size-4" />
      <span>{elem(@feedback, 1)}</span>
    </div>
    """
  end

  # Settings tab navigation
  defp settings_nav(assigns) do
    ~H"""
    <nav class="settings-nav">
      <.link
        navigate={~p"/settings"}
        class={["settings-nav__tab", @live_action == :profile && "settings-nav__tab--active"]}
      >
        Profile
      </.link>
      <.link
        navigate={~p"/settings/api-keys"}
        class={["settings-nav__tab", @live_action == :api_keys && "settings-nav__tab--active"]}
      >
        API Keys
      </.link>
    </nav>
    """
  end

  # Helper functions

  defp redact_key(hashed_key) when is_binary(hashed_key) do
    String.slice(hashed_key, 0, 4) <> "..."
  end

  defp redact_key(_), do: "..."

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_date(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_date(_), do: "Unknown"
end
