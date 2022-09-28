defmodule Eakins.Storage.S3Test do
  use Eakins.DataCase
  @moduletag :external

  alias Eakins.Factories
  alias Eakins.{Image, Storage}

  def create_temp_file(extension, contents) do
    unique_id = System.unique_integer([:positive, :monotonic])
    filename = "#{__MODULE__}-temp-#{unique_id}.#{extension}"

    file_path = Path.join(System.tmp_dir(), filename)
    File.write!(file_path, contents)
    file_path
  end

  def new_upload do
    file_path = create_temp_file(".png", "hi")

    on_exit(fn -> File.rm(file_path) end)

    %Plug.Upload{
      path: file_path,
      content_type: "image/png",
      filename: Path.basename(file_path)
    }
  end

  def an_uploaded_named_image(ctx) do
    named_image =
      new_upload()
      |> Image.Stored.from_upload(:avatar)

    {:ok, image} = Storage.S3.store(ctx.parent, named_image)

    {:ok, named_image: image}
  end

  def an_uploaded_indexed_image(ctx) do
    indexed_image =
      new_upload()
      |> Image.Stored.from_upload(0)

    {:ok, image} = Storage.S3.store(ctx.parent, indexed_image)

    {:ok, indexed_image: image}
  end

  def delete_bucket do
    {:ok, response} =
      Storage.S3.bucket()
      |> ExAws.S3.list_objects()
      |> ExAws.request()

    keys =
      response
      |> get_in([:body, :contents])
      |> Enum.map(& &1.key)

    {:ok, _} =
      Storage.S3.bucket()
      |> ExAws.S3.delete_all_objects(keys)
      |> ExAws.request()

    {:ok, _} =
      Storage.S3.bucket()
      |> ExAws.S3.delete_bucket()
      |> ExAws.request()

    :ok
  end

  def exists?(uri) do
    key =
      uri
      |> URI.parse()
      |> Map.get(:path)
      |> String.slice(1..-1)

    {:ok, response} =
      Storage.S3.bucket()
      |> ExAws.S3.list_objects(prefix: key)
      |> ExAws.request()

    keys =
      response
      |> get_in([:body, :contents])
      |> MapSet.new(& &1.key)

    MapSet.member?(keys, key)
  end

  setup_all do
    region = Application.get_env(:ex_aws, :region, "us-west-2")

    {:ok, _} =
      Storage.S3.bucket()
      |> ExAws.S3.put_bucket(region)
      |> ExAws.request()

    on_exit(&delete_bucket/0)

    :ok
  end

  setup do
    parent_schema = Factories.User.insert(:employee)
    {:ok, parent: parent_schema}
  end

  test "it should be able to save a named image", ctx do
    upload =
      new_upload()
      |> Image.Stored.from_upload(:avatar)

    assert {:ok, %Image.Stored{} = image} = Storage.S3.store(ctx.parent, upload)
    assert exists?(image.uri)
    assert image.size == 2
    assert String.starts_with?(image.uri, "s3:///images/uploads")
    refute image.stored?
  end

  test "it should be able to save a indexed image", ctx do
    indexed_image =
      new_upload()
      |> Image.Stored.from_upload(0)

    assert {:ok, %Image.Stored{} = image} = Storage.S3.store(ctx.parent, indexed_image)
    assert exists?(image.uri)
    assert image.size == 2
    assert String.starts_with?(image.uri, "s3:///images/uploads")
    refute image.stored?
  end

  describe "when a named image has been uploaded" do
    setup [:an_uploaded_named_image]

    test "it should exist", ctx do
      assert Storage.S3.exists?(ctx.parent, ctx.named_image)
    end

    test "a bogus image doesn't exist", ctx do
      bogus = %{ctx.named_image | uri: String.slice(ctx.named_image.uri, 0..-2)}
      refute Storage.S3.exists?(ctx.parent, bogus)
    end

    test "it can be deleted", ctx do
      assert :ok = Storage.S3.delete(ctx.parent, ctx.named_image)
      refute Storage.S3.exists?(ctx.parent, ctx.named_image)
    end

    test "deleting a bogus image is a no-op", ctx do
      bogus = %{ctx.named_image | uri: String.slice(ctx.named_image.uri, 0..-2)}
      assert :ok = Storage.S3.delete(ctx.parent, bogus)
    end
  end

  describe "a indexed image has been uploaded" do
    setup [:an_uploaded_indexed_image]

    test "it should exist", ctx do
      assert Storage.S3.exists?(ctx.parent, ctx.indexed_image)
    end

    test "a bogus image doesn't exist", ctx do
      bogus = %{ctx.indexed_image | uri: String.slice(ctx.indexed_image.uri, 0..-2)}
      refute Storage.S3.exists?(ctx.parent, bogus)
    end

    test "it can be deleted", ctx do
      assert :ok = Storage.S3.delete(ctx.parent, ctx.indexed_image)
      refute Storage.S3.exists?(ctx.parent, ctx.indexed_image)
    end

    test "deleting a bogus image is a no-op", ctx do
      bogus = %{ctx.indexed_image | uri: String.slice(ctx.indexed_image.uri, 0..-2)}
      assert :ok = Storage.S3.delete(ctx.parent, bogus)
    end
  end
end
