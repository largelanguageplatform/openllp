defmodule Platform.Chaos do
  import Ecto.Query, warn: false
  alias Platform.Admin.DomainPersona
  alias Platform.Repo
  alias Platform.Agent.Domain
  alias Platform.Chaos.Attachment
  alias Platform.Account.Scope

  def list_domains() do
    list_domains(0)
  end

  def list_domains(id) do
    from(subdomain in Domain,
      where: subdomain.parent_domain_id == ^id or subdomain.id == 0,
      order_by: [desc: :id]
    )
    |> Repo.all()
  end

  def list_prompts(%Domain{} = s) do
    get_domain_tree(s, [s])
    |> Enum.map(fn s ->
      Repo.all_by(DomainPersona, domain_id: s.id, status: :enabled)
    end)
    |> List.flatten([])
    |> Enum.uniq_by(fn s -> s.id end)
  end

  defp get_domain_tree(%Domain{parent_domain_id: nil}, tree), do: tree

  defp get_domain_tree(%Domain{} = s, tree) do
    node =
      from(subdomain in Domain,
        where: subdomain.id == ^s.parent_domain_id
      )
      |> Repo.one()

    get_domain_tree(node, [node | tree])
  end

  def create_attachment(%Scope{} = scope, attrs) do
    %Attachment{organization: scope.organization}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  def s3_signed_url(filename) do
    with {:ok, %{bucket: bucket, location: location}} <- storage_bucket_config(filename),
         config <- ExAws.Config.new(:s3),
         {:ok, url} <- ExAws.S3.presigned_url(config, :put, bucket, location, expires: 120) do
      {:ok, %{signed_url: url, bucket: bucket, location: location, filename: filename}}
    end
  end

  def get_attachment(filename) do
    Attachment
    |> preload([:organization])
    |> Repo.get_by(filename: filename)
  end

  def download_attachment(%Attachment{} = attachment) do
    ExAws.S3.get_object(attachment.bucket, attachment.location)
    |> ExAws.request()
  end

  def download_attachment(nil), do: {:error, :not_found}

  defp storage_bucket_config(filename) do
    config = Application.get_env(:platform, Platform.StorageBucket)

    case {Keyword.get(config, :bucket), Keyword.get(config, :location_prefix)} do
      {nil, nil} -> {:error, {:missing, [:bucket, :location_prefix]}}
      {nil, _} -> {:error, {:missing, [:bucket]}}
      {_, nil} -> {:error, {:missing, [:location_prefix]}}
      {bucket, prefix} -> {:ok, %{bucket: bucket, location: prefix <> "/" <> filename}}
    end
  end
end
