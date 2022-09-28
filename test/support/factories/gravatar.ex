defmodule Eakins.Factories.Gravatar do
  def url(name, opts \\ []) do
    size = Keyword.get(opts, :size, 80)

    path =
      ["avatar", Ecto.UUID.autogenerate(), name, size, "image.png"]
      |> Enum.map(&to_string/1)
      |> Path.join()

    "https://www.gravatar.com/#{path}"
  end
end
