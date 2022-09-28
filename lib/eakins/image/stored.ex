defmodule Eakins.Image.Stored do
  use Ecto.Schema
  alias Eakins.Image

  @primary_key false

  embedded_schema do
    field :key, :string
    field :uri, :string
    field :content_type, :string
    field :size, :integer
    field :gravity, :string, default: Image.default_gravity()
    field :default?, :boolean, virtual: true, default: false
    field :filename, :string, virtual: true
    field :stored?, :boolean, virtual: true, default: true
  end

  @type name :: String.t()
  @type t :: %__MODULE__{}

  def from_upload(%Plug.Upload{} = upload, key) do
    %__MODULE__{
      key: to_string(key),
      uri: upload.path,
      filename: upload.filename,
      stored?: false,
      content_type: upload.content_type,
      size: File.stat!(upload.path).size
    }
  end

  def new(key, uri, size) do
    content_type =
      uri
      |> URI.parse()
      |> Map.get(:path)
      |> :mimerl.filename()

    %__MODULE__{key: to_string(key), uri: uri, size: size, content_type: content_type}
  end

  def changeset(image, %__MODULE__{} = attrs) do
    changeset(image, Map.from_struct(attrs))
  end

  def changeset(image, attrs) do
    Ecto.Changeset.change(image, attrs)
  end
end
