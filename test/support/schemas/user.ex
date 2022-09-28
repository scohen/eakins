defmodule Eakins.Schemas.User do
  alias Ecto.Changeset
  use Ecto.Schema
  use Eakins.Schema

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    image_map(:avatar)
  end

  def changeset(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> Changeset.cast(attrs, [:first_name, :last_name])
    |> Changeset.validate_required([:first_name, :last_name])
  end
end
