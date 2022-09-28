defmodule Eakins.MultipleImageListTest do
  alias Eakins.Factories
  use Eakins.DataCase

  defmodule PhotoAlbum do
    use Ecto.Schema
    use Eakins.Schema

    schema "multiple_lists" do
      field(:name, :string)
      image_list(:outside_shots)
      image_list(:inside_shots)
    end

    def changeset(%__MODULE__{} = module, attrs) do
      change(module, attrs)
    end
  end

  def insert_photo_album do
    %PhotoAlbum{name: "Photos"}
    |> PhotoAlbum.changeset(%{})
    |> Repo.insert()
  end

  def a_photo_album(_) do
    {:ok, album} = insert_photo_album()
    {:ok, album: album}
  end

  describe "adding to both lists" do
    setup [:a_photo_album]

    test "you can add an outside shot", ctx do
      outside = Factories.Images.build(:indexed, uri: "photos/outside.png")

      {:ok, _album} =
        ctx.album
        |> PhotoAlbum.changeset(%{})
        |> PhotoAlbum.add_outside_shot(outside)
        |> Repo.update()

      album = Repo.get(PhotoAlbum, ctx.album.id)
      assert [outside_shot] = album.outside_shots
      assert outside_shot == outside
    end

    test "you can add an inside shot", ctx do
      inside = Factories.Images.build(:indexed, uri: "photos/inside.png")

      {:ok, _album} =
        ctx.album
        |> PhotoAlbum.changeset(%{})
        |> PhotoAlbum.add_inside_shot(inside)
        |> Repo.update()

      album = Repo.get(PhotoAlbum, ctx.album.id)
      assert [inside_shot] = album.inside_shots
      assert inside_shot == inside
    end

    test "you can add images to both albums at once", ctx do
      outside = Factories.Images.build(:indexed, uri: "photos/outside.png")
      inside = Factories.Images.build(:indexed, uri: "photos/inside.png")

      {:ok, _} =
        ctx.album
        |> PhotoAlbum.changeset(%{})
        |> PhotoAlbum.add_outside_shot(outside)
        |> PhotoAlbum.add_inside_shot(inside)
        |> Repo.update()

      album = Repo.get(PhotoAlbum, ctx.album.id)

      assert [outside_shot] = album.outside_shots
      assert outside_shot == outside

      assert [inside_shot] = album.inside_shots
      assert inside_shot == inside
    end

    test "you can add to each image list separately", ctx do
      outside = Factories.Images.build(:indexed, uri: "photos/outside.png")
      inside = Factories.Images.build(:indexed, uri: "photos/inside.png")

      {:ok, album} =
        ctx.album
        |> PhotoAlbum.changeset(%{})
        |> PhotoAlbum.add_outside_shot(outside)
        |> Repo.update()

      {:ok, _} =
        album
        |> PhotoAlbum.changeset(%{})
        |> PhotoAlbum.add_inside_shot(inside)
        |> Repo.update()

      album = Repo.get(PhotoAlbum, ctx.album.id)
      assert [outside_shot] = album.outside_shots
      assert outside_shot == outside

      assert [inside_shot] = album.inside_shots
      assert inside_shot == inside
    end
  end
end
