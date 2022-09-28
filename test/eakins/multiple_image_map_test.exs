defmodule Eakins.MultipleImageMapTest do
  use Eakins.DataCase
  alias Eakins.{Factories, Image, Repo}

  defmodule MultipleMaps do
    use Ecto.Schema

    use Eakins.Schema
    alias Eakins.Factories.Gravatar

    schema "multiple_maps" do
      field(:name, :string)
      image_map(:avatars)
      image_map(:headshots)
    end

    def default_avatar(%__MODULE__{} = image_map, _, _, height) do
      height = Image.resolve_height(height)

      %Image.Stored{
        key: "avatar",
        uri: Gravatar.url(image_map.name, size: height),
        content_type: "image/png",
        size: 308
      }
    end

    def default_avatar(_, _, _, _) do
      nil
    end

    def changeset(module, attrs) do
      Ecto.Changeset.change(module, attrs)
    end
  end

  def insert_image_map do
    %MultipleMaps{name: "Stinkypants"}
    |> MultipleMaps.changeset(%{})
    |> Repo.insert()
  end

  def with_image_map(_) do
    {:ok, multiple_bag} = insert_image_map()
    {:ok, model: multiple_bag}
  end

  def with_avatar(ctx) do
    avatar = Factories.Images.build(:named, key: :goofy, uri: "/foo/bar/goofy.png")

    {:ok, model} =
      ctx.model
      |> MultipleMaps.changeset(%{})
      |> MultipleMaps.put_avatar(avatar)
      |> Repo.update()

    {:ok, model: model}
  end

  def with_headshot(ctx) do
    avatar = Factories.Images.build(:named, key: "front_view", uri: "/foo/bar/goofy.png")

    {:ok, model} =
      ctx.model
      |> MultipleMaps.changeset(%{})
      |> MultipleMaps.put_headshot(avatar)
      |> Repo.update()

    {:ok, model: model}
  end

  describe "adding" do
    setup [:with_image_map]

    test "you can add an avatar", ctx do
      goofy_avatar = Factories.Images.build(:named, key: :goofy)

      {:ok, _} =
        ctx.model
        |> MultipleMaps.changeset(%{})
        |> MultipleMaps.put_avatar(goofy_avatar)
        |> Repo.update()

      model = Repo.get(MultipleMaps, ctx.model.id)
      assert [avatar] = model.avatars
      assert avatar.key == "goofy"
    end

    test "you can add a headshot", ctx do
      goofy_headshot = Factories.Images.build(:named, key: :goofy)

      {:ok, _} =
        ctx.model
        |> MultipleMaps.changeset(%{})
        |> MultipleMaps.put_headshot(goofy_headshot)
        |> Repo.update()

      model = Repo.get(MultipleMaps, ctx.model.id)
      assert [headshot] = model.headshots
      assert headshot.key == "goofy"
    end

    test "you can add an avatar and a headshot", ctx do
      serious_avatar = Factories.Images.build(:named, key: :serious)
      goofy_headshot = Factories.Images.build(:named, key: :goofy)

      {:ok, _} =
        ctx.model
        |> MultipleMaps.changeset(%{})
        |> MultipleMaps.put_headshot(goofy_headshot)
        |> MultipleMaps.put_avatar(serious_avatar)
        |> Repo.update()

      model = Repo.get(MultipleMaps, ctx.model.id)
      assert [headshot] = model.headshots
      assert headshot.key == "goofy"

      assert [avatar] = model.avatars
      assert avatar.key == "serious"
    end
  end

  describe "it should allow multiple image bags" do
    setup [:with_image_map, :with_avatar, :with_headshot]

    test "headshots should be able to be turned into displayable iamges", ctx do
      image = MultipleMaps.display_headshot(ctx.model, :front_view, :square, 80)

      assert String.starts_with?(image.uri, "https://proxy.eakins.test/")
      assert image.width == 80
      assert image.height == 80
      refute image.default?
    end

    test "avatars should be able to be turned into displayable images", ctx do
      image = MultipleMaps.display_avatar(ctx.model, :goofy, :square, 80)

      assert String.starts_with?(image.uri, "https://proxy.eakins.test/")
      assert image.width == 80
      assert image.height == 80
      refute image.default?
    end

    test "avatars have a default image", ctx do
      assert default = MultipleMaps.display_avatar(ctx.model, :deadly_serious, :square, 160)
      assert default.default?
      assert default.width == 160
      assert default.height == 160
    end

    test "headshots will not have a default image", ctx do
      assert nil == MultipleMaps.display_headshot(ctx.model, :back_view, :square, 80)
    end
  end
end
