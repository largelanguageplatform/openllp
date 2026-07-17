defmodule Platform.JSONSchemaTest do
  use ExUnit.Case, async: true

  describe "json schema" do
    defmodule TestSchema do
      import Platform.JSONSchema

      json_schema "test1" do
        title("foo")
      end

      json_schema "test2" do
        description("bar")
      end

      json_schema "test3" do
        property(:foo, :string)
      end

      json_schema "test4" do
        property(:foo, enum: [1, 2, "foo"], description: "enum")
      end

      json_schema "test5" do
        property(:foo, :string, description: "does foo stuff")
      end

      json_schema "test6" do
        property(:foo, :string, required: true)
      end
    end

    test "generate schema function" do
      assert TestSchema.test1_schema().title == "foo"
    end

    test "description" do
      assert TestSchema.test2_schema().description == "bar"
    end

    test "string property" do
      assert TestSchema.test3_schema().properties.foo == %{type: :string}
    end

    test "enum property" do
      assert TestSchema.test4_schema().properties.foo == %{
               enum: [1, 2, "foo"],
               description: "enum"
             }
    end

    test "property with description" do
      assert TestSchema.test5_schema().properties.foo == %{
               type: :string,
               description: "does foo stuff"
             }
    end

    test "property with required" do
      assert TestSchema.test6_schema().required == [:foo]
    end
  end
end
