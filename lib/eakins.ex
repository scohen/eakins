defmodule Eakins do
  @moduledoc """
  Eakins is a simple library that allows you to store image urls in your ecto schemas.

  ## How it works
  Eakins relies on having a known _storage_ url embedded in your schema. This url is then used to create a
  display url that takes advantage of an image resizing proxy to show the image at the correct size and aspect ratio.
  Because an image proxy is used, changing your image sizes and aspects can be done at any time, and won't require you
  to go through all your images via a job queueuing system.

  ## Integrating it into your schemas

  To use Eakins with a schema, that schema must have a column with a `:map` datatype and a
  `version` column with an :integer data type. Then, `use Eakins.Schema` in your schema module
  and declare either an `image_map` or `image_list` field

  ```
  defmodule UserSchema do
    use Ecto.Schema
    use Eakins.Schema

    schema "users" do
      field :first_name, :string
      field :last_name, :name
      image_map :avatars
    end
  end
  ```
  Your schema is now has an avatar image map, where you can store multiple images under
  different keys. See `Eakins.Schema` for more information on what you can do with the field and
  see `Eakins.Image.Display` for how to generate URLs with the field's value.
  """

  @typedoc """
  an alias for an aspect ratio
  """
  @type aspect_alias :: :square

  @typedoc """
  An aspect ratio
  """
  @type aspect :: aspect_alias | {pos_integer(), pos_integer()}

  @typedoc """
  A height in pixels
  """
  @type custom_height :: pos_integer()
  @type named_size ::
          :tiny
          | :small
          | :medium
          | :large
          | :x_large
          | :avatar_small
          | :avatar_medium
          | :avatar_large

  @typedoc """
  The size of an image either via a named size or in pixels
  """
  @type size :: named_size() | custom_height()

  @type image :: Eakins.Image.Stored.t()

  @typedoc """
  The height of an image in pixels
  """
  @type height :: pos_integer()

  @typedoc """
  The index of an image in an image list
  """
  @type index :: integer

  @typedoc """
  The name of an image in an image map
  """
  @type name :: String.t() | atom()
  @type key :: index | name

  @typedoc """
  The gravity of an image. When resizing, the image's gravity holds
  it to that position.
  """
  @type gravity :: String.t()
end
