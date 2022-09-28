defmodule Eakins.Factories.Images do
  alias Eakins.Image

  def build(type, attrs \\ [])

  def build(:indexed, attrs) do
    name = attrs[:name] || "indexed"

    %Image.Stored{
      uri: "/images/named/#{name}.png",
      size: 15_536,
      key: "0",
      content_type: "image/png"
    }
    |> merge_attributes(attrs)
  end

  def build(:named, attrs) do
    name = attrs[:name] || "named"

    %Image.Stored{
      uri: "/images/named/#{name}.png",
      size: 15_536,
      key: name,
      content_type: "image/png"
    }
    |> merge_attributes(attrs)
  end

  defp merge_attributes(schema, attrs) do
    Enum.reduce(attrs, schema, fn {k, v}, schema ->
      Map.replace(schema, k, v)
    end)
  end
end
