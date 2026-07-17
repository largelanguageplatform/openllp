defmodule PlatformWeb.AttachmentControllerTest do
  use PlatformWeb.ConnCase
  import Platform.AccountFixtures
  alias Platform.Chaos

  describe "fetch" do
    setup do
      org = organization_scope_fixture()
      {:ok, api_key} = set_api_key(org.organization)
      %{organization: org, api_key: api_key.key}
    end

    test "can get attachment", %{conn: conn, organization: scope} do
      {:ok, details} = Chaos.s3_signed_url("foo.txt")
      {:ok, _} = Chaos.create_attachment(scope, details)

      r = Req.new(url: details.signed_url, headers: %{content_type: "plain/text"})
      {:ok, _} = Req.put(r, body: "bar")

      conn =
        conn
        |> get(~p"/api/v1/attachment/foo.txt")

      assert text_response(conn, 200) == "bar"
      assert response_content_type(conn, :text) == "plain/text"
    end

    test "returns 404", %{conn: conn} do
      conn
      |> get(~p"/api/v1/attachment/nope.jpg")
      |> response(404)
    end

    test "attachment with nothing uploaded", %{conn: conn, organization: scope} do
      filename = "random#{System.unique_integer([:positive])}.txt"
      {:ok, details} = Chaos.s3_signed_url(filename)
      {:ok, _} = Chaos.create_attachment(scope, details)

      conn
      |> get(~p"/api/v1/attachment/#{filename}")
      |> response(404)
    end
  end

  describe "upload" do
    setup do
      org_fixture = organization_fixture(%{is_internal: true})
      org = organization_scope_fixture(org_fixture)
      {:ok, api_key} = set_api_key(org.organization)
      %{organization: org, api_key: api_key.key}
    end

    test "attachment successfully", %{conn: conn, organization: scope, api_key: api_key} do
      json =
        conn
        |> put_req_header("authorization", "Bearer " <> api_key)
        |> post(~p"/api/v1/attachment", %{"filename" => "bar.txt"})
        |> json_response(200)

      assert Map.has_key?(json, "signed_url")

      attachment = Chaos.get_attachment("bar.txt")
      assert attachment != nil
      assert attachment.organization.id == scope.organization.id
      assert attachment.filename == "bar.txt"
    end

    test "unauthorized, requires authorization header", %{conn: conn} do
      conn
      |> post(~p"/api/v1/attachment", %{"filename" => "bar.txt"})
      |> response(401)
    end

    test "unauthorized, invalid key", %{conn: conn} do
      conn
      |> put_req_header("authorization", "Bearer fake")
      |> post(~p"/api/v1/attachment", %{"filename" => "bar.txt"})
      |> response(401)
    end

    test "unauthorized, bad authorization value", %{conn: conn} do
      conn
      |> put_req_header("authorization", "nonsense")
      |> post(~p"/api/v1/attachment", %{"filename" => "bar.txt"})
      |> response(401)
    end

    test "any organization's valid key can upload (single-tenant: no internal-org gate)", %{
      conn: conn
    } do
      org = organization_scope_fixture()
      {:ok, api_key} = set_api_key(org.organization)

      conn
      |> put_req_header("authorization", "Bearer " <> api_key.key)
      |> post(~p"/api/v1/attachment", %{
        "filename" => "gate-#{System.unique_integer([:positive])}.txt"
      })
      |> json_response(200)
    end

    test "already exists", %{conn: conn, api_key: api_key} do
      conn
      |> put_req_header("authorization", "Bearer " <> api_key)
      |> post(~p"/api/v1/attachment", %{"filename" => "exists.txt"})
      |> json_response(200)

      conn
      |> put_req_header("authorization", "Bearer " <> api_key)
      |> post(~p"/api/v1/attachment", %{"filename" => "exists.txt"})
      |> response(400)
    end

    test "invalid filename", %{conn: conn, api_key: api_key} do
      conn
      |> put_req_header("authorization", "Bearer " <> api_key)
      |> post(~p"/api/v1/attachment", %{"filename" => "😕.txt"})
      |> response(400)
    end
  end
end
