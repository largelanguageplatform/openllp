defmodule PlatformWeb.AdminLive.Login do
  use PlatformWeb, :live_view

  alias Platform.Admin
  alias Platform.Turnstile

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-950 flex items-center justify-center px-4">
      <div class="w-full max-w-sm">
        <div class="text-center mb-8">
          <h1 class="text-xl font-semibold text-white">OpenLLP System Access</h1>
        </div>

        <.form
          for={@form}
          id="admin-login-form"
          action={~p"/sys-ctrl-9f8e7d6c/login"}
          method="post"
          phx-submit="validate_and_submit"
          phx-trigger-action={@trigger_submit}
          class="space-y-5"
        >
          <div>
            <.input
              field={@form[:email]}
              type="email"
              placeholder="Email"
              required
              autocomplete="email"
              class="w-full bg-zinc-900 border border-zinc-700 text-white placeholder-zinc-500 px-4 py-3.5 rounded-xl text-base outline-none focus:border-zinc-500 transition-colors"
              phx-mounted={JS.focus()}
            />
          </div>

          <div class="relative" id="password-container" phx-hook="PasswordToggle">
            <.input
              field={@form[:password]}
              type="password"
              placeholder="Password"
              required
              autocomplete="current-password"
              class="w-full bg-zinc-900 border border-zinc-700 text-white placeholder-zinc-500 px-4 py-3.5 pr-12 rounded-xl text-base outline-none focus:border-zinc-500 transition-colors"
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

          <div
            id="turnstile-widget"
            phx-hook="Turnstile"
            phx-update="ignore"
            data-sitekey={@turnstile_site_key}
            class="flex justify-center py-2"
          >
          </div>
          <input type="hidden" name="admin[cf_turnstile_response]" id="cf-turnstile-response" />

          <.button
            type="submit"
            class="w-full bg-emerald-500 hover:bg-emerald-400 text-zinc-900 font-semibold py-3.5 rounded-xl text-base transition-all shadow-lg shadow-emerald-500/20 hover:shadow-emerald-400/30"
            phx-disable-with="Verifying..."
          >
            Access
          </.button>

          <p :if={@error} class="text-red-400 text-sm text-center">{@error}</p>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: :admin)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:error, nil)
     |> assign(:trigger_submit, false)
     |> assign(:turnstile_site_key, Turnstile.site_key())}
  end

  @impl true
  def handle_event("validate_and_submit", %{"admin" => params}, socket) do
    turnstile_token = params["cf_turnstile_response"] || ""

    if turnstile_token == "" do
      {:noreply, assign(socket, :error, "Please complete the captcha")}
    else
      case Turnstile.verify(turnstile_token) do
        :ok ->
          case Admin.get_admin_by_email_and_password(params["email"], params["password"]) do
            nil ->
              {:noreply, assign(socket, :error, "Invalid credentials")}

            _admin ->
              {:noreply, assign(socket, :trigger_submit, true)}
          end

        {:error, _} ->
          {:noreply, assign(socket, :error, "Captcha verification failed")}
      end
    end
  end
end
