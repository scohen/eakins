defmodule Eakins.ImageListTest do
  use Eakins.DataCase
  alias Eakins.{Factories, Image}

  defmodule ImageList do
    use Ecto.Schema
    use Eakins.Schema
    alias Eakins.Image
    alias Eakins.Factories.Gravatar

    schema "image_list" do
      field(:name, :string)
      image_list(:images)
    end

    def default_image(%__MODULE__{} = image_map, seq, _, _) do
      %Image.Stored{
        key: to_string(seq),
        uri: Gravatar.url(image_map.name),
        content_type: "image/png",
        size: 308
      }
    end

    def default_image(_, _, _, _) do
      nil
    end

    def changeset(module, attrs) do
      change(module, attrs)
    end
  end

  defmodule NoDefaults do
    use Ecto.Schema
    use Eakins.Schema

    schema "image_list" do
      field(:name, :string)
      image_list(:images)
    end

    def changeset(%__MODULE__{} = module, attrs) do
      change(module, attrs)
    end
  end

  def insert_image_list do
    %ImageList{name: "Listin' the images"}
    |> ImageList.changeset(%{})
    |> Repo.insert()
  end

  def an_image_list(_) do
    {:ok, image_list} = insert_image_list()
    {:ok, schema: image_list}
  end

  def with_two_images(ctx) do
    {:ok, schema} =
      ctx.schema
      |> ImageList.changeset(%{})
      |> ImageList.add_image(Factories.Images.build(:indexed, uri: "/first.png"))
      |> ImageList.add_image(Factories.Images.build(:indexed, uri: "/second.png"))
      |> Repo.update()

    [first_image, second_image] = schema.images

    {:ok, first_image: first_image, second_image: second_image, schema: schema}
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

  describe "insert_at/2" do
    setup [:an_image_list]

    test "you can put an image before another", ctx do
      first_image = Factories.Images.build(:indexed, uri: "/first.png")
      second_image = Factories.Images.build(:indexed, uri: "/second.png")

      assert {:ok, _schema} =
               ctx.schema
               |> ImageList.changeset(%{})
               |> ImageList.add_image(first_image)
               |> ImageList.insert_image_at(-1, second_image)
               |> Repo.update()

      schema = Repo.get(ImageList, ctx.schema.id)
      assert [first, second] = schema.images
      assert first.uri == first_image.uri
      assert second.uri == second_image.uri
    end

    test "you can add to the start of the image list", ctx do
      first_image = Factories.Images.build(:indexed, uri: "/first.png")
      second_image = Factories.Images.build(:indexed, uri: "/second.png")

      {:ok, _} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.insert_image_at(0, first_image)
        |> ImageList.insert_image_at(0, second_image)
        |> Repo.update()

      schema = Repo.get(ImageList, ctx.schema.id)
      assert [second, first] = schema.images
      assert second.uri == second_image.uri
      assert first.uri == first_image.uri
    end

    test "you can add an image at a time", ctx do
      first_image = Factories.Images.build(:indexed, uri: "/first.png")
      second_image = Factories.Images.build(:indexed, uri: "/second.png")

      assert {:ok, _} =
               ctx.schema
               |> ImageList.changeset(%{})
               |> ImageList.insert_image_at(0, first_image)
               |> Repo.update()

      assert {:ok, _} =
               Repo.get(ImageList, ctx.schema.id)
               |> ImageList.changeset(%{})
               |> ImageList.insert_image_at(-1, second_image)
               |> Repo.update()

      schema = Repo.get(ImageList, ctx.schema.id)

      assert [first, second] = schema.images
      assert first.uri == first_image.uri
      assert second.uri == second_image.uri
    end

    test "the key is the same as the index", ctx do
      first_image = Factories.Images.build(:indexed, uri: "/first.png")
      second_image = Factories.Images.build(:indexed, uri: "/second.png")
      third_image = Factories.Images.build(:indexed, uri: "/third.png")

      assert {:ok, _} =
               ctx.schema
               |> ImageList.changeset(%{})
               |> ImageList.add_image(first_image)
               |> ImageList.add_image(second_image)
               |> ImageList.add_image(third_image)
               |> Repo.update()

      schema = Repo.get(ImageList, ctx.schema.id)

      assert [first, second, third] = schema.images
      assert first.key == "0"
      assert first.uri == "/first.png"

      assert second.key == "1"
      assert second.uri == "/second.png"

      assert third.key == "2"
      assert third.uri == "/third.png"
    end

    test "optimistic locking prevents stale updates", ctx do
      assert {:ok, _} =
               ctx.schema
               |> ImageList.changeset(%{})
               |> ImageList.add_image(Factories.Images.build(:indexed))
               |> Repo.update()

      assert_raise Ecto.StaleEntryError, fn ->
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.add_image(Factories.Images.build(:indexed))
        |> Repo.update()
      end
    end
  end

  describe "image_at/2" do
    setup [:an_image_list, :with_two_images]

    test "you can find an image by index", ctx do
      assert ctx.first_image == ImageList.image_at(ctx.schema, 0)
      assert ctx.second_image == ImageList.image_at(ctx.schema, 1)
    end

    test "if no index exists, nil is returned", ctx do
      assert nil == ImageList.image_at(ctx.schema, 5)
    end
  end

  describe "replace_image_at/3" do
    setup [:an_image_list, :with_two_images]

    test "you can replace the last image", ctx do
      replacement = Factories.Images.build(:indexed, uri: "/replaced.png")

      {:ok, _} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.replace_image_at(1, replacement)
        |> Repo.update()

      schema = Repo.get(ImageList, ctx.schema.id)

      assert [first, replaced] = schema.images
      assert first.uri == ctx.first_image.uri
      assert replaced.uri == replacement.uri
    end

    test "you can replace the first image", ctx do
      replacement = Factories.Images.build(:indexed, uri: "/replaced.png")

      {:ok, _} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.replace_image_at(0, replacement)
        |> Repo.update()

      schema = Repo.get(ImageList, ctx.schema.id)

      assert [replaced, second] = schema.images
      assert second.uri == ctx.second_image.uri
      assert replaced.uri == replacement.uri
    end
  end

  describe "delete_image_at/2" do
    setup [:an_image_list, :with_two_images]

    test "you can delete the first image by its index", ctx do
      {:ok, schema} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.delete_image_at(0)
        |> Repo.update()

      assert [image] = schema.images
      assert image.uri == "/second.png"

      schema = Repo.get(ImageList, schema.id)

      assert [image] = schema.images
      assert image.uri == "/second.png"
      assert image.key == "0"
    end

    test "you can delete the last image by its index", ctx do
      {:ok, schema} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.delete_image_at(1)
        |> Repo.update()

      assert [image] = schema.images
      assert image.uri == "/first.png"

      schema = Repo.get(ImageList, schema.id)

      assert [image] = schema.images
      assert image.uri == "/first.png"
    end
  end

  describe "display_images/3" do
    setup [:an_image_list, :with_two_images]

    test "returns images that are scaled", ctx do
      assert [image_1, image_2] = ImageList.display_images(ctx.schema, :square, 80)
      assert image_1.width == 80
      assert image_1.height == 80
      assert image_1.original == ctx.first_image

      assert image_2.width == 80
      assert image_2.height == 80
      assert image_2.original == ctx.second_image
    end
  end

  describe "display_image/4" do
    setup [:an_image_list, :with_two_images]

    test "you can request scaled instances for a single image", ctx do
      image = ImageList.display_image(ctx.schema, 0, :square, 80)

      assert String.starts_with?(image.uri, "https://proxy.eakins.test/")
      assert image.original == ctx.first_image
      assert image.width == 80
      assert image.height == 80
    end

    test "it returns a default image if you ask for a index that doesn't exist", ctx do
      image = ImageList.display_image(ctx.schema, 2, :square, 80)

      assert %Image.Display{} = image
      assert image.default?
    end

    test "nil is returned if no default function is defined" do
      assert nil == NoDefaults.display_image(%NoDefaults{}, 2, :square, 80)
    end

    test "you can get all scaled instances", ctx do
      images = ImageList.display_images(ctx.schema, :square, 90)

      assert [image_1, image_2] = images
      assert image_1.original == ctx.first_image
      assert image_1.width == 90
      assert image_1.height == 90

      assert image_2.original == ctx.second_image
      assert image_2.width == 90
      assert image_2.height == 90
    end
  end

  describe "storage" do
    setup [:an_image_list, :with_an_uploaded_png, :clean_up_uploads]

    def clean_up_uploads(_) do
      on_exit(fn ->
        Eakins.Storage.delete_all()
      end)
    end

    test "it saves files into its storage", ctx do
      {:ok, image_list} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.add_image(ctx.uploaded_png)
        |> Repo.update()

      [image] = image_list.images
      assert Eakins.Storage.exists?(image_list, image)
    end

    test "remove_image_from_storage/2", ctx do
      {:ok, schema} =
        ctx.schema
        |> ImageList.changeset(%{})
        |> ImageList.add_image(ctx.uploaded_png)
        |> Repo.update()

      [old_image] = schema.images

      assert Eakins.Storage.exists?(schema, old_image)

      ImageList.remove_image_from_storage(schema, old_image)

      refute Eakins.Storage.exists?(schema, old_image)
    end
  end
end
