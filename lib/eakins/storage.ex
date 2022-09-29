defmodule Eakins.Storage do
  @moduledoc """
  The storage interface for uploaded images
  """

  alias Eakins.Image
  @type parent_schema :: Ecto.Schema.schema()
  @type image :: Image.Stored.t()

  @callback delete_all() :: :ok | {:error, term}
  @callback delete(parent_schema, image) :: :ok | {:error, term}
  @callback store(parent_schema, image) :: {:ok, image} | {:error, term}
  @callback exists?(parent_schema, image) :: boolean

  @optional_callbacks delete_all: 0

  def exists?(parent_schema, image) do
    storage_backend().exists?(parent_schema, image)
  end

  def delete(_, nil) do
    :ok
  end

  def delete(parent_schema, image) do
    storage_backend().delete(parent_schema, image)
  end

  def delete_all do
    if function_exported?(storage_backend(), :delete_all, 0) do
      apply(storage_backend(), :delete_all, [])
    else
      {:error, :not_supported}
    end
  end

  def store(parent_schema, %{stored?: false} = image) do
    storage_backend().store(parent_schema, image)
  end

  def store(_, image) do
    {:ok, image}
  end

  defp storage_backend do
    Application.get_env(:eakins, :storage_module, Eakins.Storage.Local)
  end
end
