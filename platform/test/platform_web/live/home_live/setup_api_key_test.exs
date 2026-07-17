defmodule PlatformWeb.HomeLive.SetupApiKeyTest do
  use PlatformWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Platform.Agent

  setup :assign_bootstrap_org

  describe "first-run flow" do
    test "root URL shows API key setup when no key exists", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "API Key"
    end

    test "root URL redirects to the portal once a key exists", %{conn: conn, scope: scope} do
      {:ok, _} = Agent.generate_api_key(scope)

      assert {:error, {:live_redirect, %{to: "/portal"}}} = live(conn, ~p"/")
    end

    test "generating a key reveals it and offers the dashboard", %{conn: conn, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/setup/api-key")

      html = lv |> form("#generate-key-form") |> render_submit()

      assert Agent.has_api_key?(scope)
      assert html =~ "Continue to Dashboard"
    end

    test "the portal never redirects to a login page", %{conn: conn, scope: scope} do
      # keyless: portal bounces to key setup — not to any auth page
      conn_without_key = get(conn, ~p"/portal")
      assert redirected_to(conn_without_key) == ~p"/setup/api-key"

      # keyed: portal renders with no session of any kind
      {:ok, _} = Agent.generate_api_key(scope)
      conn_with_key = get(build_conn(), ~p"/portal")
      assert html_response(conn_with_key, 200)
    end
  end
end
