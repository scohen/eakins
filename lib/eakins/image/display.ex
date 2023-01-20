defmodule Eakins.Image.Display do
  @moduledoc """
  A displayable image instance
  When created with a `Eakins.Image.Stored` image, this module creates an image suitable for display
  via our image proxy.
  """

  defstruct uri: nil,
            default?: false,
            width: nil,
            height: nil,
            content_type: nil,
            key: nil,
            original: nil,
            gravity: nil,
            aspect: nil

  alias Eakins.Image

  @type t :: %__MODULE__{
          uri: String.t(),
          default?: boolean,
          width: pos_integer(),
          height: pos_integer(),
          content_type: String.t(),
          original: Eakins.image(),
          key: Eakins.key(),
          gravity: Eakins.gravity()
        }

  @imgproxy_gravity_map %{
    "n" => "no",
    "s" => "so",
    "e" => "ea",
    "w" => "we",
    "ne" => "noea",
    "nw" => "nowe",
    "se" => "soea",
    "sw" => "sowe",
    "center" => "ce",
    "smart" => "sm"
  }

  def new(nil, _, _) do
    nil
  end

  def new(%Image.Stored{} = image, aspect, named_height) when is_atom(named_height) do
    height = Image.resolve_height(named_height)
    new(image, aspect, height)
  end

  def new(%Image.Stored{} = image, :square, height) when is_integer(height) do
    new(image, {1, 1}, height)
  end

  def new(%Image.Stored{} = image, aspect, height) do
    {width, height} = Image.apply_aspect_ratio(aspect, height)
    scaled_uri = generate_url(image.key, width, height, image.gravity, :fill, image.uri)

    %__MODULE__{
      content_type: image.content_type,
      default?: image.default?,
      height: height,
      key: image.key,
      original: image,
      uri: scaled_uri,
      width: width,
      gravity: image.gravity,
      aspect: aspect
    }
  end

  defp generate_url(key, width, height, gravity, type, source_url) do
    extension = extract_extension(key, source_url)
    encoded_source_url = Base.url_encode64(source_url, padding: false) <> extension
    imgproxy_gravity = Map.fetch!(@imgproxy_gravity_map, gravity)

    pipeline_opts =
      [
        # resizing
        [:rs, type, width, height, :t, :t],
        # gravity
        [:g, imgproxy_gravity]
      ]
      |> List.flatten()
      |> Enum.map_join(":", &to_string/1)

    path =
      [
        "",
        pipeline_opts,
        encoded_source_url
      ]
      |> Enum.join("/")

    sig = sign(path)
    imgproxy_scheme() <> "://" <> imgproxy_host() <> "/" <> sig <> path
  end

  defp extract_extension(key, url) do
    uri = URI.parse(url)
    extension = Path.extname(uri.path)
    key_string = to_string(key)

    cond do
      String.starts_with?(key_string, "logo_") ->
        extension

      extension == ".png" ->
        ".jpg"

      true ->
        extension
    end
  end

  defp sign(path) do
    :hmac
    |> :crypto.mac(:sha256, imgproxy_key(), imgproxy_salt() <> path)
    |> Base.url_encode64(padding: false)
  end

  defp imgproxy_host do
    Application.get_env(:eakins, :imgproxy_host)
  end

  defp imgproxy_key do
    :eakins
    |> Application.get_env(:imgproxy_key, "")
    |> Base.decode16!(case: :lower)
  end

  defp imgproxy_salt do
    :eakins
    |> Application.get_env(:imgproxy_salt, "")
    |> Base.decode16!(case: :lower)
  end

  defp imgproxy_scheme do
    Application.get_env(:eakins, :imgproxy_scheme, "https")
  end
end
