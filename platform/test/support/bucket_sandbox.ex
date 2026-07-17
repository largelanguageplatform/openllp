defmodule Platform.Bucket.Sandbox do
  def start() do
    bucket = Keyword.get(Application.get_env(:platform, Platform.StorageBucket), :bucket)

    if bucket != nil do
      config = ExAws.Config.new(:s3)

      ExAws.S3.put_bucket(bucket, config.region)
      |> ExAws.request()
    end
  end
end
