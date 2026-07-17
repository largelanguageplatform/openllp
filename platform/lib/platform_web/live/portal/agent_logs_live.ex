defmodule PlatformWeb.Portal.AgentLogsLive do
  @moduledoc """
  Agent Logs page - Chat-style interface for viewing agent conversations.

  Features:
  - Conversations sidebar (grouped by peer_name)
  - Message panel with expand/collapse for long messages
  - Real-time message streaming
  - Mobile two-screen navigation
  """
  use PlatformWeb, :live_view
  require Logger

  alias Platform.Conversations
  alias Platform.Agent.Manager
  alias Platform.Agent

  # ============================================
  # MOUNT
  # ============================================

  def mount(%{"agent_name" => agent_name}, _session, socket) do
    scope = socket.assigns.current_scope
    org_id = scope.organization.id

    agent = Agent.get_agent_by_name(scope, agent_name)

    if is_nil(agent) do
      {:ok,
       socket
       |> put_flash(:error, "Agent not found")
       |> push_navigate(to: ~p"/portal")}
    else
      convos = Conversations.get_all_conversations_by_agent(agent)
      selected_convo = List.first(convos)

      messages =
        Conversations.get_conversation_messages_by_conversation_id(Map.get(selected_convo, :id))

      # Check if agent is online
      is_online =
        case Manager.get_session(agent_name) do
          {:ok, _pid} -> true
          _ -> false
        end

      # Subscribe to updates
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Platform.PubSub, "agents:#{agent.id}:msgs:#{selected_convo.id}")
        Phoenix.PubSub.subscribe(Platform.PubSub, "agents:updates:#{org_id}")
        Phoenix.PubSub.subscribe(Platform.PubSub, "agents:#{agent.id}")
      end

      {:ok,
       socket
       |> assign(agent: agent)
       |> assign(agent_name: agent_name)
       |> assign(is_online: is_online)
       |> assign(selected: selected_convo)
       |> assign(mobile_view: :list)
       |> assign(conversation_count: Conversations.get_conversation_count_by_agent(agent))
       |> assign(message_count: length(messages))
       |> stream(:conversations, convos)
       |> stream(:messages, messages)}
    end
  end

  # ============================================
  # EVENT HANDLERS
  # ============================================
  def handle_event("select-conversation", %{"conversation" => id}, socket) do
    prev_selected = socket.assigns.selected

    if prev_selected.id != String.to_integer(id) do
      convo = Conversations.get_conversation_by_id(id)

      convo = %{
        id: convo.id,
        test_result: convo.test_result,
        display_name: convo.display_name,
        inserted_at: convo.inserted_at,
        session: convo.agent_session.session
      }

      messages = Conversations.get_conversation_messages_by_conversation_id(convo.id)

      socket =
        socket
        |> assign(selected: convo)
        |> assign(mobile_view: :messages)
        |> assign(message_count: length(messages))
        |> stream_insert(:conversations, convo, update_only: true)
        |> stream(:messages, messages, reset: true)

      if connected?(socket) do
        agent = socket.assigns.agent
        Phoenix.PubSub.subscribe(Platform.PubSub, "agents:#{agent.id}:msgs:#{id}")

        if prev_selected != nil do
          Phoenix.PubSub.unsubscribe(
            Platform.PubSub,
            "agents:#{agent.id}:msgs:#{prev_selected.id}"
          )

          {:noreply, socket |> stream_insert(:conversations, prev_selected, update_only: true)}
        else
          {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # ============================================
  # PUBSUB HANDLERS
  # ============================================

  def handle_info({:add_message, message}, socket) do
    if message.session_conversation_id == socket.assigns.selected.id do
      socket =
        socket
        |> stream_insert(:messages, message)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:conversation_update, session_conversation}, socket) do
    count = Conversations.get_conversation_count_by_agent(socket.assigns.agent)

    convo = %{
      id: session_conversation.id,
      test_result: session_conversation.test_result,
      display_name: session_conversation.display_name,
      inserted_at: session_conversation.inserted_at,
      session: session_conversation.agent_session.session
    }

    {:noreply,
     socket
     |> assign(conversation_count: count)
     |> stream_insert(:conversations, convo, at: 0)}
  end

  def handle_info({:refresh, %{name: name, is_online: online}}, socket) do
    if name == socket.assigns.agent_name do
      {:noreply, assign(socket, is_online: online)}
    else
      {:noreply, socket}
    end
  end

  # ============================================
  # RENDER
  # ============================================

  def render(assigns) do
    ~H"""
    <Layouts.portal_app
      flash={@flash}
      current_scope={@current_scope}
      container_class="mx-auto max-w-7xl"
      active_nav="home"
    >
      <div class="logs-page">
        <header class="logs-page-header">
          <div class="logs-header-left">
            <.link navigate={~p"/portal"} class="logs-back-btn">
              <.icon name="hero-arrow-left-mini" /> Back
            </.link>
            <div class="logs-header-title">
              <h1>{@agent_name}</h1>
              <span class={["logs-status-badge", @is_online && "online"]}>
                <span class="status-dot"></span>
                {if @is_online, do: "Online", else: "Offline"}
              </span>
            </div>
          </div>
        </header>

        <div class={["logs-chat-layout", @mobile_view == :messages && "mobile-messages-view"]}>
          <.conversations_sidebar
            conversations={@streams.conversations}
            count={@conversation_count}
            selected={@selected.id}
            mobile_view={@mobile_view}
          />

          <main class={["logs-panel", @mobile_view == :list && "mobile-hidden"]}>
            <.message_panel
              :if={@message_count > 0}
              selected={@selected}
              messages={@streams.messages}
              count={@message_count}
              mobile_view={@mobile_view}
              agent_name={@agent_name}
            />
            <div :if={@message_count == 0} class="logs-panel-empty">
              <.icon name="hero-inbox" class="empty-icon" />
              <span>No messages yet</span>
            </div>
          </main>
        </div>
      </div>
    </Layouts.portal_app>
    """
  end

  # ============================================
  # FUNCTION COMPONENTS
  # ============================================

  attr :conversations, :list, required: true
  attr :count, :integer, required: true
  attr :selected, :integer, default: nil
  attr :mobile_view, :atom, required: true

  defp conversations_sidebar(assigns) do
    ~H"""
    <aside class={["logs-sidebar", @mobile_view == :messages && "mobile-hidden"]}>
      <div class="logs-sidebar-header">
        <span class="logs-sidebar-title">Conversations</span>
        <span class="logs-sidebar-count">{@count}</span>
      </div>

      <div :if={@count == 0} class="logs-sidebar-empty">
        <.icon name="hero-chat-bubble-left-right" class="empty-icon" />
        <span>No conversations yet</span>
      </div>
      <div class="logs-sidebar-list" id="conversations" phx-update="stream">
        <.conversation_item
          :for={{dom_id, conv} <- @conversations}
          conversation={conv}
          id={dom_id}
          is_selected={conv.id == @selected}
        />
      </div>
    </aside>
    """
  end

  attr :conversation, :map, required: true
  attr :is_selected, :boolean, default: false
  attr :id, :integer, required: true

  defp conversation_item(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      class={["conversation-item", @is_selected && "selected", @conversation.test_result]}
      phx-click="select-conversation"
      phx-value-conversation={@conversation.id}
      aria-current={@is_selected && "true"}
    >
      <div class="conversation-item-header">
        <.status_icon test_result={@conversation.test_result} />
        <span class="conversation-peer-name">{@conversation.display_name}</span>
        <span class="conversation-preview">{@conversation.session}</span>
        <span class="conversation-time">{format_time_ago(@conversation.inserted_at)}</span>
      </div>
    </button>
    """
  end

  attr :test_result, :atom, required: true

  defp status_icon(%{test_result: :inprogress} = assigns) do
    ~H"""
    <.icon name="hero-clock" class="bg-gray-500" />
    """
  end

  defp status_icon(%{test_result: :incomplete} = assigns) do
    ~H"""
    <.icon name="hero-exclamation-triangle" class="bg-amber-500" />
    """
  end

  defp status_icon(%{test_result: :fail} = assigns) do
    ~H"""
    <.icon name="hero-x-circle" class="bg-red-500" />
    """
  end

  defp status_icon(%{test_result: :pass} = assigns) do
    ~H"""
    <.icon name="hero-check-circle" class="bg-green-500" />
    """
  end

  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  attr :selected, :map, default: nil
  attr :messages, :any, required: true
  attr :count, :integer, required: true
  attr :agent_name, :string, required: true
  attr :mobile_view, :atom, required: true

  defp message_panel(assigns) do
    ~H"""
    <div class="logs-panel-header">
      <button type="button" class="logs-panel-back" phx-click="back-to-list">
        <.icon name="hero-arrow-left-mini" /> Conversations
      </button>
      <div class="logs-panel-title">
        <.status_icon test_result={@selected.test_result} />
        <span class="logs-panel-peer">{@selected.display_name}</span>
        <span class="logs-panel-count">
          {@count} messages
        </span>
      </div>
    </div>

    <div
      class="logs-messages-container"
      id="logs-messages-container"
      aria-live="polite"
    >
      <div class="logs-messages" id="logs-messages" phx-update="stream">
        <.message_capsule
          :for={{dom_id, msg} <- @messages}
          id={dom_id}
          message={msg}
          from={@selected.display_name}
          agent_name={@agent_name}
          details={annotation_details(msg)}
        />
      </div>
    </div>
    """
  end

  def annotation_details(%{direction: :annotation, annotation_details: details}) do
    details = Jason.decode!(details, keys: :atoms)

    case Jason.decode(details.parameters) do
      {:ok, params} ->
        Map.merge(details, %{parameters: params, use_table: true})

      {:error, _} ->
        Map.put(details, :use_table, false)
    end
  end

  def annotation_details(_), do: %{}

  def annotation_class(%{threw_exception: true}),
    do: "collapse collapse-arrow bg-red-100 border-red-300 border"

  def annotation_class(%{threw_exception: false}),
    do: "collapse collapse-arrow bg-blue-100 border-blue-300 border"

  attr :id, :string, required: true
  attr :from, :string, required: true
  attr :agent_name, :string, required: true
  attr :message, :map, required: true
  attr :details, :map

  defp message_capsule(%{message: %{direction: :annotation}} = assigns) do
    ~H"""
    <div
      title="tool call"
      class={["message-animate", "dark:text-base-100", annotation_class(@details)]}
      id={@id}
    >
      <input type="checkbox" />
      <div class="collapse-title font-semibold">
        <.icon :if={!@details.threw_exception} name="hero-bolt" class="bg-yellow-500 mr-5" />
        <.icon :if={@details.threw_exception} name="hero-bolt-slash" class="bg-red-500 mr-5" />
        <span class="message-from-name mr-2">{@details.name}</span>
        <span class="message-time">{@message.inserted_at}</span>
      </div>
      <div class="collapse-content">
        <div :if={@details.use_table}>
          <b>Arguments: </b>
          <ul class="list-disc ml-8">
            <li :for={{name, value} <- @details.parameters}><b>{name}: </b>{value}</li>
          </ul>
        </div>
        <div :if={!@details.use_table}>
          <b>Raw Arguments: </b>{@details.parameters}
        </div>
        <div :if={!@details.threw_exception}>
          <b>Returned: </b>{@details.result}
        </div>
        <div :if={@details.threw_exception}>
          <b>Exception: </b><pre class="ml-8">{@details.result}</pre>
        </div>
        <div>
          <b>Duration: </b>{@details.duration_ms / 1000.0} seconds
        </div>
      </div>
    </div>
    """
  end

  defp message_capsule(assigns) do
    ~H"""
    <div
      class={[
        "message-capsule",
        "message-animate",
        @message.direction
      ]}
      id={@id}
      phx-hook="ExpandableMessage"
    >
      <div class="message-meta">
        <span class="message-from">
          <span :if={@message.direction == :inbound} class="message-from-name">{@from}</span>
          <span :if={@message.direction == :outbound} class="message-from-name">{@agent_name}</span>
        </span>
        <span class="message-time">{@message.inserted_at}</span>
        <button
          type="button"
          class="message-copy-btn"
          phx-hook="CopyToClipboard"
          id={"copy-#{@message.id}"}
          data-content={Base.decode64!(@message.prompt)}
          title="Copy message"
        >
          <.icon name="hero-clipboard-document-mini" />
        </button>
      </div>

      <div class="message-body clamped">
        <div class="message-content">
          <pre>{Base.decode64!(@message.prompt)}</pre>
        </div>
        <div class="message-body-fade"></div>
      </div>

      <%= if @message.attachment && @message.attachment != "" do %>
        <div class="message-attachment">
          <.icon name="hero-paper-clip-mini" />
          <.link href={get_attachment_url(@agent_name, @message.attachment)} class="attachment-link">
            {@message.attachment}
          </.link>
        </div>
      <% end %>

      <button type="button" class="message-expand-toggle" aria-expanded="false">
        Show full ↓
      </button>
    </div>
    """
  end

  defp get_attachment_url(name, attachment), do: ~p"/uploads/#{name}/#{attachment}"
end
