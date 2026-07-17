defmodule Platform.Chaos.Tools do
  alias Platform.Chaos.Tools.Invoice
  require Logger

  def init("invoice") do
    state = %{
      invoice_number: Invoice.random_invoice_number(),
      from: %{
        name: "Summit Building Supply Co.",
        email: "billing@summitbuildingsupply.com",
        address: "4720 Industrial Parkway, Denver, CO 80216"
      },
      to: %{
        name: "Ironridge Construction LLC",
        email: "accounts@ironridgeconstruction.com",
        address: "1385 Commerce Dr., Suite 200, Aurora, CO 80011"
      },
      items: Invoice.random_line_items(),
      tax_rate: Invoice.random_tax_rate()
    }

    {:ok, state}
  end

  def init(_topic) do
    {:ok, %{}}
  end

  def generate_attachment(from, state, "pdf") do
    params = %{
      agent_name: from,
      invoice_number: state.invoice_number,
      items: state.items,
      tax_rate: state.tax_rate,
      from: state.from,
      to: state.to
    }

    url = fetch_invoice_url()

    r =
      Req.new(
        method: "POST",
        url: fetch_invoice_url(),
        headers: %{"content-type" => "application/json"},
        body: Jason.encode!(params)
      )

    case Req.request(r) do
      {:ok, %Req.Response{status: 201, body: %{"location" => location, "filename" => filename}}} ->
        Logger.info("'#{from}' agent successfully created PDF")
        {:ok, {location, filename}}

      {:ok, %Req.Response{status: 201, body: body}} ->
        Logger.error("'#{from}' got unexpected response body, returning nil: #{inspect(body)}")
        {:error, :noretry}

      {:ok, %Req.Response{status: status, body: body}} when status >= 500 ->
        Logger.error("'#{from}' got server error with body #{inspect(body)}")
        {:error, :retry}

      {:ok, %Req.Response{status: status}} when status >= 400 and status <= 499 ->
        Logger.error("'#{from}' got unexpected response code #{status}, returning nil")
        {:error, :noretry}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        Logger.error("'#{from}' agent connection was refused for url '#{url}'. Is it running?")
        {:error, :noretry}

      {:error, %Req.TransportError{reason: :nxdomain}} ->
        Logger.error("'#{from}' agent could not resolve url '#{url}'")
        {:error, :noretry}

      {:error, reason} ->
        Logger.error("'#{from}' agent failed pdf generation with reason: #{inspect(reason)}")
        {:error, :retry}
    end
  end

  def generate_attachment(_from, _state, media_type) do
    {:error, {:unsupported, media_type}}
  end

  defp fetch_invoice_url() do
    Application.fetch_env!(:platform, Platform.PDFAgent)
    |> Keyword.fetch!(:invoice_url)
  end
end
