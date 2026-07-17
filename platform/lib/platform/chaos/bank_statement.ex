defmodule Platform.Chaos.BankStatement do
  @moduledoc """
  Generates realistic bank statement data via LLM structured output.

  ## Customer Context

  When generating a coherent document set for one simulated identity, the bank
  statement must show the same account holder who appears on the W2, 1099, and
  receipts. This is especially important for bank statements because an agent
  testing document ingestion needs to verify that payroll deposits on the statement
  match the W2 wages, and that the account holder name matches across all documents.

  Pass a `:customer` map in opts to pin the account holder and bank:

      customer = %{
        name: "Elena Martinez",
        address: "456 Oak Avenue, Apt 2B, Palo Alto, CA 94301",
        bank_name: "JPMorgan Chase Bank, N.A."
      }

      Platform.Chaos.BankStatement.generate(customer: customer)

  When `:customer` is omitted, the LLM generates fully random fictional data (original behavior).
  """

  @schema_path Path.join(:code.priv_dir(:platform), "schemas/bank-statement-schema.json")
  @external_resource @schema_path
  @statement_schema @schema_path |> File.read!() |> Jason.decode!()
  @statement_schema_encoded Jason.encode!(@statement_schema)

  def schema, do: @statement_schema

  @doc """
  Generates a bank statement document as a decoded JSON map.

  ## Options

    * `:customer` - (map) Optional customer identity for the account holder.
      When provided, the account holder name, address, and bank name are locked
      to these values. All transactions, balances, dates, and account numbers
      remain randomly generated. See module doc for the full map shape.

    * Any other key-value pairs are forwarded to `Platform.LLM.init/2` as LLM
      configuration (e.g. `:model`, `:receive_timeout`).
  """
  def generate(opts \\ []) do
    # Separate the customer context from LLM configuration options.
    # The customer map controls *whose account* the statement belongs to;
    # the remaining opts control *how the LLM runs* (model, timeout, etc.).
    {customer, llm_opts} = Keyword.pop(opts, :customer)

    llm =
      Platform.LLM.init(:bank_statement, llm_opts)
      |> Platform.LLM.system(system_prompt())
      |> Platform.LLM.chat(user_prompt(customer), format: %{type: "object"})

    llm
    |> Platform.LLM.latest()
    |> Map.get(:content)
    |> strip_markdown()
    |> Jason.decode!()
  end

  def generate_pdf(statement_data) do
    case Req.post(fetch_url(), json: statement_data) do
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
    |> Keyword.fetch!(:bank_statement_url)
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
    You are a banking data generator that creates realistic US bank statement data
    closely mimicking real statements from major banks like Chase, Bank of America,
    Wells Fargo, or Citibank.

    Transaction descriptions MUST be detailed and realistic, following these exact patterns:

    Deposits and Additions:
    - "Direct Deposit ACME CORPORATION PAYROLL"
    - "Online Transfer From Chk :1858 Transact#: 7901783357"
    - "Incoming Wire Transfer REF#WR20250115001"
    - "Mobile Deposit REF#MD20250120 CHK#1247"

    ATM & Debit Card Withdrawals:
    - "Card Purchase 01/15 WALMART SUPERCENTER #3847 PHOENIX AZ Card 4496"
    - "Card Purchase 01/18 SHELL OIL 57442103847 SCOTTSDALE AZ Card 4496"
    - "Recurring Card Purchase 01/20 NETFLIX.COM LOS GATOS CA Card 4496"
    - "Card Purchase 01/22 TRADER JOES #187 TEMPE AZ Card 4496"
    - "ATM Withdrawal 01/10 NON-CHASE ATM 4501 N SCOTTSDALE RD SCOTTSDALE AZ"

    Electronic Withdrawals:
    - "Online Payment 7901788327 To CHASE MORTGAGE 1009"
    - "ACH Debit GEICO AUTO INSURANCE PREMIUM"
    - "Online Bill Pay ARIZONA PUBLIC SERVICE CO CONF#9284756"
    - "ACH Debit VERIZON WIRELESS AUTOPAY"

    Fees:
    - "Monthly Service Fee"
    - "Non-Chase ATM Fee - WITHDRAWAL"
    - "Insufficient Funds Fee For A $14.04 Recurring Card Purchase"
    - "Overdraft Protection Transfer Fee"

    Key rules:
    - All data must be fictional but realistic
    - Account number must be partially masked (e.g. xxxxx100899010)
    - Running balances must be mathematically correct throughout
    - Deposits INCREASE the balance, all other categories DECREASE it
    - Each transaction's balance = previous balance +/- amount
    - Summary ending_balance must equal beginning_balance + deposits - withdrawals - fees
    - Use card last-4 digits consistently across card purchases
    - Include realistic reference/transaction numbers
    - Transaction dates should use MM/DD format and be in chronological order
    """
  end

  # When no customer context is provided, generate a fully random bank statement.
  # The LLM picks a random account holder, bank, and generates all transactions.
  defp user_prompt(nil) do
    """
    Generate a complete monthly bank statement for a random US checking account.
    Include 15-25 transactions across these categories:

    - Deposits and Additions (2-4 transactions: payroll direct deposits, transfers in)
    - ATM & Debit Card Withdrawals (8-12 transactions: retail stores, gas stations,
      restaurants, groceries, online subscriptions — include merchant name, city, state,
      and card last 4 digits)
    - Electronic Withdrawals (3-5 transactions: mortgage/rent, utilities, insurance,
      loan payments — include payee names and confirmation numbers)
    - Fees (0-2 transactions: monthly service fee, ATM fees, overdraft fees)

    The account holder should have a realistic beginning balance between $500 and $15,000.

    Respond using the following JSON schema:
    #{@statement_schema_encoded}
    """
  end

  # When a customer map is provided, we pin the account holder identity so the
  # bank statement belongs to the same person whose W2, 1099, and receipts we
  # generated. This is the most important document for cross-referencing because
  # agents can verify that W2 payroll amounts appear as direct deposits, and that
  # the account holder's name and address are consistent across all documents.
  #
  # The bank name can also be pinned (e.g. "JPMorgan Chase Bank, N.A.") so the
  # statement header, service phone numbers, and website all match a specific bank.
  # When the bank_name is not provided, the LLM picks a random major US bank.
  defp user_prompt(customer) when is_map(customer) do
    """
    Generate a complete monthly bank statement for a US checking account.
    Include 15-25 transactions across these categories:

    - Deposits and Additions (2-4 transactions: payroll direct deposits, transfers in)
    - ATM & Debit Card Withdrawals (8-12 transactions: retail stores, gas stations,
      restaurants, groceries, online subscriptions — include merchant name, city, state,
      and card last 4 digits)
    - Electronic Withdrawals (3-5 transactions: mortgage/rent, utilities, insurance,
      loan payments — include payee names and confirmation numbers)
    - Fees (0-2 transactions: monthly service fee, ATM fees, overdraft fees)

    The account holder should have a realistic beginning balance between $500 and $15,000.

    #{customer_block(customer)}

    All other fields (transactions, balances, dates, account number) should be
    randomly generated with realistic values.

    Respond using the following JSON schema:
    #{@statement_schema_encoded}
    """
  end

  # Builds the identity constraint block for the bank statement account holder.
  #
  # The bank statement uses three customer fields:
  # - `name` and `address` for the account holder (printed at top of statement)
  # - `bank_name` for the issuing bank (controls header, phone, website styling)
  #
  # The bank_name is particularly useful because it affects the entire look and
  # feel of the statement — a "JPMorgan Chase Bank, N.A." statement will have
  # Chase-specific phone numbers and URLs, while "Bank of America" would differ.
  defp customer_block(customer) do
    lines =
      [
        if(customer[:name], do: "- Account holder name: #{customer[:name]}"),
        if(customer[:address], do: "- Account holder address: #{customer[:address]}"),
        if(customer[:bank_name], do: "- Bank name: #{customer[:bank_name]}")
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
