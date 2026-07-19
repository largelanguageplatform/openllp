defmodule PlatformWeb.AdminSessionController do
  use PlatformWeb, :controller

  alias Platform.Admin
  alias PlatformWeb.AdminAuth

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    case Admin.get_admin_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_flash(:error, "Invalid credentials")
        |> redirect(to: ~p"/admin/login")

      admin ->
        AdminAuth.log_in_admin(conn, admin)
    end
  end

  def delete(conn, _params) do
    AdminAuth.log_out_admin(conn)
  end
end
