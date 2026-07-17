defmodule PlatformWeb.BundleControllerTest do
  use PlatformWeb.ConnCase

  import Platform.AgentFixtures

  @create_attrs %{
    agent: "alice",
    registration_id: 42,
    signed_prekey_id: 42,
    signed_prekey_public: "some signed_prekey_public",
    signed_prekey_signature: "some signed_prekey_signature",
    identity_key_public: "some identity_key_public"
  }
  @invalid_attrs %{
    agent: nil,
    registration_id: nil,
    signed_prekey_id: nil,
    signed_prekey_public: nil,
    signed_prekey_signature: nil,
    identity_key_public: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create bundle" do
    test "renders bundle when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/bundle", @create_attrs)

      expected = %{
        "agent_id" => "alice",
        "identity_key_public" => "some identity_key_public",
        "registration_id" => 42,
        "signed_prekey_id" => 42,
        "signed_prekey_public" => "some signed_prekey_public",
        "signed_prekey_signature" => "some signed_prekey_signature"
      }

      assert ^expected = json_response(conn, 201)

      conn = get(conn, ~p"/api/v1/bundle/alice")

      assert ^expected = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/bundle", bundle: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete bundle" do
    setup [:create_bundle]

    test "deletes chosen bundle", %{conn: conn, bundle: bundle} do
      conn = delete(conn, ~p"/api/v1/bundle/#{bundle.agent}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/bundle/#{bundle.agent}")
      assert response(conn, 404)
    end
  end

  defp create_bundle(_) do
    bundle = bundle_fixture()

    %{bundle: bundle}
  end
end
