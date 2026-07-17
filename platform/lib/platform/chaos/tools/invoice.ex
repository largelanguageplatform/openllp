defmodule Platform.Chaos.Tools.Invoice do
  @items [
    %{description: "Portland Cement Type I/II (94 lb bag)", unit_price: 14.50},
    %{description: "Ready-Mix Concrete (per cubic yard)", unit_price: 165.00},
    %{description: "#4 Rebar, Grade 60 (20 ft length)", unit_price: 12.75},
    %{description: "2x4x8 Pressure-Treated Lumber", unit_price: 6.98},
    %{description: "3/4\" Plywood Sheathing (4x8 sheet)", unit_price: 42.50},
    %{description: "6x6 W2.9/W2.9 Welded Wire Mesh (5x150 ft roll)", unit_price: 189.00},
    %{description: "Coarse Aggregate / Gravel (per ton)", unit_price: 38.00},
    %{description: "1/2\" Drywall Sheet (4x8)", unit_price: 14.25}
  ]

  def random_invoice_number do
    "INV-#{:rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")}"
  end

  def random_tax_rate do
    Enum.random([0.04, 0.065, 0.075, 0.08, 0.085, 0.10])
  end

  @doc """
  Returns a random selection of invoice line items with random quantities.

  Each call returns between 1 and #{length(@items)} items, each with a
  random quantity between 1 and 50.
  """
  def random_line_items do
    count = Enum.random(1..length(@items))

    @items
    |> Enum.shuffle()
    |> Enum.take(count)
    |> Enum.map(fn item ->
      Map.put(item, :quantity, Enum.random(1..50))
    end)
  end
end
