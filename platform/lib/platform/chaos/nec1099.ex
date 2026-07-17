defmodule Platform.Chaos.NEC1099 do
  @moduledoc """
  Generates realistic 1099-NEC data via LLM structured output.

  ## Customer Context

  When generating a suite of documents for one simulated identity, the 1099-NEC
  recipient must match the same person who appears on their W2, bank statement,
  and receipts. Without this, the LLM invents a different contractor every time,
  making it impossible to test cross-document consistency (e.g. verifying that
  the 1099 income appears as a deposit on the bank statement).

  Pass a `:customer` map in opts to pin the recipient identity:

      customer = %{
        name: "Elena Martinez",
        address: "456 Oak Avenue, Apt 2B, Palo Alto, CA 94301",
        ssn: "487-65-9321"
      }

      Platform.Chaos.NEC1099.generate(customer: customer)

  The customer becomes the **recipient** (the contractor receiving payment).
  The payer company is always randomly generated — in real life a person can
  receive 1099s from many different companies.

  When `:customer` is omitted, the LLM generates fully random fictional data (original behavior).
  """

  @schema_path Path.join(:code.priv_dir(:platform), "schemas/us-1099-nec-schema.json")
  @external_resource @schema_path
  @nec_schema @schema_path |> File.read!() |> Jason.decode!()
  @nec_schema_encoded Jason.encode!(@nec_schema)

  def schema, do: @nec_schema

  @doc """
  Generates a 1099-NEC document as a decoded JSON map.

  ## Options

    * `:customer` - (map) Optional customer identity for the recipient.
      When provided, the recipient name, SSN, and address are locked to these
      values. The payer company and all financial details remain random.
      See module doc for the full map shape.

    * Any other key-value pairs are forwarded to `Platform.LLM.init/2` as LLM
      configuration (e.g. `:model`, `:receive_timeout`).
  """
  def generate(opts \\ []) do
    # Separate the customer context from LLM configuration options.
    # The customer map controls *who receives* the 1099-NEC;
    # the remaining opts control *how the LLM runs* (model, timeout, etc.).
    {customer, llm_opts} = Keyword.pop(opts, :customer)

    llm =
      Platform.LLM.init(:nec1099, llm_opts)
      |> Platform.LLM.system(system_prompt())
      |> Platform.LLM.chat(user_prompt(customer), format: %{type: "object"})

    llm
    |> Platform.LLM.latest()
    |> Map.get(:content)
    |> strip_markdown()
    |> Jason.decode!()
  end

  def generate_pdf(nec_data) do
    case Req.post(fetch_url(), json: nec_data) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        {:ok, %{location: body["location"], filename: body["filename"]}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_url do
    Application.fetch_env!(:platform, Platform.PDFAgent)
    |> Keyword.fetch!(:nec1099_url)
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
    You are a tax document data generator that creates realistic US 1099-NEC
    (Nonemployee Compensation) form data exactly matching IRS specifications.

    All data must be fictional but completely realistic. Follow these rules precisely:

    PAYER (the company paying the contractor):
    - Use a plausible US corporation name (e.g. "Vertex Analytics Inc", "Meridian Consulting Group LLC")
    - Address must be a full block on one line: "123 Technology Parkway, Suite 400, San Jose, CA 95134"
    - TIN must be a fictional EIN in format XX-XXXXXXX (e.g. "84-2938471")
    - Include a phone number in format (XXX) XXX-XXXX

    RECIPIENT (the independent contractor):
    - Use a realistic individual name (first + last)
    - TIN must be a fictional SSN in format XXX-XX-XXXX (e.g. "487-65-9321")
    - street_address is ONLY the street line: "456 Oak Avenue, Apt 2B"
    - city_state_zip is ONLY city, state, ZIP: "Palo Alto, CA 94301"
    - These MUST be separate fields — do NOT combine them

    COMPENSATION:
    - nonemployee_compensation (Box 1): Realistic amount between $15,000 and $250,000
    - federal_tax_withheld (Box 4): Typically 0 for 1099-NEC unless backup withholding applies
      (if withholding, use 24% of compensation)
    - direct_sales: Almost always false
    - corrected: Always false for new forms
    - fatca_filing: Always false for domestic recipients

    STATE TAX INFO:
    - Include 1 state entry
    - state: Two-letter code matching the recipient's address state
    - state_id: Payer's state ID number (e.g. "800-123-4567" for CA)
    - state_income: Same as nonemployee_compensation
    - state_tax_withheld: Realistic state withholding (e.g. 3-9% of income depending on state)
    """
  end

  # When no customer context is provided, generate a fully random 1099-NEC.
  # Both the payer company and recipient contractor are invented by the LLM.
  defp user_prompt(nil) do
    """
    Generate a complete 1099-NEC form for a random independent contractor for tax year 2025.
    The contractor should be in a common freelance field (software consulting, marketing,
    design, accounting, etc.). Make sure the payer is a recognizable type of company that
    would hire contractors.

    Respond using the following JSON schema:
    #{@nec_schema_encoded}
    """
  end

  # When a customer map is provided, we pin the recipient identity so this 1099-NEC
  # is addressed to the same person whose name appears on their W2, bank statement,
  # and receipts. The payer company remains random — a person typically receives
  # 1099s from multiple different clients/companies.
  #
  # The 1099-NEC schema requires the recipient address to be split into two fields:
  # `street_address` and `city_state_zip`. The customer map provides a single `address`
  # string, so we instruct the LLM to split it appropriately. The LLM is good at
  # parsing "456 Oak Avenue, Apt 2B, Palo Alto, CA 94301" into the two fields.
  defp user_prompt(customer) when is_map(customer) do
    """
    Generate a complete 1099-NEC form for tax year 2025.
    The contractor should be in a common freelance field (software consulting, marketing,
    design, accounting, etc.). Make sure the payer is a recognizable type of company that
    would hire contractors.

    #{customer_block(customer)}

    The PAYER company and all financial details (compensation, withholdings, state tax)
    should be randomly generated with realistic values.

    Respond using the following JSON schema:
    #{@nec_schema_encoded}
    """
  end

  # Builds the identity constraint block for the 1099-NEC recipient.
  #
  # Only recipient fields are pinned here. The customer is always the recipient
  # (the person who earned the income), never the payer. This reflects real life:
  # a freelancer receives 1099s from many companies, but their own identity stays
  # consistent across all of them.
  #
  # Note the special handling of the address field: the 1099-NEC schema requires
  # separate `street_address` and `city_state_zip` fields, but the customer map
  # provides a single combined `address`. We pass the full address and instruct
  # the LLM to split it correctly into the two schema fields.
  defp customer_block(customer) do
    lines =
      [
        if(customer[:name], do: "- Recipient name: #{customer[:name]}"),
        if(customer[:ssn], do: "- Recipient TIN (SSN): #{customer[:ssn]}"),
        if(customer[:address],
          do:
            "- Recipient full address: #{customer[:address]} (split this into street_address and city_state_zip)"
        )
      ]
      |> Enum.reject(&is_nil/1)

    if lines == [] do
      ""
    else
      """
      IMPORTANT — You MUST use these exact details for the RECIPIENT (do not change spelling, casing, or formatting):
      #{Enum.join(lines, "\n")}
      """
    end
  end
end
