defmodule PlatformWeb.Portal.DashboardLive do
  use PlatformWeb, :live_view
  require Logger

  alias Platform.Agent
  alias Platform.Agent.Session

  @moduledoc """
  Real-time agent dashboard.

  Automatically updates when agents connect/disconnect or send messages.
  Uses Phoenix PubSub for server-side events and LiveView for browser updates.
  """

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    oid = scope.organization.id

    # Redirect to API key setup if user has no keys
    if not has_keys?(scope) do
      {:ok, push_navigate(socket, to: ~p"/setup/api-key")}
    else
      if connected?(socket) do
        channel = "agents:updates:" <> :erlang.integer_to_binary(oid)
        Logger.debug("Subscribing to channel #{channel}")
        Phoenix.PubSub.subscribe(Platform.PubSub, channel)
      end

      # Show nudge only if org name hasn't been customized yet
      show_nudge = not scope.organization.name_customized

      socket =
        socket
        |> assign(org: oid)
        |> assign(agents: list_connected_agents(scope))
        |> assign(show_org_name_nudge?: show_nudge)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.portal_app
      flash={@flash}
      current_scope={@current_scope}
      container_class="mx-auto max-w-5xl space-y-6"
      active_nav="home"
    >
      <.org_name_nudge :if={@show_org_name_nudge?} />
      <.dashboard agents={@agents} org_name={@current_scope.organization.name} />
    </Layouts.portal_app>
    """
  end

  defp org_name_nudge(assigns) do
    ~H"""
    <div class="org-name-nudge" id="org-nudge" phx-hook="OrgNudge" style="display:none">
      <span class="nudge-text">Name your organization in</span>
      <.link navigate={~p"/settings"} class="nudge-link">Settings</.link>
      <button
        type="button"
        phx-click="dismiss_org_nudge"
        phx-hook="DismissNudge"
        id="dismiss-nudge"
        class="nudge-skip"
      >
        Skip for now
      </button>
    </div>
    """
  end

  defp dashboard(assigns) do
    ~H"""
    <div class="app-shell">
      <header class="app-header">
        <h1><span :if={@org_name && @org_name != ""}>{@org_name} </span>Dashboard</h1>
        <p>Real-time activity</p>
      </header>

      <main class="app-main">
        <% connected_count = Enum.count(@agents, & &1.is_online) %>
        <div class="stats-container grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div class="stat-card border-t-2 border-emerald-500/70">
            <div class="flex items-center justify-between">
              <div class="stat-label">Connected Agents</div>
              <div class={[
                "flex items-center gap-2",
                connected_count > 0 && "text-emerald-400",
                connected_count == 0 && "text-zinc-500"
              ]}>
                <span class={[
                  "relative inline-flex h-2.5 w-2.5",
                  connected_count > 0 || "invisible"
                ]}>
                  <span class="absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75 animate-ping">
                  </span>
                  <span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-500"></span>
                </span>
                <.icon name="hero-wifi" class="h-4 w-4" />
              </div>
            </div>
            <div class={[
              "stat-value",
              connected_count > 0 && "text-emerald-400",
              connected_count == 0 && "text-zinc-200"
            ]}>
              {connected_count}
            </div>
            <div class="stat-desc">Currently online</div>
          </div>
          <div class="stat-card border-t-2 border-sky-500/70">
            <div class="flex items-center justify-between">
              <div class="stat-label">Registered Agents</div>
              <div class="flex items-center gap-2 text-sky-400">
                <.icon name="hero-server-stack" class="h-4 w-4" />
              </div>
            </div>
            <div class="stat-value text-zinc-200 text-3xl font-semibold">
              {length(@agents)}
            </div>
            <div class="stat-desc">Total registered</div>
          </div>
        </div>

        <%= if @agents == [] do %>
          <div class="empty-state">
            <div class="empty-state__icon">
              <.icon name="hero-clock" class="empty-state__hero-icon" />
            </div>
            <h3 class="empty-state__title">Waiting for Agents to connect</h3>
            <p class="empty-state__desc">
              Check <.link navigate={~p"/docs"} class="empty-state__link">Documentation</.link>
              for instructions.
            </p>
          </div>
        <% else %>
          <div
            id="agents-table"
            class="border border-zinc-200 dark:border-zinc-800 rounded-xl overflow-hidden bg-white dark:bg-transparent"
          >
            <%!-- Table Header --%>
            <div class="grid grid-cols-12 gap-4 px-6 py-3 bg-zinc-50 dark:bg-zinc-900/50 border-b border-zinc-200 dark:border-zinc-800 text-xs font-medium text-zinc-500 uppercase tracking-wider">
              <div class="col-span-3">Agent Name</div>
              <div class="col-span-2">Status</div>
              <div class="col-span-3">Session ID</div>
              <div class="col-span-2 text-center">Messages</div>
              <div class="col-span-2 text-right">Actions</div>
            </div>

            <%!-- Table Rows --%>
            <div
              :for={agent <- @agents}
              id={"agent-#{agent.name}"}
              class="grid grid-cols-12 gap-4 px-6 py-3.5 items-center border-b border-zinc-100 dark:border-zinc-800/50 last:border-b-0 transition-colors duration-150 hover:bg-zinc-50 dark:hover:bg-zinc-900/30"
            >
              <div class="col-span-3 min-w-0">
                <span class="font-medium text-zinc-900 dark:text-white text-sm truncate block">
                  {agent.name}
                </span>
              </div>
              <div class="col-span-2">
                <%= if agent.is_online do %>
                  <span class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium rounded-md bg-emerald-100 dark:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400">
                    <span class="relative inline-flex h-1.5 w-1.5">
                      <span class="absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75 animate-ping">
                      </span>
                      <span class="relative inline-flex h-1.5 w-1.5 rounded-full bg-emerald-500">
                      </span>
                    </span>
                    Online
                  </span>
                <% else %>
                  <span class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium rounded-md bg-zinc-100 dark:bg-zinc-500/20 text-zinc-500 dark:text-zinc-400">
                    <span class="inline-flex h-1.5 w-1.5 rounded-full bg-zinc-400 dark:bg-zinc-500">
                    </span>
                    Offline
                  </span>
                <% end %>
              </div>
              <div class="col-span-3 min-w-0">
                <span class="text-sm text-zinc-500 dark:text-zinc-400 font-mono truncate block">
                  {agent.session_id || "—"}
                </span>
              </div>
              <div class="col-span-2 text-center">
                <span class="text-sm text-zinc-500 dark:text-zinc-400 tabular-nums">
                  {agent.message_count}
                </span>
              </div>
              <div class="col-span-2 text-right">
                <.link
                  navigate={~p"/portal/agents/#{agent.name}/logs"}
                  class="text-emerald-600 dark:text-emerald-500 hover:text-emerald-500 dark:hover:text-emerald-400 text-sm font-medium transition-all duration-150"
                >
                  View Logs
                </.link>
              </div>
            </div>
          </div>
        <% end %>

        <div class="footer-hint">
          <p>💡 Dashboard updates automatically</p>
        </div>
      </main>
    </div>
    """
  end

  def handle_event("dismiss_org_nudge", _params, socket) do
    {:noreply, assign(socket, show_org_name_nudge?: false)}
  end

  def handle_info({:refresh, agent}, socket) do
    agents =
      socket.assigns.agents
      |> Enum.filter(fn %{name: name} -> name != agent.name end)

    agents =
      [agent | agents]
      |> Enum.sort_by(& &1.name)

    {:noreply, assign(socket, agents: agents)}
  end

  defp has_keys?(scope) do
    keys = Agent.list_api_keys(scope)
    length(keys) > 0
  end

  defp list_connected_agents(scope) do
    Agent.list_agents(scope)
    |> Enum.map(fn %{name: name} ->
      Session.refresh_update(name)

      %{
        name: name,
        session_id: nil,
        message_count: 0,
        is_online: false
      }
    end)
    |> Enum.sort_by(& &1.name)
  end
end
