defmodule PlatformWeb.BundleController do
  use PlatformWeb, :controller

  alias Platform.Agent
  alias Platform.Agent.Bundle

  action_fallback PlatformWeb.FallbackController

  def create(conn, bundle_params) do
    with {:ok, %Bundle{} = bundle} <- Agent.create_bundle(bundle_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/bundle/#{bundle.agent}")
      |> render(:show, bundle: bundle)
    end
  end

  def show(conn, %{"id" => id}) do
    case Agent.get_bundle!(id) do
      nil -> {:error, :not_found}
      bundle -> render(conn, :show, bundle: bundle)
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Agent.delete_bundle(id)
    send_resp(conn, :no_content, "")
  end
end
