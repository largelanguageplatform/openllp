defmodule Platform.Chaos.W2 do
  @moduledoc """
  Generates realistic W-2 data via LLM structured output.

  ## Customer Context

  When generating documents for a single simulated identity (e.g. testing an agent's
  ability to cross-reference a person's W2, 1099, bank statement, and receipts), all
  documents must share the same name, SSN, address, and employer. Without this, the
  LLM invents a different person every time, making cross-document validation impossible.

  Pass a `:customer` map in opts to pin the employee and employer identity:

      customer = %{
        name: "Elena Martinez",
        address: "456 Oak Avenue, Apt 2B, Palo Alto, CA 94301",
        ssn: "487-65-9321",
        employer_name: "Vertex Analytics Inc",
        employer_address: "123 Technology Parkway, Suite 400, San Jose, CA 95134",
        employer_ein: "84-2938471"
      }

      Platform.Chaos.W2.generate(customer: customer)

  When `:customer` is omitted, the LLM generates fully random fictional data (original behavior).
  """

  @schema_path Path.join(:code.priv_dir(:platform), "schemas/us-w2-schema.json")
  @external_resource @schema_path
  @w2_schema @schema_path |> File.read!() |> Jason.decode!()
  @w2_schema_encoded Jason.encode!(@w2_schema)

  def schema, do: @w2_schema

  @doc """
  Generates a W-2 document as a decoded JSON map.

  ## Options

    * `:customer` - (map) Optional customer identity to pin on the generated document.
      When provided, the employee name, SSN, address, and employer details are locked
      to these values. All other fields (wages, withholdings, box 12 codes, state/local
      taxes) remain randomly generated. See module doc for the full map shape.

    * Any other key-value pairs are forwarded to `Platform.LLM.init/2` as LLM
      configuration (e.g. `:model`, `:receive_timeout`).
  """
  def generate(opts \\ []) do
    # Separate the customer context from LLM configuration options.
    # The customer map controls *what identity* appears on the document;
    # the remaining opts control *how the LLM runs* (model, timeout, etc.).
    {customer, llm_opts} = Keyword.pop(opts, :customer)

    llm =
      Platform.LLM.init(:w2, llm_opts)
      |> Platform.LLM.system(system_prompt())
      |> Platform.LLM.chat(user_prompt(customer), format: %{type: "object"})

    llm
    |> Platform.LLM.latest()
    |> Map.get(:content)
    |> strip_markdown()
    |> Jason.decode!()
  end

  def generate_pdf(w2_data) do
    case Req.post(fetch_w2_url(), json: w2_data) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        {:ok, %{location: body["location"], filename: body["filename"]}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_w2_url do
    Application.fetch_env!(:platform, Platform.PDFAgent)
    |> Keyword.fetch!(:w2_url)
  end

  defp strip_markdown(content) do
    content
    |> String.trim()
    |> String.replace(~r/^```(?:json)?\n?/, "")
    |> String.replace(~r/\n?```$/, "")
    |> String.trim()
  end

  defp system_prompt do
    """
    You are a payroll data generator. Generate realistic but fictional W-2
    wage and tax statement data. Use plausible US employer names, addresses,
    and tax amounts. All SSNs and EINs must be fictional.
    """
  end

  # When no customer context is provided, generate a fully random W-2.
  # This is the original default behavior — the LLM picks a random employee,
  # employer, and all financial details.
  defp user_prompt(nil) do
    """
    Generate a complete W-2 wage and tax statement for a random US employee for tax year 2025.
    Respond using the following JSON schema:
    #{@w2_schema_encoded}
    """
  end

  # When a customer map is provided, we inject their identity as hard constraints
  # into the prompt. This ensures the W-2 is issued to a specific person at a
  # specific employer — critical when generating a coherent document set where
  # a bank statement, 1099, and receipts all need to reference the same individual.
  #
  # Only the identity fields are pinned. Financial details (wages, withholdings,
  # box 12 codes, state/local taxes) are still randomly generated so each W-2
  # looks unique while remaining attributable to the same person.
  defp user_prompt(customer) when is_map(customer) do
    """
    Generate a complete W-2 wage and tax statement for tax year 2025.

    #{customer_block(customer)}

    All other fields (wages, withholdings, box 12 codes, state/local taxes)
    should be randomly generated with realistic values.

    Respond using the following JSON schema:
    #{@w2_schema_encoded}
    """
  end

  # Builds the identity constraint block for the LLM prompt.
  #
  # The W-2 uses the most customer fields of any document type because it contains
  # both employee AND employer information. Each field is only included if present
  # in the customer map — missing keys are silently skipped, and the LLM will
  # generate random values for those fields instead.
  #
  # This selective approach means you can pass a partial customer map (e.g. just
  # a name and SSN) and the LLM fills in the rest, or pass a complete map to
  # lock down every identity field.
  defp customer_block(customer) do
    lines =
      [
        if(customer[:name], do: "- Employee full name: #{customer[:name]}"),
        if(customer[:ssn], do: "- Employee SSN: #{customer[:ssn]}"),
        if(customer[:address], do: "- Employee address: #{customer[:address]}"),
        if(customer[:employer_name], do: "- Employer name: #{customer[:employer_name]}"),
        if(customer[:employer_address], do: "- Employer address: #{customer[:employer_address]}"),
        if(customer[:employer_ein], do: "- Employer EIN: #{customer[:employer_ein]}")
      ]
      |> Enum.reject(&is_nil/1)

    if lines == [] do
      ""
    else
      """
      IMPORTANT — You MUST use these exact details (do not change spelling, casing, or formatting):
      #{Enum.join(lines, "\n")}
      """
    end
  end
end
