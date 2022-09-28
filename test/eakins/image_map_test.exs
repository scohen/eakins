defmodule Eakins.ImageMapTest do
  use Eakins.DataCase

  alias Eakins.{Factories, Image, Storage}

  defmodule ImageMap do
    use Ecto.Schema
    use Eakins.Schema
    alias Eakins.Factories.Gravatar

    schema "image_map" do
      field(:name, :string)
      image_map(:images)
    end

    def default_image(%__MODULE__{} = image_map, "avatar", _, height) do
      %Image.Stored{
        key: "avatar",
        uri: Gravatar.url(image_map.name, size: height),
        content_type: "image/png",
        size: 308
      }
    end

    def default_image(_, _, _, _) do
      nil
    end

    def changeset(module, attrs) do
      Ecto.Changeset.change(module, attrs)
    end
  end

  def new_image(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:key, :avatar)
      |> Keyword.put_new(:uri, "/foo/bar/avatar.png")

    Factories.Images.build(:named, opts)
  end

  def insert_image_map do
    %ImageMap{name: "Stinkypants"}
    |> ImageMap.changeset(%{})
    |> Repo.insert()
  end

  def image_map(_) do
    {:ok, image_map} = insert_image_map()
    {:ok, image_map: image_map}
  end

  def with_avatar(ctx) do
    avatar = new_image()

    {:ok, image_map} =
      ctx.image_map
      |> ImageMap.changeset(%{})
      |> ImageMap.put_image(avatar)
      |> Repo.update()

    {:ok, image_map: image_map, avatar: avatar}
  end

  def with_selfie(ctx) do
    selfie = new_image(key: :selfie, uri: "/foo/bar/selfie.jpg", size: 29_354)

    {:ok, updated_image_map} =
      ctx.image_map
      |> ImageMap.changeset(%{})
      |> ImageMap.put_image(selfie)
      |> Repo.update()

    {:ok, image_map: updated_image_map, selfie: selfie}
  end

  @smallest_png <<120, 156, 99, 96, 1, 0, 0, 6, 0, 5>>

  def with_an_uploaded_png(_ctx) do
    file_path = Path.join(System.tmp_dir!(), "small.png")
    File.write(file_path, @smallest_png)

    on_exit(fn ->
      File.rm(file_path)
    end)

    uploaded_png = %Plug.Upload{
      path: file_path,
      content_type: "image/png",
      filename: "small.png"
    }

    {:ok, uploaded_png: uploaded_png}
  end

  describe "image_map" do
    setup [:image_map]

    test "an image_map starts out empty", ctx do
      assert ctx.image_map.images == []
    end

    test "an can add an image", ctx do
      image = new_image()

      {:ok, _} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(image)
        |> Repo.update()

      image_map = Repo.get(ImageMap, ctx.image_map.id)
      assert [image] = image_map.images
      assert image.key == "avatar"
      assert image.uri == "/foo/bar/avatar.png"
      assert image.size == image.size
      assert image.content_type == "image/png"
    end
  end

  describe "an image_map with an avatar" do
    setup [:image_map, :with_avatar]

    test "an image bag can have images with different names", ctx do
      selfie = new_image(key: "selfie", uri: "/foo/bar/selfie.png")

      ctx.image_map
      |> ImageMap.changeset(%{})
      |> ImageMap.put_image(selfie)
      |> Repo.update()

      image_map = Repo.get(ImageMap, ctx.image_map.id)

      assert [selfie, avatar] = image_map.images
      assert selfie.key == "selfie"
      assert selfie.uri == "/foo/bar/selfie.png"

      assert avatar.key == "avatar"
      assert avatar.uri == "/foo/bar/avatar.png"
    end

    test "an image can be overwritten", ctx do
      selfie = new_image(key: "selfie", uri: "/foo/bar/selfie.png")

      {:ok, image_map} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(selfie)
        |> Repo.update()

      new_avatar = new_image(key: :avatar, uri: "/foo/bar/avatar2.jpg", size: 14_437)

      image_map
      |> ImageMap.changeset(%{})
      |> ImageMap.put_image(new_avatar)
      |> Repo.update()

      image_map = Repo.get(ImageMap, image_map.id)
      assert [avatar, _selfie] = image_map.images

      assert avatar.uri == "/foo/bar/avatar2.jpg"
      assert avatar.size == 14_437
    end

    test "optimistic locking prevents concurrent access", ctx do
      avatar = new_image()
      selfie = new_image(key: :selfie, uri: "/foo/bar/selfie.png")

      {:ok, _} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(avatar)
        |> Repo.update()

      assert_raise Ecto.StaleEntryError, fn ->
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(selfie)
        |> Repo.update()
      end
    end
  end

  describe "delete_image/2" do
    setup [:image_map, :with_avatar, :with_selfie]

    test "can delete an image", ctx do
      assert {:ok, updated} =
               ctx.image_map
               |> ImageMap.changeset(%{})
               |> ImageMap.delete_image(:avatar)
               |> Repo.update()

      assert [selfie] = updated.images
      assert selfie.key == :selfie
    end

    test "can delete an image that was just added", ctx do
      other_image = new_image(key: "other")

      assert {:ok, updated} =
               ctx.image_map
               |> ImageMap.changeset(%{})
               |> ImageMap.put_image(other_image)
               |> ImageMap.delete_image("other")
               |> Repo.update()

      assert [:avatar, :selfie] == Enum.map(updated.images, & &1.key) |> Enum.sort()
    end

    test "can delete multiple images", ctx do
      assert {:ok, updated} =
               ctx.image_map
               |> ImageMap.changeset(%{})
               |> ImageMap.delete_image(:avatar)
               |> ImageMap.delete_image(:selfie)
               |> Repo.update()

      assert [] == Enum.map(updated.images, & &1.key)
    end

    test "can add and delete multiple images", ctx do
      foo_image = new_image(key: :foo)
      bar_image = new_image(key: :bar)
      baz_image = new_image(key: :baz)

      assert {:ok, updated} =
               ctx.image_map
               |> ImageMap.changeset(%{})
               |> ImageMap.put_image(foo_image)
               |> ImageMap.put_image(bar_image)
               |> ImageMap.delete_image(:avatar)
               |> ImageMap.put_image(baz_image)
               |> ImageMap.delete_image("bar")
               |> Repo.update()

      assert [:baz, :foo, :selfie] == Enum.map(updated.images, & &1.key)
    end
  end

  describe "has_image?/2" do
    setup [:image_map, :with_avatar]

    test "can check if an image exists", ctx do
      assert ImageMap.has_image?(ctx.image_map, :avatar)
      assert ImageMap.has_image?(ctx.image_map, "avatar")

      refute ImageMap.has_image?(ctx.image_map, :selfie)
      refute ImageMap.has_image?(ctx.image_map, "selfie")
    end
  end

  describe "image/3" do
    setup [:image_map, :with_avatar, :with_selfie]

    test "it will give a default if the image doesn't exist" do
      {:ok, image_map_with_no_avatar} = insert_image_map()
      scaled_image = ImageMap.display_image(image_map_with_no_avatar, "avatar", :square, 80)

      assert %Image.Display{} = scaled_image
      assert scaled_image.default?
      assert String.starts_with?(scaled_image.original.uri, "https://www.gravatar.com/avatar")
      assert scaled_image.content_type == "image/png"
    end

    test "a relative uri will be sent through the proxy", ctx do
      assert %Image.Display{} =
               scaled = ImageMap.display_image(ctx.image_map, :avatar, :square, 80)

      assert scaled.width == 80
      assert scaled.height == 80
      assert String.starts_with?(scaled.uri, "https://proxy.eakins.test/")
    end
  end

  describe "images/3" do
    setup [:image_map, :with_avatar, :with_selfie]

    test "returns an empty list if the image_map has no images" do
      {:ok, no_image_image_map} = insert_image_map()
      assert [] = ImageMap.display_images(no_image_image_map, :square, 80)
    end

    test "returns a list of scaled images if the image_map has images", ctx do
      assert [selfie, avatar] = ImageMap.display_images(ctx.image_map, :square, 80)
      assert avatar.original == ctx.avatar
      assert selfie.original == ctx.selfie
    end
  end

  describe "storage" do
    setup [:image_map, :with_an_uploaded_png, :clean_up_uploads]

    def clean_up_uploads(_) do
      on_exit(fn ->
        Storage.delete_all()
      end)

      :ok
    end

    test "it saves file to its storage", ctx do
      {:ok, image} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(:avatar, ctx.uploaded_png)
        |> Repo.update()

      assert [image] = image.images

      assert Storage.exists?(ctx.image_map, image)
      assert image.size == byte_size(@smallest_png)
    end

    test "it can save multiple files at once", ctx do
      {:ok, image} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(:avatar, ctx.uploaded_png)
        |> ImageMap.put_image(:other_thing, ctx.uploaded_png)
        |> Repo.update()

      assert [_, _] = image.images
    end

    test "it removes an image when it's been deleted", ctx do
      {:ok, image_map} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(:avatar, ctx.uploaded_png)
        |> Repo.update()

      [old_image] = image_map.images

      assert Storage.exists?(ctx.image_map, old_image)

      {:ok, _} =
        image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.delete_image(:avatar)
        |> Repo.update()

      refute Storage.exists?(ctx.image_map, old_image)
    end

    test "remove_image_from_storage/2", ctx do
      {:ok, image_map} =
        ctx.image_map
        |> ImageMap.changeset(%{})
        |> ImageMap.put_image(:avatar, ctx.uploaded_png)
        |> Repo.update()

      [old_image] = image_map.images

      assert Storage.exists?(ctx.image_map, old_image)

      ImageMap.remove_image_from_storage(ctx.image_map, old_image)

      refute Storage.exists?(ctx.image_map, old_image)
    end
  end
end
