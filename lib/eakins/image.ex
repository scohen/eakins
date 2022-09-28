defmodule Eakins.Image do
  @moduledoc false

  @named_heights %{
    x_large: 1024,
    large: 800,
    medium: 240,
    small: 120,
    tiny: 64,
    avatar_large: 128,
    avatar_medium: 64,
    avatar_small: 32
  }

  @gravities ~w(n s e w ne nw se sw center smart)

  @default_gravity "smart"

  @supported_aspect_ratios [{1, 1}, {2, 3}, {4, 5}, {21}]

  @type image :: %{}

  def apply_aspect_ratio(:square, height) do
    apply_aspect_ratio({1, 1}, height)
  end

  def apply_aspect_ratio(:original, height) do
    {0, height}
  end

  def apply_aspect_ratio({same, same}, height) do
    {height, height}
  end

  def apply_aspect_ratio({width_aspect, height_aspect}, desired_height) do
    desired_height = resolve_height(desired_height)
    desired_width = round(desired_height * (width_aspect / height_aspect))
    {desired_width, desired_height}
  end

  def resolve_height(size) when is_integer(size), do: size

  def resolve_height(named_size) when is_map_key(@named_heights, named_size) do
    Map.get(@named_heights, named_size)
  end

  def supported_aspect_ratios do
    @supported_aspect_ratios
  end

  def gravities do
    @gravities
  end

  def default_gravity do
    @default_gravity
  end
end
