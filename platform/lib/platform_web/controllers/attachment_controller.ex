defmodule PlatformWeb.AttachmentController do
  use PlatformWeb, :controller

  require Logger
  alias Platform.Account.Scope
  alias Platform.Agent
  alias Platform.Agent.APIKey
  alias Platform.Chaos
  action_fallback PlatformWeb.FallbackController

  def create(conn, %{"filename" => filename}) do
    with {:ok, key} <- auth(conn),
         {:ok, scope} <- get_scope(key) do
      {:ok, attachment_details} = Chaos.s3_signed_url(filename)

      case Chaos.create_attachment(scope, attachment_details) do
        {:ok, _} ->
          conn
          |> put_status(:ok)
          |> render(:show, signed_url: attachment_details.signed_url)

        {:error, %Ecto.Changeset{valid?: false}} ->
          {:error, :bad_request}
      end
    else
      _error ->
        {:error, :unauthorized}
    end
  end

  def show(conn, %{"file" => file}) do
    contents =
      file
      |> Chaos.get_attachment()
      |> Chaos.download_attachment()

    with {:ok, resp} <- contents do
      conn
      |> put_status(:ok)
      |> maybe_put_resp_header(resp)
      |> text(resp.body)
    else
      {:error, {:http_error, 404, _body}} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  def download(conn, %{"agent_name" => agent_name, "attachment" => attachment}) do
    scope = conn.assigns.current_scope
    agent = Agent.get_agent_by_name(scope, agent_name)

    if agent != nil do
      contents =
        attachment
        |> Chaos.get_attachment()
        |> Chaos.download_attachment()

      with {:ok, resp} <- contents do
        conn
        |> put_status(:ok)
        |> maybe_put_resp_header(resp)
        |> text(resp.body)
      else
        {:error, {:http_error, 404, _body}} ->
          {:error, :not_found}

        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  defp maybe_put_resp_header(conn, resp) do
    resp.headers
    |> Keyword.take(["ETag", "Content-Type"])
    |> List.foldl(conn, fn {k, v}, conn -> put_resp_header(conn, String.downcase(k), v) end)
  end

  defp auth(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> key] -> {:ok, key}
      other -> {:error, {:invalid_auth, other}}
    end
  end

  defp get_scope(key) do
    with %APIKey{} = api_key <- Agent.get_api_key(key),
         scope <- Scope.for_organization(api_key.organization) do
      {:ok, scope}
    end
  end
end
