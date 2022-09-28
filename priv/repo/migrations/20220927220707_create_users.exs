defmodule Eakins.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :avatar, :map
      add :version, :integer
    end
  end
end
