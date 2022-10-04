defmodule Eakins.Storage.S3 do
  @moduledoc """
  S3 Based storage for uploaded images
  """

  alias ExAws.S3.Upload
  alias Eakins.Image
  alias Eakins.Storage

  @behaviour Storage

  def bucket do
    Application.get_env(:eakins, :s3_upload_bucket)
  end

  @impl Storage
  def store(parent_schema, image) do
    path = to_path(parent_schema, image)

    image.uri
    |> Upload.stream_file()
    |> ExAws.S3.upload(bucket(), path)
    |> ExAws.request()
    |> case do
      {:ok, _} ->
        {:ok, %{image | uri: "s3://#{bucket()}/#{path}", stored?: true}}

      {:error, _} = error ->
        error
    end
  end

  @impl Storage
  def delete_all do
    {:error, :not_implemented}
  end

  @impl Storage
  def delete(_, %{uri: uri}) do
    key = uri_to_key(uri)

    bucket()
    |> ExAws.S3.delete_object(key)
    |> ExAws.request()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _} = error ->
        error
    end
  end

  @impl Storage
  def exists?(_, image) do
    key = uri_to_key(image.uri)

    bucket()
    |> ExAws.S3.list_objects(prefix: key)
    |> ExAws.request()
    |> case do
      {:ok, response} ->
        keys =
          response
          |> get_in([:body, :contents])
          |> MapSet.new(& &1.key)

        MapSet.member?(keys, key)

      _ ->
        false
    end
  end

  defp to_path(parent_schema, %Image.Stored{} = image) do
    uuid = Ecto.UUID.autogenerate()
    extension = Path.extname(image.filename)
    image_type = to_string(image.key)
    image_filename = "#{uuid}-#{image_type}#{extension}"

    [
      "images",
      "uploads",
      dirname(parent_schema),
      to_string(parent_schema.id),
      to_string(image.key),
      image_filename
    ]
    |> Path.join()
  end

  defp uri_to_key(uri) do
    uri
    |> URI.parse()
    |> Map.get(:path)
    |> String.slice(1..-1)
  end

  defp dirname(%mod{}) do
    mod
    |> Module.split()
    |> Enum.map(&String.downcase/1)
    |> Enum.join(".")
  end
end
