defmodule PlatformWeb.AttachmentJSON do
  def show(%{signed_url: signed_url}), do: %{signed_url: signed_url}
end
