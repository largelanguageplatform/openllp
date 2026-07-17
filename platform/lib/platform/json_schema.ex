defmodule Platform.JSONSchema do
  defmacro json_schema(name, do: block) when is_binary(name) do
    schema_name = :erlang.binary_to_atom("#{name}_schema")

    context = build_context(block)
    validate_context(context)
    rs = render_schema(context)

    quote do
      def unquote(schema_name)() do
        unquote(Macro.escape(rs))
      end
    end
  end

  defp build_context({:__block__, _, statements}) do
    statements
    |> Enum.reduce(
      %{properties: [], title: nil, description: nil},
      fn stmt, context ->
        case stmt do
          {:title, _, [title]} ->
            Map.put(context, :title, title)

          {:description, _, [desc]} ->
            Map.put(context, :description, desc)

          {:property, _, prop} ->
            p = build_property(prop)
            %{context | properties: [p | context.properties]}

          _else ->
            context
        end
      end
    )
  end

  defp build_context(rest), do: build_context({:__block__, [], [rest]})

  defp build_property([name, [{:enum, values} | opts]]) do
    opts
    |> List.flatten()
    |> build_options()
    |> Map.merge(%{name: name, type: :enum, values: values})
  end

  defp build_property([name, type | opts]) do
    opts
    |> List.flatten()
    |> build_options()
    |> Map.merge(%{name: name, type: type})
  end

  defp build_options(opts) do
    %{
      description: Keyword.get(opts, :description),
      required: Keyword.get(opts, :required)
    }
  end

  defp validate_context(context) do
    context
    |> Enum.map(fn {k, v} ->
      validate_statement(k, v)
    end)
  end

  defp validate_statement(:title, t) when is_binary(t), do: :ok
  defp validate_statement(:title, nil), do: :ok
  defp validate_statement(:description, d) when is_binary(d), do: :ok
  defp validate_statement(:description, nil), do: :ok

  defp validate_statement(:properties, ps) do
    ps
    |> Enum.map(fn p ->
      Enum.map(p, fn {k, v} -> validate_property(k, v) end)
    end)
  end

  defp validate_statement(:title, _), do: raise("title needs to be a string")
  defp validate_statement(:description, _), do: raise("description needs to be a string")
  defp validate_statement(_k, _v), do: :ok

  defp validate_property(:type, :string), do: :ok
  defp validate_property(:type, :boolean), do: :ok
  defp validate_property(:type, :enum), do: :ok
  defp validate_property(:type, :number), do: :ok
  defp validate_property(:type, :integer), do: :ok
  defp validate_property(:type, :null), do: :ok
  defp validate_property(:description, d) when is_binary(d), do: :ok
  defp validate_property(:description, nil), do: :ok

  defp validate_property(:type, t) when not is_atom(t),
    do: raise("type needs to be atom: #{inspect(t)}")

  defp validate_property(:type, t), do: raise("unsupported type: #{inspect(t)}")
  defp validate_property(:description, _), do: raise("description needs to be a string")
  defp validate_property(:required, true), do: :ok
  defp validate_property(:required, false), do: :ok
  defp validate_property(:required, nil), do: :ok
  defp validate_property(:required, _), do: raise("attribute 'required' needs to be a boolean")
  defp validate_property(_k, _v), do: :ok

  defp render_schema(context) do
    props = render_properties(context.properties)
    required = render_required(context.properties)

    %{type: :object}
    |> maybe_add(:title, context.title)
    |> maybe_add(:description, context.description)
    |> maybe_add(:properties, props)
    |> maybe_add(:required, required)
  end

  defp render_properties(props) do
    props
    |> Enum.reduce(%{}, fn p, acc ->
      case p.type do
        :enum ->
          opts =
            %{enum: p.values}
            |> maybe_add(:description, p.description)

          Map.put(acc, p.name, opts)

        _else ->
          opts =
            %{type: p.type}
            |> maybe_add(:description, p.description)

          Map.put(acc, p.name, opts)
      end
    end)
  end

  defp render_required(props) do
    props
    |> Enum.reduce([], fn p, acc ->
      case p.required do
        true ->
          [p.name | acc]

        _else ->
          acc
      end
    end)
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, _key, []), do: map
  defp maybe_add(map, _key, value) when value == %{}, do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
