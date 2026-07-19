defmodule PlatformWeb.AdminLive.Prompts do
  use PlatformWeb, :live_view

  alias Platform.Admin
  alias Platform.Agent.Domain

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-950 text-white flex">
      <.sidebar active_section={@active_section} />
      <main class="flex-1 p-6 overflow-auto">
        <%= case @active_section do %>
          <% :domains -> %>
            <.domains_section
              domains={@domains}
              adding={@adding}
              editing_id={@editing_id}
              form={@form}
            />
          <% :personas -> %>
            <.personas_section
              personas={@personas}
              domains={@domains}
              adding={@adding}
              editing_id={@editing_id}
              form={@form}
            />
          <% :admins -> %>
            <.admin_users_section
              admin_users={@admin_users}
              editing_id={@editing_id}
              form={@form}
            />
        <% end %>
      </main>
    </div>
    """
  end

  # --- Sidebar ---

  defp sidebar(assigns) do
    ~H"""
    <aside class="w-56 border-r border-zinc-800 bg-zinc-950 flex flex-col">
      <div class="p-6">
        <h1 class="text-lg font-semibold text-white">Admin</h1>
      </div>
      <nav class="flex-1 px-3 space-y-1">
        <.nav_item label="Agent Domains" section={:domains} active={@active_section} />
        <.nav_item label="Domain Personas" section={:personas} active={@active_section} />
        <.nav_item label="Admin Users" section={:admins} active={@active_section} />
      </nav>
      <div class="p-4 border-t border-zinc-800">
        <.link
          href={~p"/admin/logout"}
          method="delete"
          class="text-zinc-500 hover:text-white text-sm transition-all duration-150"
        >
          Logout
        </.link>
      </div>
    </aside>
    """
  end

  defp nav_item(assigns) do
    ~H"""
    <button
      phx-click="switch_section"
      phx-value-section={@section}
      class={[
        "w-full flex items-center px-3 py-2.5 text-sm transition-all cursor-pointer relative",
        @active == @section && "text-white bg-emerald-500/10 rounded-r-lg",
        @active != @section && "text-zinc-400 hover:text-white hover:bg-zinc-800/30 rounded-lg"
      ]}
    >
      <span
        :if={@active == @section}
        class="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-emerald-500 rounded-full"
      />
      {@label}
    </button>
    """
  end

  # --- Domains Section ---

  defp domains_section(assigns) do
    ~H"""
    <div class="max-w-8xl">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Agent Domains</h1>
          <p class="text-zinc-500 text-sm mt-1">Manage AI domains used for discovery</p>
        </div>
        <button
          :if={!@adding}
          phx-click="add_new_domain"
          class="px-4 py-2 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
        >
          Add New
        </button>
      </div>

      <%!-- Add New Domain Form --%>
      <div
        :if={@adding}
        class="mb-6 border border-zinc-800 rounded-xl overflow-hidden"
      >
        <div class="px-6 py-4 bg-zinc-900/50 border-b border-zinc-800">
          <h2 class="text-sm font-medium text-white">New Domain</h2>
        </div>
        <div class="px-6 py-5 bg-zinc-900/30">
          <.form for={@form} id="new-domain-form" phx-submit="create_domain">
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Name
              </label>
              <input
                type="text"
                name="name"
                value={@form[:name].value}
                class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                placeholder="Enter domain name..."
              />
            </div>
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Parent Domain
              </label>
              <select
                name="parent_domain"
                required
              >
                <option :for={domain <- @domains} value={domain.id}>{domain.name}</option>
              </select>
            </div>
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Description
              </label>
              <textarea
                name="description"
                rows="4"
                class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg p-4 text-sm resize-y outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                placeholder="Enter domain description..."
              >{@form[:description].value}</textarea>
            </div>
            <div class="flex justify-end gap-3">
              <button
                type="button"
                phx-click="cancel_domain"
                class="px-4 py-2 text-sm text-zinc-500 hover:text-zinc-300 transition-all duration-150 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-5 py-2.5 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
                phx-disable-with="Creating..."
              >
                Create Domain
              </button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- Domains Table --%>
      <div class="border border-zinc-800 rounded-xl overflow-hidden">
        <div class="grid grid-cols-12 gap-6 px-6 py-3 bg-zinc-900/50 border-b border-zinc-800 text-xs font-medium text-zinc-500 uppercase tracking-wider">
          <div class="col-span-1">Name</div>
          <div class="col-span-1">Parent</div>
          <div class="col-span-9">Description</div>
          <div class="col-span-1 text-right">Action</div>
        </div>

        <div :if={@domains == []} class="px-6 py-12 text-center text-zinc-500">
          No domains configured yet.
        </div>

        <div :for={domain <- @domains} id={"domain-#{domain.id}"}>
          <div class={[
            "grid grid-cols-12 gap-6 px-6 py-3.5 items-center border-b border-zinc-800/50 last:border-b-0 transition-colors duration-150",
            @editing_id == domain.id && "bg-zinc-900/30"
          ]}>
            <div class="col-span-1">
              <span class={[
                "inline-block px-2 py-0.5 text-xs font-medium rounded-md",
                domain_pill_classes(domain.name)
              ]}>
                {domain.name}
              </span>
            </div>
            <div class="col-span-1">
              <span
                :if={domain.parent_domain}
                class={[
                  "inline-block px-2 py-0.5 text-xs font-medium rounded-md",
                  domain_pill_classes(domain.parent_domain.name)
                ]}
              >
                {domain.parent_domain.name}
              </span>
            </div>
            <div class="col-span-9 min-w-0">
              <p class="text-sm text-zinc-400">{domain.description}</p>
            </div>
            <div class="col-span-1 text-right">
              <button
                :if={@editing_id != domain.id}
                phx-click="edit_domain"
                phx-value-id={domain.id}
                class="text-emerald-500 hover:text-emerald-400 text-sm font-medium transition-all duration-150 cursor-pointer"
              >
                Edit
              </button>
              <button
                :if={@editing_id == domain.id}
                phx-click="cancel_domain"
                class="text-zinc-500 hover:text-zinc-300 text-sm transition-all duration-150 cursor-pointer"
              >
                Cancel
              </button>
            </div>
          </div>

          <%!-- Edit Panel --%>
          <%= if @editing_id == domain.id do %>
            <div class="px-6 py-5 bg-zinc-900/50 border-b border-zinc-800">
              <.form
                for={@form}
                id={"domain-form-#{domain.id}"}
                phx-submit="save_domain"
                phx-value-id={domain.id}
              >
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Name
                  </label>
                  <input
                    type="text"
                    name="name"
                    value={@form[:name].value}
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  />
                </div>
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Parent domain
                  </label>
                  <select
                    name="parent_domain"
                    required
                  >
                    <option
                      :for={domain <- @domains}
                      value={domain.id}
                      selected={domain.id == @form[:parent_domain_id].value}
                    >
                      {domain.name}
                    </option>
                  </select>
                </div>
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Description
                  </label>
                  <textarea
                    name="description"
                    rows="4"
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg p-4 text-sm resize-y outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  >{@form[:description].value}</textarea>
                </div>
                <div class="flex justify-end">
                  <button
                    type="submit"
                    class="px-5 py-2.5 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
                    phx-disable-with="Saving..."
                  >
                    Save Changes
                  </button>
                </div>
              </.form>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # --- Personas Section ---

  defp personas_section(assigns) do
    ~H"""
    <div class="max-w-8xl">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Domain Personas</h1>
          <p class="text-zinc-500 text-sm mt-1">Manage AI domain persona configurations</p>
        </div>
        <button
          :if={!@adding}
          phx-click="add_new"
          class="px-4 py-2 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
        >
          Add New
        </button>
      </div>

      <%!-- Add New Form --%>
      <div
        :if={@adding}
        class="mb-6 border border-zinc-800 rounded-xl overflow-hidden"
      >
        <div class="px-6 py-4 bg-zinc-900/50 border-b border-zinc-800">
          <h2 class="text-sm font-medium text-white">New Domain Persona</h2>
        </div>
        <div class="px-6 py-5 bg-zinc-900/30">
          <.form for={@form} id="new-prompt-form" phx-submit="create">
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Name
              </label>
              <input
                type="text"
                name="name"
                required
                class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                placeholder="Enter domain persona name..."
              />
            </div>
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Enabled
              </label>
              <input
                type="checkbox"
                name="status"
                value="true"
              />
            </div>
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Domain
              </label>
              <select
                name="domain_id"
                required
                class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
              >
                <option value="">Select a domain...</option>
                <option :for={domain <- @domains} value={domain.id}>{domain.name}</option>
              </select>
            </div>
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Max Turns
              </label>
              <input
                type="number"
                name="max_turns"
                min="1"
                max="20"
                value="10"
                required
                class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
              />
            </div>
            <div class="mb-4">
              <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                Prompt Text
              </label>
              <textarea
                name="prompt_text"
                rows="6"
                required
                class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg p-4 text-sm font-mono resize-y outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                placeholder="Enter prompt text..."
              ></textarea>
            </div>
            <div class="flex justify-end gap-3">
              <button
                type="button"
                phx-click="cancel_add"
                class="px-4 py-2 text-sm text-zinc-500 hover:text-zinc-300 transition-all duration-150 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-5 py-2.5 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
                phx-disable-with="Creating..."
              >
                Create Persona
              </button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- Table --%>
      <div class="border border-zinc-800 rounded-xl overflow-hidden">
        <div class="grid grid-cols-13 gap-6 px-6 py-3 bg-zinc-900/50 border-b border-zinc-800 text-xs font-medium text-zinc-500 uppercase tracking-wider">
          <div class="col-span-2">Name</div>
          <div class="col-span-1">Domain</div>
          <div class="col-span-5">Preview</div>
          <div class="col-span-1 text-center">Turns</div>
          <div class="col-span-2">Updated By</div>
          <div class="col-span-1 text-right">Enabled</div>
          <div class="col-span-1 text-right">Action</div>
        </div>

        <div :if={@personas == []} class="px-6 py-12 text-center text-zinc-500">
          No domain personas configured yet.
        </div>

        <div :for={persona <- @personas} id={"persona-#{persona.id}"}>
          <div class={[
            "grid grid-cols-13 gap-6 px-6 py-3.5 items-center border-b border-zinc-800/50 last:border-b-0 transition-colors duration-150",
            @editing_id == persona.id && "bg-zinc-900/30"
          ]}>
            <div class="col-span-2 min-w-0">
              <span class="font-medium text-white text-sm truncate block">{persona.name}</span>
            </div>
            <div class="col-span-1">
              <span
                :if={persona.domain}
                class={[
                  "inline-block px-2 py-0.5 text-xs font-medium rounded-md whitespace-nowrap",
                  domain_pill_classes(persona.domain.name)
                ]}
              >
                {persona.domain.name}
              </span>
              <span :if={!persona.domain} class="text-sm text-zinc-600">—</span>
            </div>
            <div class="col-span-5 min-w-0">
              <p class="text-sm text-zinc-400 truncate">{persona.prompt_text}</p>
            </div>
            <div class="col-span-1 text-center">
              <span class="text-sm text-zinc-400 tabular-nums">{persona.max_turns}</span>
            </div>
            <div class="col-span-2 min-w-0">
              <span :if={persona.updated_by_admin} class="text-sm text-zinc-500 truncate block">
                {persona.updated_by_admin.email}
              </span>
              <span :if={!persona.updated_by_admin} class="text-sm text-zinc-600">—</span>
            </div>
            <div class="col-span-1 text-right">
              <span :if={persona.status == :enabled}>
                <.icon name="hero-check-circle" class="text-green-500" />
              </span>
              <span :if={persona.status == :disabled}>
                <.icon name="hero-x-circle" class="text-red-500" />
              </span>
            </div>
            <div class="col-span-1 text-right">
              <button
                :if={@editing_id != persona.id}
                phx-click="edit"
                phx-value-id={persona.id}
                class="text-emerald-500 hover:text-emerald-400 text-sm font-medium transition-all duration-150 cursor-pointer"
              >
                Edit
              </button>
              <button
                :if={@editing_id == persona.id}
                phx-click="cancel"
                class="text-zinc-500 hover:text-zinc-300 text-sm transition-all duration-150 cursor-pointer"
              >
                Cancel
              </button>
            </div>
          </div>

          <%!-- Expanded Edit Panel --%>
          <%= if @editing_id == persona.id do %>
            <div class="px-6 py-5 bg-zinc-900/50 border-b border-zinc-800">
              <.form
                for={@form}
                id={"prompt-form-#{persona.id}"}
                phx-submit="save"
                phx-value-id={persona.id}
              >
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Name
                  </label>
                  <input
                    type="text"
                    name="name"
                    value={@form[:name].value}
                    required
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  />
                </div>
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Enabled
                  </label>
                  <input
                    type="checkbox"
                    name="status"
                    value={@form[:status].value}
                    checked={@form[:status].value}
                  />
                </div>
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-3">
                    Domain
                  </label>
                  <select
                    name="domain_id"
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  >
                    <option
                      :for={domain <- @domains}
                      value={domain.id}
                      selected={domain.id == persona.domain_id}
                    >
                      {domain.name}
                    </option>
                  </select>
                </div>
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Max Turns
                  </label>
                  <input
                    type="number"
                    name="max_turns"
                    min="1"
                    max="20"
                    value={@form[:max_turns].value}
                    required
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  />
                </div>
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Prompt Text
                  </label>
                  <textarea
                    name="prompt_text"
                    rows="8"
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg p-4 text-sm font-mono resize-y outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  >{@form[:prompt_text].value}</textarea>
                </div>

                <div class="flex justify-end mt-4">
                  <button
                    type="submit"
                    class="px-5 py-2.5 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
                    phx-disable-with="Saving..."
                  >
                    Save Changes
                  </button>
                </div>
              </.form>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # --- Admin Users Section ---

  defp admin_users_section(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Admin Users</h1>
          <p class="text-zinc-500 text-sm mt-1">Manage platform administrators</p>
        </div>
      </div>

      <%!-- Admin Users Table --%>
      <div class="border border-zinc-800 rounded-xl overflow-hidden">
        <div class="grid grid-cols-12 gap-6 px-6 py-3 bg-zinc-900/50 border-b border-zinc-800 text-xs font-medium text-zinc-500 uppercase tracking-wider">
          <div class="col-span-5">Email</div>
          <div class="col-span-3">Created</div>
          <div class="col-span-3">Password Status</div>
          <div class="col-span-1 text-right">Action</div>
        </div>

        <div :if={@admin_users == []} class="px-6 py-12 text-center text-zinc-500">
          No admin users configured yet.
        </div>

        <div :for={user <- @admin_users} id={"admin-#{user.id}"}>
          <div class={[
            "grid grid-cols-12 gap-6 px-6 py-3.5 items-center border-b border-zinc-800/50 last:border-b-0 transition-colors duration-150",
            @editing_id == user.id && "bg-zinc-900/30"
          ]}>
            <div class="col-span-5 min-w-0">
              <span class="font-medium text-white text-sm truncate block">{user.email}</span>
            </div>
            <div class="col-span-3">
              <span class="text-sm text-zinc-400">{format_date(user.inserted_at)}</span>
            </div>
            <div class="col-span-3">
              <%= if user.password_changed_at do %>
                <span class="inline-block px-2 py-0.5 text-xs font-medium rounded-md bg-emerald-500/20 text-emerald-400">
                  Active
                </span>
              <% else %>
                <span class="inline-block px-2 py-0.5 text-xs font-medium rounded-md bg-amber-500/20 text-amber-400">
                  Pending
                </span>
              <% end %>
            </div>
            <div class="col-span-1 text-right">
              <button
                :if={@editing_id != user.id}
                phx-click="edit_admin"
                phx-value-id={user.id}
                class="text-emerald-500 hover:text-emerald-400 text-sm font-medium transition-all duration-150 cursor-pointer"
              >
                Edit
              </button>
              <button
                :if={@editing_id == user.id}
                phx-click="cancel_admin"
                class="text-zinc-500 hover:text-zinc-300 text-sm transition-all duration-150 cursor-pointer"
              >
                Cancel
              </button>
            </div>
          </div>

          <%!-- Edit Panel --%>
          <%= if @editing_id == user.id do %>
            <div class="px-6 py-5 bg-zinc-900/50 border-b border-zinc-800">
              <.form
                for={@form}
                id={"admin-form-#{user.id}"}
                phx-submit="save_admin"
                phx-value-id={user.id}
              >
                <div class="mb-4">
                  <label class="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                    Email
                  </label>
                  <input
                    type="email"
                    name="email"
                    value={@form[:email].value}
                    class="w-full bg-zinc-900 border border-zinc-700 text-white rounded-lg px-4 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500/30 transition-all duration-150"
                  />
                </div>
                <div class="flex justify-end">
                  <button
                    type="submit"
                    class="px-5 py-2.5 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 text-zinc-900 rounded-lg transition-all duration-150 hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
                    phx-disable-with="Saving..."
                  >
                    Save Changes
                  </button>
                </div>
              </.form>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # --- Helpers ---
  defp format_date(nil), do: "—"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  @pill_colors [
    "bg-emerald-500/20 text-emerald-400",
    "bg-violet-500/20 text-violet-400",
    "bg-amber-500/20 text-amber-400",
    "bg-sky-500/20 text-sky-400",
    "bg-rose-500/20 text-rose-400",
    "bg-fuchsia-500/20 text-fuchsia-400",
    "bg-teal-500/20 text-teal-400",
    "bg-orange-500/20 text-orange-400"
  ]

  defp domain_pill_classes(domain_name) when is_binary(domain_name) do
    index = :erlang.phash2(domain_name, length(@pill_colors))
    Enum.at(@pill_colors, index)
  end

  defp domain_pill_classes(_), do: "bg-zinc-500/20 text-zinc-400"

  # --- Mount ---

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_section, :personas)
     |> assign(:personas, Admin.list_domain_personas())
     |> assign(:domains, Admin.list_domains())
     |> assign(:admin_users, Admin.list_admin_users())
     |> assign(:editing_id, nil)
     |> assign(:adding, false)
     |> assign(:form, nil)}
  end

  # --- Event Handlers ---

  # Navigation
  @impl true
  def handle_event("switch_section", %{"section" => section}, socket)
      when section in ["domains", "personas", "admins"] do
    {:noreply,
     socket
     |> assign(:active_section, String.to_existing_atom(section))
     |> assign(:editing_id, nil)
     |> assign(:adding, false)
     |> assign(:form, nil)}
  end

  # Domains - Add New
  @impl true
  def handle_event("add_new_domain", _params, socket) do
    form = to_form(Admin.change_domain(%Domain{}))

    {:noreply,
     socket
     |> assign(:adding, true)
     |> assign(:form, form)
     |> assign(:editing_id, nil)}
  end

  # Domains - Create
  @impl true
  def handle_event(
        "create_domain",
        %{"name" => name, "description" => description, "parent_domain" => parent_domain},
        socket
      ) do
    parent_domain = Admin.get_domain!(parent_domain)

    case Admin.create_domain(parent_domain, %{
           name: name,
           description: description
         }) do
      {:ok, _domain} ->
        {:noreply,
         socket
         |> assign(:domains, Admin.list_domains())
         |> assign(:adding, false)
         |> assign(:form, nil)
         |> put_flash(:info, "Domain created")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Domains - Edit
  @impl true
  def handle_event("edit_domain", %{"id" => id}, socket) do
    domain = Admin.get_domain!(id)
    form = to_form(Admin.change_domain(domain))

    {:noreply,
     socket
     |> assign(:editing_id, domain.id)
     |> assign(:adding, false)
     |> assign(:form, form)}
  end

  # Domains - Save
  @impl true
  def handle_event(
        "save_domain",
        %{
          "id" => id,
          "name" => name,
          "description" => description,
          "parent_domain" => parent_domain
        },
        socket
      ) do
    domain = Admin.get_domain!(id)
    parent_domain = Admin.get_domain!(parent_domain)

    case Admin.update_domain(domain, %{
           name: name,
           description: description,
           parent_domain_id: parent_domain.id
         }) do
      {:ok, _domain} ->
        {:noreply,
         socket
         |> assign(:domains, Admin.list_domains())
         |> assign(:editing_id, nil)
         |> assign(:form, nil)
         |> put_flash(:info, "Domain updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Domains - Cancel
  @impl true
  def handle_event("cancel_domain", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_id, nil)
     |> assign(:adding, false)
     |> assign(:form, nil)}
  end

  # Personas - Add New
  @impl true
  def handle_event("add_new", _params, socket) do
    form = to_form(%{"name" => "", "domain_id" => "", "prompt_text" => "", "max_turns" => "10"})

    {:noreply,
     socket
     |> assign(:adding, true)
     |> assign(:form, form)
     |> assign(:editing_id, nil)}
  end

  # Personas - Cancel Add
  @impl true
  def handle_event("cancel_add", _params, socket) do
    {:noreply,
     socket
     |> assign(:adding, false)
     |> assign(:form, nil)}
  end

  # Personas - Create
  @impl true
  def handle_event("create", %{"domain_id" => ""} = _params, socket) do
    {:noreply, put_flash(socket, :error, "Domain is required")}
  end

  @impl true
  def handle_event(
        "create",
        %{
          "domain_id" => domain_id,
          "name" => name,
          "prompt_text" => prompt_text,
          "max_turns" => max_turns
        } = params,
        socket
      ) do
    admin = socket.assigns.current_admin

    case find_domain(socket.assigns.domains, domain_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid domain selected")}

      domain ->
        attrs = %{
          name: name,
          domain_id: domain.id,
          prompt_text: prompt_text,
          max_turns: max_turns,
          status:
            if params["status"] == "true" do
              :enabled
            else
              :disabled
            end
        }

        case Admin.create_domain_persona(attrs, admin) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:personas, Admin.list_domain_personas())
             |> assign(:adding, false)
             |> assign(:form, nil)
             |> put_flash(:info, "Domain persona created")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create domain persona.")}
        end
    end
  end

  # Persona - Edit
  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    persona = Admin.get_domain_persona!(id)

    form =
      to_form(%{
        "name" => persona.name,
        "prompt_text" => persona.prompt_text,
        "domain_id" => persona.domain_id,
        "max_turns" => persona.max_turns,
        "status" => persona.status == :enabled
      })

    {:noreply,
     socket
     |> assign(:editing_id, String.to_integer(id))
     |> assign(:adding, false)
     |> assign(:form, form)}
  end

  # Persona - Cancel
  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_id, nil)
     |> assign(:form, nil)}
  end

  # Persona - Save
  @impl true
  def handle_event(
        "save",
        %{
          "id" => id,
          "name" => name,
          "domain_id" => domain_id,
          "prompt_text" => prompt_text,
          "max_turns" => max_turns
        } = f,
        socket
      ) do
    admin = socket.assigns.current_admin

    case find_domain(socket.assigns.domains, domain_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid domain selected")}

      domain ->
        persona = Admin.get_domain_persona!(id)

        attrs = %{
          name: name,
          domain_id: domain.id,
          prompt_text: prompt_text,
          max_turns: max_turns,
          status:
            if f["status"] do
              :enabled
            else
              :disabled
            end
        }

        case Admin.update_domain_persona(persona, attrs, admin) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:personas, Admin.list_domain_personas())
             |> assign(:editing_id, nil)
             |> assign(:form, nil)
             |> put_flash(:info, "Domain persona updated")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update domain persona")}
        end
    end
  end

  # Admin Users - Edit
  @impl true
  def handle_event("edit_admin", %{"id" => id}, socket) do
    user = Admin.get_admin_user!(id)
    form = to_form(Admin.change_admin_email(user))

    {:noreply,
     socket
     |> assign(:editing_id, user.id)
     |> assign(:form, form)}
  end

  # Admin Users - Save
  @impl true
  def handle_event("save_admin", %{"id" => id, "email" => email}, socket) do
    user = Admin.get_admin_user!(id)

    case Admin.update_admin_email(user, %{email: email}) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:admin_users, Admin.list_admin_users())
         |> assign(:editing_id, nil)
         |> assign(:form, nil)
         |> put_flash(:info, "Admin email updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Admin Users - Cancel
  @impl true
  def handle_event("cancel_admin", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_id, nil)
     |> assign(:form, nil)}
  end

  # --- Private Helpers ---

  defp find_domain(domains, domain_id) when is_binary(domain_id) do
    case Integer.parse(domain_id) do
      {id, ""} -> Enum.find(domains, &(&1.id == id))
      _ -> nil
    end
  end

  defp find_domain(domains, domain_id) when is_integer(domain_id) do
    Enum.find(domains, &(&1.id == domain_id))
  end

  defp find_domain(_domains, _domain_id), do: nil
end
