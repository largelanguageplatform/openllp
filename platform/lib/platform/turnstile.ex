defmodule Platform.Turnstile do
  @moduledoc """
  Cloudflare Turnstile captcha verification.
  """

  require Logger

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  @doc """
  Verifies a Turnstile token.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def verify(token, remote_ip \\ nil) when is_binary(token) do
    secret_key = Application.get_env(:platform, :turnstile)[:secret_key]

    Logger.debug(
      "Turnstile secret key (first 10 chars): #{String.slice(secret_key || "", 0, 10)}..."
    )

    body =
      %{secret: secret_key, response: token}
      |> maybe_add_remote_ip(remote_ip)

    case Req.post(@verify_url, json: body) do
      {:ok, %{status: 200, body: %{"success" => true}}} ->
        Logger.info("Turnstile verification successful")
        :ok

      {:ok, %{status: 200, body: %{"success" => false, "error-codes" => codes}}} ->
        Logger.warning("Turnstile verification failed: #{inspect(codes)}")
        {:error, codes}

      {:error, reason} ->
        Logger.warning("Turnstile API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_add_remote_ip(body, nil), do: body
  defp maybe_add_remote_ip(body, ip), do: Map.put(body, :remoteip, ip)

  @doc """
  Returns the Turnstile site key for frontend use.
  """
  def site_key do
    Application.get_env(:platform, :turnstile)[:site_key]
  end
end
