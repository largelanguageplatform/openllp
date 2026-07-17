defmodule Platform.ProtocolTest do
  use ExUnit.Case

  alias Platform.Protocol.ToolCall
  alias Postgrex.Protocol
  alias Platform.Protocol
  alias Platform.Protocol.{Auth, Error, Presence, Message}

  describe "protocol" do
    test "invalid schema" do
      assert Protocol.from_map("notamap") == Error.invalid_schema()
      assert Protocol.from_map(%{foo: "bar"}) == Error.invalid_schema()
    end

    test "unrecognized type" do
      actual = Protocol.from_map(%{"id" => "foo", "type" => "invalid"})
      assert actual == Error.unrecognized_type("foo", "invalid")
    end
  end

  describe "auth" do
    test "invalid schema" do
      base = %{"type" => "authenticate", "id" => "foo"}
      auth1 = base |> Map.put("name", "bar")
      auth2 = base |> Map.put("key", "baz")

      assert Protocol.from_map(base) == Error.invalid_schema()
      assert Protocol.from_map(auth1) == Error.invalid_schema()
      assert Protocol.from_map(auth2) == Error.invalid_schema()
    end

    test "valid schema" do
      expected = %Auth{id: "foo", name: "bar", key: "baz"}

      actual =
        %{
          "type" => "authenticate",
          "id" => "foo",
          "name" => "bar",
          "key" => "baz"
        }
        |> Protocol.from_map()

      assert expected == actual
    end

    test "can serialize" do
      expected = ~s({"data":{"session_id":"bar"},"id":"foo","type":"authenticated"})
      assert Auth.serialize("foo", "bar") == expected
    end
  end

  describe "presence" do
    test "valid schema" do
      expected = %Presence{id: "foo", status: :available}
      expected2 = %Presence{id: "foo", status: :unavailable, supports_encryption?: true}
      presence = %{"type" => "presence", "id" => "foo", "data" => %{"status" => "available"}}

      presence2 = %{
        "type" => "presence",
        "id" => "foo",
        "data" => %{"status" => "unavailable", "supports_encryption" => true}
      }

      assert Protocol.from_map(presence) == expected
      assert Protocol.from_map(presence2) == expected2
    end

    test "invalid schema" do
      base = %{"type" => "presence", "id" => "foo", "data" => %{}}
      p1 = base |> Map.put("data", %{"status" => "invalid"})
      p2 = base |> Map.put("data", %{"supports_encryption" => "foo", "status" => "available"})
      assert Protocol.from_map(base) == Error.invalid_presence_schema("foo")
      assert Protocol.from_map(p1) == Error.invalid_presence_schema("foo")
      assert Protocol.from_map(p2) == Error.invalid_presence_schema("foo")
    end
  end

  describe "message" do
    test "valid schema" do
      expected = %Message{id: "foo", from: nil, encrypted?: true, to: "bar", prompt: "baz"}
      expected2 = %Message{id: "foo", from: "alice", encrypted?: false, to: "bar", prompt: "baz"}

      m1 =
        %{
          "type" => "message",
          "id" => "foo",
          "data" => %{
            "to" => "bar",
            "encrypted" => true,
            "prompt" => "baz"
          }
        }

      m2 =
        %{
          "type" => "message",
          "id" => "foo",
          "from" => "alice",
          "data" => %{
            "to" => "bar",
            "encrypted" => false,
            "prompt" => "baz"
          }
        }

      assert Protocol.from_map(m1) == expected
      assert Protocol.from_map(m2) == expected2
    end

    test "invalid schema" do
      base = %{"type" => "message", "id" => "foo", "data" => %{}}
      m1 = base |> Map.put("data", %{"encrypted" => "derp", "to" => "bob"})
      m2 = base |> Map.put("data", %{"encrypted" => "false", "to" => nil})
      m3 = base |> Map.put("data", %{"encrypted" => "false"})
      m4 = base |> Map.put("data", %{"encrypted" => "true", "to" => "bob", "prompt" => nil})
      assert Protocol.from_map(base) == Error.missing_recipient("foo")
      assert Protocol.from_map(m1) == Error.invalid_message_schema("foo")
      assert Protocol.from_map(m2) == Error.invalid_message_schema("foo")
      assert Protocol.from_map(m3) == Error.missing_recipient("foo")
      assert Protocol.from_map(m4) == Error.invalid_message_schema("foo")
    end
  end

  describe "ack" do
    test "user session can't send an ack" do
      assert Protocol.from_map(%{type: "ack", id: "foo"}) == Error.invalid_schema()
    end

    test "platform can send ack for auth, presence, and message types" do
      msg = %Message{id: "foo", from: "alice", to: "bob", prompt: "hi"}
      pres = %Presence{id: "bar", status: :available}
      auth = %Auth{id: "baz", name: "alice", key: "secretkey"}
      assert Protocol.ack(msg) == %{type: "ack", id: "foo"}
      assert Protocol.ack(pres) == %{type: "ack", id: "bar"}
      assert Protocol.ack(auth) == %{type: "ack", id: "baz"}
    end
  end

  describe "tool_call" do
    test "valid schema" do
      tool = %ToolCall{
        id: "toolcall1",
        to: "bob",
        name: "get_weather",
        parameters: "{\"city\":\"Seattle\"}",
        result: "rainy"
      }

      t1 = %{
        "id" => "toolcall1",
        "type" => "tool_call",
        "data" => %{
          "to" => "bob",
          "name" => "get_weather",
          "parameters" => "{\"city\":\"Seattle\"}",
          "result" => "rainy",
          "threw_exception" => false
        }
      }

      assert Protocol.from_map(t1) == tool
    end

    test "invalid schema" do
      t1 = %{
        "id" => "toolcall1",
        "type" => "tool_call",
        "data" => %{
          "to" => "bob",
          "name" => 1,
          "parameters" => "{\"city\":\"Seattle\"}",
          "result" => "rainy",
          "threw_exception" => false
        }
      }

      assert Protocol.from_map(t1) == :error
    end
  end
end
