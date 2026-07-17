defmodule Platform.Chaos.Receipt do
  @moduledoc """
  Generates realistic vendor-branded receipt data via LLM structured output.

  ## Customer Context

  When generating a coherent document set for one simulated identity, the receipt's
  purchaser ("to" field) must match the same person who appears on their W2, 1099,
  and bank statement. This matters because an agent testing document ingestion needs
  to verify that receipt totals could plausibly appear as card purchases on the bank
  statement, and that the purchaser name is consistent across all documents.

  Pass a `:customer` map in opts to pin the purchaser identity:

      customer = %{name: "Elena Martinez"}

      Platform.Chaos.Receipt.generate(customer: customer)

  The customer becomes the **purchaser** (the "to" party on the receipt).
  The vendor, items, and all other details are always randomly generated — in real
  life a person buys from many different stores.

  When `:customer` is omitted, the LLM generates fully random fictional data (original behavior).
  """

  @schema_path Path.join(:code.priv_dir(:platform), "schemas/receipt-schema.json")
  @external_resource @schema_path
  @receipt_schema @schema_path |> File.read!() |> Jason.decode!()
  @receipt_schema_encoded Jason.encode!(@receipt_schema)

  def schema, do: @receipt_schema

  @doc """
  Generates a vendor-branded receipt document as a decoded JSON map.

  ## Options

    * `:customer` - (map) Optional customer identity for the purchaser.
      When provided, the "to" name is locked to this value. The vendor choice,
      items, pricing, and all other fields remain random.
      See module doc for the full map shape.

    * Any other key-value pairs are forwarded to `Platform.LLM.init/2` as LLM
      configuration (e.g. `:model`, `:receive_timeout`).
  """
  def generate(opts \\ []) do
    # Separate the customer context from LLM configuration options.
    # The customer map controls *who the receipt is made out to*;
    # the remaining opts control *how the LLM runs* (model, timeout, etc.).
    {customer, llm_opts} = Keyword.pop(opts, :customer)

    llm =
      Platform.LLM.init(:receipt, llm_opts)
      |> Platform.LLM.system(system_prompt())
      |> Platform.LLM.chat(user_prompt(customer), format: %{type: "object"})

    llm
    |> Platform.LLM.latest()
    |> Map.get(:content)
    |> strip_markdown()
    |> Jason.decode!()
  end

  def generate_pdf(receipt_data) do
    case Req.post(fetch_url(), json: receipt_data) do
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
    |> Keyword.fetch!(:receipt_url)
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
    You are a receipt data generator that creates realistic business purchase receipts
    from popular US vendors. Each receipt must look like it came from a real vendor.

    You MUST pick ONE vendor_id from this list and generate items appropriate for that vendor:

    VENDOR FORMAT TYPES:
    Some vendors issue full-page A4 receipts (digital/email). Others print on narrow thermal
    register tape. The format affects item description style:
    - A4 vendors: normal descriptive item names
    - Thermal vendors: ALL CAPS abbreviated POS-style descriptions, max 28 characters each.
      Abbreviate like real point-of-sale systems:
      "DW 20V DRILL KIT" not "DeWalt 20V MAX Lithium-Ion Cordless Drill Kit"
      "KS PAPER TOWELS 12PK" not "Kirkland Signature Paper Towels 12-Pack"
      "ICED CARM MACCH GR" not "Iced Caramel Macchiato (Grande)"
      "REG UNLEADED 12.8G" not "Regular Unleaded Gasoline 12.847 Gallons"

    === A4 VENDORS (full-page digital receipts) ===

    "amazon" — Amazon.com (e-commerce / office supplies)
      From: "Amazon.com", address: "410 Terry Ave N, Seattle, WA 98109"
      Items: office supplies, tech accessories, books, cables, mouse, keyboard, printer paper,
             USB hub, monitor stand, desk organizer, headset, webcam
      Receipt number format: "114-XXXXXXX-XXXXXXX"

    "uber" — Uber (transportation / rideshare)
      From: "Uber Technologies, Inc.", address: "1515 3rd St, San Francisco, CA 94158"
      Items: ride fare (base fare), booking fee, surge pricing, toll charges, tip
      2-4 items max. Receipt number format: "UBER-XXXXXXXXXX"

    "fedex" — FedEx (shipping / packaging)
      From: "FedEx Office", address (e.g. "2200 Market St, San Francisco, CA 94114")
      Items: overnight shipping labels, ground shipping, packaging supplies, document printing,
             customs brokerage fee, fuel surcharge
      Receipt number format: "XXXX-XXXX-XXXX"

    "delta" — Delta Air Lines (business travel)
      From: "Delta Air Lines", address: "1030 Delta Blvd, Atlanta, GA 30354"
      Items: flight ticket (with route, e.g. "SFO to JFK Economy"), seat upgrade,
             checked baggage, in-flight WiFi
      2-4 items. Receipt number format: "DL-XXXXXXXXXX"

    === THERMAL VENDORS (narrow register tape — ALL CAPS, max 28 chars per item) ===

    "costco" — Costco Wholesale (warehouse club)
      From: "Costco Wholesale", address with warehouse # (e.g. "Warehouse #482, 1000 N Rengstorff Ave, Mountain View, CA 94043")
      Items: KS BATH TISSUE 30PK, KS OLIVE OIL 2L, ORG BLUEBERRIES 18OZ, ROTISSERIE CHICKEN,
             KS PAPER TOWELS 12PK, KIRKLAND WATER 40PK, TRAIL MIX 2LB
      3-8 items. Receipt number format: "XXXXXXXX" (8 digits)

    "homedepot" — The Home Depot (hardware / home improvement)
      From: "The Home Depot", address with store # (e.g. "Store #6345, 2435 Charleston Rd, Mountain View, CA 94043")
      Items: DW 20V DRILL KIT, 2X4X8 STUD, GE LED BULB 4PK, GORILLA GLUE 8OZ,
             BEHR PAINT GAL, 3M SANDPAPER 10PK, ROMEX WIRE 50FT
      2-6 items. Receipt number format: "HD-XXXX-XXXX-XXXX"

    "shell" — Shell (gas station)
      From: "Shell", address with station # (e.g. "Station #47821, 1200 El Camino Real, Mountain View, CA 94040")
      Items: REG UNLEADED 12.8G, SUPREME 10.2G, CAR WASH BASIC, DASANI WATER 20OZ, SNICKERS BAR
      2-3 items. Receipt number format: "SHL-XXXXXXXXX"

    "staples" — Staples (office supplies)
      From: "Staples", address with store # (e.g. "Store #1247, 680 E El Camino Real, Mountain View, CA 94040")
      Items: HP 64 INK BLK, COPY PAPER 10RM, SHARPIE FINE 12PK, SWINGLINE STAPLER,
             SCOTCH TAPE 6PK, POST-IT NOTES 12PK, BIC PENS 10PK
      2-6 items. Receipt number format: "STX-XXXX-XXXXXXX"

    "starbucks" — Starbucks (coffee / cafe)
      From: "Starbucks", address with store # (e.g. "Store #12847, 345 University Ave, Palo Alto, CA 94301")
      Items: ICED CARM MACCH GR, BACON GOUDA SNDWCH, CAKE POP, BRWD COFFEE TL,
             CHOC CROISSANT, DRGN DRINK VENTI, OATMILK LATTE GR
      2-4 items. Receipt number format: "STR-XXXX-XXXXXXX"

    "mcdonalds" — McDonald's (fast food)
      From: "McDonald's", address with store # (e.g. "Store #37421, 900 E El Camino Real, Sunnyvale, CA 94087")
      Items: BIG MAC MEAL, MCCHICKEN, MED FRIES, LG COKE, APPLE PIE,
             QTR POUNDER DLX, 10PC MCNUGGET, HASH BROWN
      2-5 items. Receipt number format: "MCD-XXXXXXXX"

    "chipotle" — Chipotle Mexican Grill (fast casual)
      From: "Chipotle Mexican Grill", address (e.g. "530 Bryant St, Palo Alto, CA 94301")
      Items: CHKN BURRITO BWL, CHIPS & GUAC, LG DRINK, QUESO BLNCO,
             STEAK TACOS 3PK, SIDE SOUR CREAM, CHIPS & SALSA
      2-4 items. Receipt number format: "CHP-XXXXXXXX"

    "walmart" — Walmart (retail / grocery)
      From: "Walmart Supercenter", address with store # (e.g. "Store #5434, 600 Showers Dr, Mountain View, CA 94040")
      Items: GV WHOLE MILK GAL, BOUNTY PAPER TWL, TIDE PODS 42CT, DORITOS NACHO 10OZ,
             BANANAS 1 BUNCH, GV WHITE BREAD, CLOROX WIPES 3PK, DAWN DISH SOAP
      3-8 items. Receipt number format: "TC# XXXX XXXX XXXX XXXX"

    GENERAL RULES:
    - All prices must be realistic for each vendor
    - Tax rate should be appropriate for the vendor's state (0.06-0.10)
    - amount = quantity * unit_price for each item
    - subtotal = sum of all item amounts
    - tax_amount = subtotal * tax_rate (rounded to 2 decimals)
    - total = subtotal + tax_amount
    - Payment method: use a realistic credit card format like "Visa ****4829" or "Amex ****1247"
    - The "to" field should be a realistic business purchaser name
    """
  end

  # When no customer context is provided, generate a fully random receipt.
  # The LLM picks a random vendor and a random purchaser name.
  defp user_prompt(nil) do
    """
    Generate a complete receipt from a randomly chosen vendor for a typical business purchase.
    Pick any one of the 12 vendor_id options and create items that would realistically appear
    on that vendor's receipt. Include 2-6 items depending on the vendor type.

    Respond using the following JSON schema:
    #{@receipt_schema_encoded}
    """
  end

  # When a customer map is provided, we pin the purchaser name so the receipt is
  # made out to the same person whose W2, 1099, and bank statement we generated.
  # This is important because card purchases on the bank statement should reference
  # merchants that match receipt vendors, and the purchaser name ties it all together.
  #
  # The receipt is the simplest case — we only need the customer's name for the "to"
  # field. The vendor, items, and pricing are always random because a person shops
  # at many different stores.
  defp user_prompt(customer) when is_map(customer) do
    """
    Generate a complete receipt from a randomly chosen vendor for a typical business purchase.
    Pick any one of the 12 vendor_id options and create items that would realistically appear
    on that vendor's receipt. Include 2-6 items depending on the vendor type.

    #{customer_block(customer)}

    The vendor, items, pricing, and all other details should be randomly generated.

    Respond using the following JSON schema:
    #{@receipt_schema_encoded}
    """
  end

  # Builds the identity constraint block for the receipt purchaser.
  #
  # The receipt only uses the customer's name — it goes into the "to" field
  # as the person or business who made the purchase. Unlike the W2 or 1099
  # which need SSNs and addresses, a receipt just needs to know who bought it.
  #
  # If the customer map has an address, we include it too since some receipts
  # (especially for business/shipping) include the buyer's address.
  defp customer_block(customer) do
    lines =
      [
        if(customer[:name], do: "- Purchaser name (the \"to\" field): #{customer[:name]}"),
        if(customer[:address], do: "- Purchaser address: #{customer[:address]}")
      ]
      |> Enum.reject(&is_nil/1)

    if lines == [] do
      ""
    else
      """
      IMPORTANT — You MUST use these exact details for the purchaser (do not change spelling, casing, or formatting):
      #{Enum.join(lines, "\n")}
      """
    end
  end
end
