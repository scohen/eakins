defmodule Eakins.Factories.User do
  alias Eakins.Repo
  alias Eakins.Schemas.User

  def insert(:user, attrs \\ []) do
    attrs
    |> Enum.reduce(%User{}, fn {k, v}, user ->
      Map.replace(user, k, v)
    end)
    |> Repo.insert()
  end
end
