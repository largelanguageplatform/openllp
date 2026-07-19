defmodule PlatformWeb.AdminAuth do
  @moduledoc """
  Authentication plug and LiveView hooks for admin users.
  """

  use PlatformWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Platform.Admin

  @session_cookie "_platform_admin_session"
  @max_age 60 * 60 * 24 * 14
  @session_options [sign: true, max_age: @max_age, same_site: "Lax"]

  # --- Plug Functions ---

  def log_in_admin(conn, admin) do
    token = Admin.generate_admin_session_token(admin)

    conn
    |> renew_session()
    |> put_session(:admin_token, token)
    |> put_resp_cookie(@session_cookie, token, @session_options)
    |> redirect(to: ~p"/admin/prompts")
  end

  def log_out_admin(conn) do
    if token = get_session(conn, :admin_token) do
      Admin.delete_admin_session_token(token)
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@session_cookie)
    |> redirect(to: ~p"/admin/login")
  end

  def fetch_current_admin(conn, _opts) do
    {token, conn} = ensure_admin_token(conn)

    admin =
      if token do
        case Admin.get_admin_by_session_token(token) do
          {admin, _inserted_at} -> admin
          nil -> nil
        end
      end

    assign(conn, :current_admin, admin)
  end

  def require_authenticated_admin(conn, _opts) do
    if conn.assigns[:current_admin] do
      conn
    else
      conn
      |> redirect(to: ~p"/admin/login")
      |> halt()
    end
  end

  def require_password_changed(conn, _opts) do
    admin = conn.assigns[:current_admin]

    if admin && Admin.must_change_password?(admin) do
      conn
      |> redirect(to: ~p"/admin/change-password")
      |> halt()
    else
      conn
    end
  end

  def redirect_if_admin_authenticated(conn, _opts) do
    if conn.assigns[:current_admin] do
      conn
      |> redirect(to: ~p"/admin/prompts")
      |> halt()
    else
      conn
    end
  end

  defp ensure_admin_token(conn) do
    if token = get_session(conn, :admin_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@session_cookie])

      if token = conn.cookies[@session_cookie] do
        {token, put_session(conn, :admin_token, token)}
      else
        {nil, conn}
      end
    end
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  # --- LiveView Hooks ---

  def on_mount(:mount_current_admin, _params, session, socket) do
    {:cont, mount_current_admin(socket, session)}
  end

  def on_mount(:require_authenticated_admin, _params, session, socket) do
    socket = mount_current_admin(socket, session)

    if socket.assigns.current_admin do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/admin/login")

      {:halt, socket}
    end
  end

  def on_mount(:require_password_changed, _params, session, socket) do
    socket = mount_current_admin(socket, session)
    admin = socket.assigns.current_admin

    cond do
      is_nil(admin) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/login")}

      Admin.must_change_password?(admin) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/change-password")}

      true ->
        {:cont, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_admin(socket, session)

    if socket.assigns.current_admin do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/prompts")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_admin(socket, session) do
    Phoenix.Component.assign_new(socket, :current_admin, fn ->
      if token = session["admin_token"] do
        case Admin.get_admin_by_session_token(token) do
          {admin, _} -> admin
          nil -> nil
        end
      end
    end)
  end
end
