defmodule Eakins.AspectRatio do
  @moduledoc false

  @spec parse(String.t()) :: {:ok, Eakins.aspect()} | :error
  def parse("original"), do: {:ok, :original}

  def parse("1:1"), do: {:ok, :square}

  def parse(aspect_ratio) do
    with [w, h] <- String.split(aspect_ratio, ":"),
         {w, ""} <- Integer.parse(w),
         {h, ""} <- Integer.parse(h) do
      {:ok, {w, h}}
    else
      _ -> :error
    end
  end
end
