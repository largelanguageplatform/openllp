defmodule PlatformWeb.HomeLive.SettingsTest do
  use PlatformWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Platform.Agent

  setup :assign_bootstrap_org

  describe "settings page" do
    test "renders the profile tab with the organization name form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/settings")

      assert html =~ "Organization Name"
      assert html =~ "name_form"
    end

    test "updates the organization name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("#name_form", organization: %{name: "Renamed Local Org"})
        |> render_submit()

      assert html =~ "Organization name updated"
      assert Platform.Bootstrap.organization!().name == "Renamed Local Org"
    end

    test "shows validation errors for an invalid name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("#name_form", organization: %{name: String.duplicate("x", 201)})
        |> render_submit()

      assert html =~ "Failed to update name"
    end
  end

  describe "api keys tab" do
    test "generates a key and reveals it once", %{conn: conn, scope: scope} do
      {:ok, lv, html} = live(conn, ~p"/settings/api-keys")
      assert html =~ "No API key generated yet"

      html = lv |> element("button", "Generate API Key") |> render_click()
      assert html =~ "New API key generated!"
      assert Agent.has_api_key?(scope)

      html = lv |> element("button", "Done") |> render_click()
      assert html =~ "Current key:"
    end

    test "regenerates the key, invalidating the old one", %{conn: conn, scope: scope} do
      {:ok, _old} = Agent.generate_api_key(scope)
      [%{hashed_key: old_hash}] = Agent.list_api_keys(scope)

      {:ok, lv, html} = live(conn, ~p"/settings/api-keys")
      assert html =~ "Current key:"

      html = lv |> element("button", "Regenerate Key") |> render_click()
      assert html =~ "New API key generated!"

      [%{hashed_key: new_hash}] = Agent.list_api_keys(scope)
      refute new_hash == old_hash
    end
  end
end
