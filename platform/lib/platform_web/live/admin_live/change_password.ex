defmodule PlatformWeb.AdminLive.ChangePassword do
  use PlatformWeb, :live_view

  alias Platform.Admin

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-950 flex items-center justify-center px-4">
      <div class="w-full max-w-sm">
        <div class="text-center mb-8">
          <h1 class="text-xl font-semibold text-white">Change Password</h1>
          <p class="text-zinc-400 text-sm mt-2">
            You must set a new password before continuing.
          </p>
        </div>

        <.form
          for={@form}
          id="change-password-form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-5"
        >
          <div>
            <label class="block text-sm text-zinc-400 mb-2">New Password</label>
            <div class="relative" id="password-container" phx-hook="PasswordToggle">
              <.input
                field={@form[:password]}
                type="password"
                required
                autocomplete="new-password"
                class="w-full bg-zinc-900 border border-zinc-700 text-white px-4 py-3.5 pr-12 rounded-xl text-base outline-none focus:border-zinc-500 transition-colors"
                phx-mounted={JS.focus()}
              />
              <button
                type="button"
                data-toggle-password
                class="absolute right-4 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300 transition-colors"
              >
                <.icon name="hero-eye" class="w-5 h-5 eye-show" />
                <.icon name="hero-eye-slash" class="w-5 h-5 eye-hide hidden" />
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm text-zinc-400 mb-2">Confirm Password</label>
            <div class="relative" id="password-confirm-container" phx-hook="PasswordToggle">
              <.input
                field={@form[:password_confirmation]}
                type="password"
                required
                autocomplete="new-password"
                class="w-full bg-zinc-900 border border-zinc-700 text-white px-4 py-3.5 pr-12 rounded-xl text-base outline-none focus:border-zinc-500 transition-colors"
              />
              <button
                type="button"
                data-toggle-password
                class="absolute right-4 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300 transition-colors"
              >
                <.icon name="hero-eye" class="w-5 h-5 eye-show" />
                <.icon name="hero-eye-slash" class="w-5 h-5 eye-hide hidden" />
              </button>
            </div>
          </div>

          <div class="text-xs text-zinc-500 space-y-1">
            <p>Password requirements:</p>
            <ul class="list-disc list-inside">
              <li>At least 12 characters</li>
              <li>At least one lowercase letter</li>
              <li>At least one uppercase letter</li>
              <li>At least one number or special character</li>
            </ul>
          </div>

          <.button
            type="submit"
            class="w-full bg-emerald-500 hover:bg-emerald-400 text-zinc-900 font-semibold py-3.5 rounded-xl text-base transition-all shadow-lg shadow-emerald-500/20 hover:shadow-emerald-400/30"
            phx-disable-with="Saving..."
          >
            Set Password
          </.button>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    admin = socket.assigns.current_admin
    changeset = Admin.change_admin_password(admin)

    {:ok,
     socket
     |> assign(:admin, admin)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.admin
      |> Admin.change_admin_password(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    admin = socket.assigns.admin

    if params["password"] != params["password_confirmation"] do
      {:noreply,
       socket
       |> put_flash(:error, "Passwords do not match")}
    else
      case Admin.update_admin_password(admin, params) do
        {:ok, _admin} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password changed successfully")
           |> redirect(to: ~p"/admin/login")}

        {:error, changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :user))
  end
end
