defmodule Eakins.Storage.Local do
  @moduledoc """
  Development-only local storage for image uploads.
  """
  alias Eakins.{Image, Storage}
  require Config

  @behaviour Storage

  def storage_root do
    :eakins
    |> Application.get_env(:env, :prod)
    |> storage_root_for()
  end

  @impl Storage
  def delete_all do
    if Application.get_env(:eakins, :env, :prod) == :test do
      File.rm_rf(storage_root())
    else
      raise "delete_all is not supported in this environment"
    end
  end

  @impl Storage
  def delete(_parent_schema, image) do
    local_path = local_path(image)

    if File.exists?(local_path) && File.regular?(local_path) do
      File.rm(local_path)
    else
      :ok
    end
  end

  @impl Storage
  def exists?(_parent_schema, image) do
    local_path = local_path(image)
    File.exists?(local_path)
  end

  @impl Storage
  def store(parent_schema, image) do
    %{dir: dest_dir, filename: filename, uri: uri} = paths_for(parent_schema, image)

    with :ok <- File.mkdir_p(dest_dir),
         :ok <- File.cp(image.uri, filename) do
      stored_image = %{image | uri: uri, stored?: true, filename: nil}
      {:ok, stored_image}
    end
  end

  defp paths_for(parent_schema, %Image.Stored{} = image) do
    uuid = Ecto.UUID.autogenerate()

    extension = Path.extname(image.filename)
    image_type = to_string(image.key)
    filename = "#{uuid}-#{image_type}#{extension}"

    dest_dir = Path.join([storage_root(), dirname(parent_schema), to_string(parent_schema.id)])
    dest_file = Path.join(dest_dir, filename)

    image_path =
      ["images", "uploads", dirname(parent_schema), to_string(parent_schema.id), filename]
      |> Path.join()

    %{
      dir: dest_dir,
      filename: dest_file,
      uri: "local://#{image_path}"
    }
  end

  defp local_path(%Image.Stored{} = image) do
    [root, _ | rest] = URI.parse(image.uri).path |> Path.split()
    storage_root() <> Path.join([root | rest])
  end

  defp storage_root_for(:test) do
    Path.join(System.tmp_dir(), "uploads")
  end

  defp storage_root_for(:dev) do
    :eakins
    |> Application.app_dir(:upload_directory)
    |> Path.join()
    |> Path.expand()
  end

  defp dirname(%module{}) do
    module
    |> Module.split()
    |> Enum.map(&String.downcase/1)
    |> Enum.join(".")
  end
end
