defmodule Eakins.Repo.Migrations.Initial do
  use Ecto.Migration

  def change do
    create table(:image_map) do
      add :name, :string
      add :images, :map
      add :version, :integer, default: 0
    end

    create table(:image_list) do
      add :name, :string
      add :images, :map
      add :version, :integer, default: 0
    end

    create table(:multiple_maps) do
      add :name, :string
      add :avatars, :map
      add :headshots, :map
      add :version, :integer, default: 0
    end

    create table(:multiple_lists) do
      add :name, :string
      add :outside_shots, :map
      add :inside_shots, :map
      add :version, :integer, default: 0
    end

    create table(:list_and_map) do
      add :name, :string
      add :avatars, :map
      add :photos, :map
      add :version, :integer
    end
  end
end
