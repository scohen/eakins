defmodule Eakins.Schema do
  @moduledoc """
  A schema extension that allows you to attach images to a model.

  To use this extension, your schema must define an integer
  field called `:version` and a map field. The map field's name
  should be the same as the image map or image list that you will define.

  To configure this module, just `use` it below your usage of `Eakins.Schema`.
  Then, define eith an `image_map` or `image_list` in your schema.

  ```
  defmodule Myapp.User do
    use Ecto.Schema
    use Eakins.Schema
    schema "users" do
      field :first_name, :string
      field :last_name, :string
      image_map :avatars
    end
  end
  ```

  The previous incantation will define an image map and associate with the `images` field.
  The name of the image list or the image map should be plural, as the functions that are
  generated make use of this name to provide access to the entire list (the plural functions)
  or a single image (the singular functions).

  # Image Maps

  An image map is an unordered collection of named images. Eakins in this collection can
  be added, removed or accessed by their name. Similarly, you can use the generated functions
  to retrieve a displayable instance at any aspect ratio or size. If the name of the image map is
  `images`, the following functions are generated:

    * `display_image/4` - Returns a displayable instance of the named image
    * `display_images/3` - Returns all images associated with this model. The return values are displayable.
    * `find_image/2` - Finds the image with the given name
    * `delete_image/2` - Deletes the image with the given name
    * `has_image?/2` - Returns true if there is an image with the given name
    * `put_image/3` - Sets the image with the given name, replacing any existing image.
    * `find_image/2` - Finds the image on this model with the given name. The returned image is not displayable

  # Image Lists

  An image list is an ordered list of images,.
  Images in an image list are able to be retrieved, deleted and added by index

  If the name of the image list is `images`, the following functions are generated:

    * `display_image/4` - Returns a displayable image with the given index or nil if one doesn't exist.
    * `display_images/3` - Returns all images in the image list at the given aspect ratio and height.
    * `find_image/2` - Returns the image with the given index, if it exists and nil otherwise.
    * `delete_image_at/2` - When applied to a changeset, deletes the image with the given index.
    * `replace_image_at/3` - Sets the image with the given index on this image list. This will replace any image with the same index.
    * `insert_image_at/3` - Inserts an image into the image list at the specified index. This will grow the list
    * `image_at`/2 - Finds the image in this image list with the given index. The returned image is not displayable.

  # Generated functions
  Adding an image list or an image map to your model creates adds helper functions that let you
  modify the image containers as well as functions that generate images suitable for display.
  The generated functions are fully documented and have proper typespecs.

  # Saving new images
  To create a new image from a `Plug.Upload`, pass it in the image argument to one of the generated put functions.
  The image will be saved to backend storage during the attached model's update.

  for example
  ```
    def save_avatar(%User{} = user, %Plug.Upload{} = image) do
      user
      |> User.changeset(%{})
      |> User.put_image(:avatar, image)
      |> Repo.update()
    end
  ```
  If the function completes correctly, the image will be persisted in the configured storage.
  # Deleting old images

  Old images must be deleted after the transaction completes, as we can't be guaranteed that the
  model will be saved correctly. To delete old images, use an Ecto.Multi

  ```
    def replace_avatar(%User{} = user, %Plug.Upload{} = avatar) do
      old_image = User.find_image(user, :avatar)
      changeset = user
        |> User.changeset(%{})
        |> User.put_image(:avatar, avatar)
      Multi.new()
      |> Multi.update(:update_user, changeset)
      |> Multi.run(:delete_old_image, fn _, _ ->
        case Eakins.Storage.delete(user, old_image) do
          :ok -> {:ok, old_image}
          error -> error
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{update_user: user}} ->
          {:ok, user}

        {: error, _failed_op, failed_value, _} ->
          {:error, failed_value}
      end
  ```
  """

  require Ecto.Schema
  alias Eakins.Image

  defmacro __using__(_) do
    quote location: :keep do
      import unquote(__MODULE__), only: [image_map: 1, image_list: 1]
      alias Eakins.Storage
      alias Eakins.Image.Stored
      @type t :: Ecto.Schema.t()
      Module.register_attribute(__MODULE__, :image_maps, accumulate: true)
      Module.register_attribute(__MODULE__, :image_lists, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro image_map(name) do
    quote location: :keep do
      @image_maps unquote(name)
      Ecto.Schema.embeds_many(unquote(name), Image.Stored, on_replace: :delete)

      if Module.get_attribute(__MODULE__, :needs_version?, true) do
        Ecto.Schema.field(:version, :integer, default: 0)
      end

      @needs_version? false
    end
  end

  defmacro image_list(name) do
    quote location: :keep do
      @image_lists unquote(name)
      Ecto.Schema.embeds_many(unquote(name), Image.Stored, on_replace: :delete)

      if Module.get_attribute(__MODULE__, :needs_version?, true) do
        Ecto.Schema.field(:version, :integer, default: 0)
      end

      @needs_version? false
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  @spec __before_compile__(atom | %{:module => atom, optional(any) => any}) ::
          {:__block__, [], maybe_improper_list}
  defmacro __before_compile__(env) do
    image_map_fns =
      for image_map_name <- Module.get_attribute(env.module, :image_maps, []) do
        image_map_functions(image_map_name, env)
      end

    image_list_fns =
      for image_list_name <- Module.get_attribute(env.module, :image_lists, []) do
        image_list_functions(image_list_name, env)
      end

    quote do
      unquote_splicing(image_map_fns)
      unquote_splicing(image_list_fns)

      defp to_integer(i) when is_integer(i), do: i
      defp to_integer(s) when is_binary(s), do: String.to_integer(s)

      defp reindex_list_images(images) do
        images
        |> Enum.with_index()
        |> Enum.map(fn {image, index} -> Map.put(image, :key, to_string(index)) end)
      end

      defp store_added_list_image(changeset, image_list_name, added_image) do
        case Eakins.Storage.store(changeset.data, added_image) do
          {:ok, saved_image} ->
            {_, images} = fetch_field(changeset, image_list_name)

            images =
              images
              |> Enum.reduce([], fn
                ^added_image, acc ->
                  [saved_image | acc]

                other_image, acc ->
                  [other_image | acc]
              end)
              |> Enum.reverse()
              |> reindex_list_images()

            changeset
            |> put_embed(image_list_name, images)

          {:error, reason} ->
            add_error(changeset, image_list_name, to_string(reason))
        end
      end

      def store_added_map_image(changeset, image_map_name, added_image) do
        case Eakins.Storage.store(changeset.data, added_image) do
          {:ok, saved_image} ->
            image_name = saved_image.key

            # replace the uploaded image with the saved instance
            {_, images} = fetch_field(changeset, image_map_name)

            images =
              images
              |> Enum.reduce([], fn
                %{key: ^image_name}, acc ->
                  [saved_image | acc]

                other_image, acc ->
                  [other_image | acc]
              end)
              |> Enum.reverse()

            put_embed(changeset, image_map_name, images)

          {:error, reason} ->
            add_error(changeset, image_map_name, to_string(reason))
        end
      end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp image_map_functions(image_map_name, env) do
    image_map_singular = image_map_name |> Inflex.singularize() |> String.to_atom()
    default_fn_name = :"default_#{image_map_singular}"
    delete_fn_name = :"delete_#{image_map_singular}"
    display_one_fn_name = :"display_#{image_map_singular}"
    display_many_fn_name = :"display_#{image_map_name}"
    find_fn_name = :"find_#{image_map_singular}"
    has_fn_name = :"has_#{image_map_singular}?"
    put_fn_name = :"put_#{image_map_singular}"
    remove_from_storage_fn_name = :"remove_#{image_map_singular}_from_storage"

    default_image_fn =
      unless Module.defines?(env.module, {default_fn_name, 4}) do
        quote do
          def unquote(default_fn_name)(_, _, _, _) do
            nil
          end
        end
      end

    quote location: :keep do
      alias Ecto.Changeset
      import Changeset

      unquote(default_image_fn)

      def image_container_type(unquote(image_map_name)) do
        :map
      end

      def image_container_type(unquote(to_string(image_map_name))) do
        image_container_type(unquote(image_map_name))
      end

      @doc """
      Removes an image from the underlying storage
      """
      @spec unquote(remove_from_storage_fn_name)(schema :: t, iamge :: Image.Stored.t() | nil) ::
              :ok | {:error, any}
      def unquote(remove_from_storage_fn_name)(%__MODULE__{} = schema, image) do
        Eakins.Storage.delete(schema, image)
      end

      @doc """
      Adds an image to the `#{unquote(image_map_name)}` map changeset
      """

      @spec unquote(put_fn_name)(Changeset.t(), Eakins.name(), Plug.Upload.t()) :: Changeset.t()
      def unquote(put_fn_name)(changeset, image_key, %Plug.Upload{} = uploaded_image) do
        image_key = to_string(image_key)
        image = Image.Stored.from_upload(uploaded_image, image_key)
        unquote(put_fn_name)(changeset, image)
      end

      @spec unquote(put_fn_name)(Changeset.t(), Image.Stored.t()) :: Changeset.t()
      def unquote(put_fn_name)(changeset, %Image.Stored{} = image) do
        image_key = to_string(image.key)

        {replaced_images, images} =
          changeset
          |> fetch_field(unquote(image_map_name))
          |> elem(1)
          |> Enum.split_with(fn %{key: key} -> to_string(key) == image_key end)

        changeset
        |> put_embed(unquote(image_map_name), [image | images])
        |> prepare_changes(&store_added_map_image(&1, unquote(image_map_name), image))
        |> optimistic_lock(:version)
      end

      @doc """
      Deletes the named image from the `#{unquote(image_map_name)}` map
      """
      @spec unquote(delete_fn_name)(Changeset.t(), Eakins.key()) :: Changeset.t()
      def unquote(delete_fn_name)(changeset, image_name) do
        image_name = to_string(image_name)

        {deleted_image, kept_images} =
          changeset
          |> apply_changes()
          |> Map.get(unquote(image_map_name), [])
          |> Enum.split_with(fn %{key: key} -> to_string(key) == image_name end)

        changeset
        |> put_embed(unquote(image_map_name), kept_images)
        |> prepare_changes(fn changeset ->
          deleted_image = List.first(deleted_image)

          case unquote(remove_from_storage_fn_name)(changeset.data, deleted_image) do
            :ok ->
              put_embed(changeset, unquote(image_map_name), kept_images)

            {:error, reason} ->
              add_error(changeset, unquote(image_map_name), to_string(reason))
          end
        end)
        |> optimistic_lock(:version)
      end

      @doc """
      Returns whether or not the `#{unquote(image_map_name)}` map contains an image with the given name.
      """
      @spec unquote(has_fn_name)(schema :: t, Eakins.name()) :: boolean
      def unquote(has_fn_name)(%__MODULE__{} = schema, image_name) do
        unquote(find_fn_name)(schema, image_name) != nil
      end

      @doc """
       Retrieves the named image from the `#{unquote(image_map_name)}` map ready do display
       at the given aspect ratio and height
      """
      @spec unquote(display_one_fn_name)(
              schema :: t,
              name :: Eakins.name(),
              Eakins.aspect(),
              Eakins.size()
            ) ::
              Image.Display.t() | nil
      def unquote(display_one_fn_name)(%__MODULE__{} = schema, name, aspect, height) do
        image = unquote(find_fn_name)(schema, name)

        {scaled_instance, default?} =
          case image do
            %Image.Stored{} = image ->
              {image, false}

            nil ->
              {unquote(default_fn_name)(schema, to_string(name), aspect, height), true}
          end

        if is_map(scaled_instance) do
          scaled_instance
          |> Image.Display.new(aspect, height)
          |> Map.put(:default?, default?)
        end
      end

      @doc """
       Returns all images in the `#{unquote(image_map_name)}` map ready do display
       at the given aspect ratio and height
      """
      @spec unquote(display_many_fn_name)(schema :: t, aspect :: Eakins.aspect(), Eakins.size()) ::
              [Image.Display.t()]
      def unquote(display_many_fn_name)(%__MODULE__{} = schema, aspect, height) do
        schema
        |> Map.get(unquote(image_map_name), [])
        |> Enum.map(&Image.Display.new(&1, aspect, height))
      end

      @doc """
      Finds a given image by name
      This image is the original image uploaded by the user, and is not suitable for display
      """
      @spec unquote(find_fn_name)(schema :: t, Eakins.name()) :: Image.Stored.t() | nil
      def unquote(find_fn_name)(%__MODULE__{} = schema, name) do
        name = to_string(name)

        schema
        |> Map.get(unquote(image_map_name), [])
        |> Enum.find(fn %{key: key} -> to_string(key) == name end)
      end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp image_list_functions(image_list_name, env) do
    image_list_singular = image_list_name |> Inflex.singularize() |> String.to_atom()
    add_fn_name = :"add_#{image_list_singular}"
    replace_fn_name = :"replace_#{image_list_singular}_at"
    insert_fn_name = :"insert_#{image_list_singular}_at"
    delete_fn_name = :"delete_#{image_list_singular}_at"
    default_fn_name = :"default_#{image_list_singular}"
    display_many_fn_name = :"display_#{image_list_name}"
    display_one_fn_name = :"display_#{image_list_singular}"
    find_fn_name = :"#{image_list_singular}_at"
    remove_from_storage_fn_name = :"remove_#{image_list_singular}_from_storage"

    default_fn =
      unless Module.defines?(env.module, {default_fn_name, 4}) do
        quote do
          def unquote(default_fn_name)(_, _, _, _) do
            nil
          end
        end
      end

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote location: :keep do
      alias Ecto.Changeset
      alias Eakins

      import Changeset

      unquote(default_fn)

      def image_container_type(unquote(image_list_name)) do
        :list
      end

      def image_container_type(unquote(to_string(image_list_name))) do
        image_container_type(unquote(image_list_name))
      end

      @doc """
      Removes the image from its underlying storage mechanism
      """
      @spec unquote(remove_from_storage_fn_name)(schema :: t, image :: Image.Stored.t() | nil) ::
              :ok | {:error, term}
      def unquote(remove_from_storage_fn_name)(%__MODULE__{} = schema, image) do
        Eakins.Storage.delete(schema, image)
      end

      @doc """
      Adds an image to the end of the `#{unquote(image_list_name)}` image list
      """
      @spec unquote(add_fn_name)(Changeset.t(), Plug.Upload.t() | Image.Stored.t()) ::
              Changeset.t()

      def unquote(add_fn_name)(changeset, %Image.Stored{} = image) do
        unquote(insert_fn_name)(changeset, -1, image)
      end

      def unquote(add_fn_name)(changeset, %Plug.Upload{} = upload) do
        image = Image.Stored.from_upload(upload, nil)
        unquote(insert_fn_name)(changeset, -1, image)
      end

      @spec unquote(replace_fn_name)(Changeset.t(), pos_integer, Plug.Upload.t()) :: Changeset.t()
      def unquote(replace_fn_name)(changeset, index, %Plug.Upload{} = upload) do
        image = Image.Stored.from_upload(upload, index)
        unquote(replace_fn_name)(changeset, index, image)
      end

      @doc """
      Replaces the image in the `#{unquote(image_list_name)}`at `index` with the given image.
      """
      @spec unquote(replace_fn_name)(Changeset.t(), pos_integer, Image.Stored.t()) ::
              Changeset.t()
      def unquote(replace_fn_name)(changeset, index, %Image.Stored{} = image) do
        index_integer = to_integer(index)

        image = %{image | key: to_string(image.key)}

        {_, changeset_images} = fetch_field(changeset, unquote(image_list_name))
        images = List.replace_at(changeset_images, index_integer, image)

        changeset
        |> put_embed(unquote(image_list_name), images)
        |> prepare_changes(&store_added_list_image(&1, unquote(image_list_name), image))
        |> optimistic_lock(:version)
      end

      @doc """
      Replaces the image in the `#{unquote(image_list_name)}`at `index` with the given image.
      """
      @spec unquote(insert_fn_name)(Changeset.t(), integer, Image.Stored.t()) :: Changeset.t()
      def unquote(insert_fn_name)(changeset, index, %Image.Stored{} = image) do
        index_integer = to_integer(index)

        {_, images} = fetch_field(changeset, unquote(image_list_name))
        images = List.insert_at(images, index_integer, image)

        changeset
        |> put_embed(unquote(image_list_name), images)
        |> prepare_changes(&store_added_list_image(&1, unquote(image_list_name), image))
        |> optimistic_lock(:version)
      end

      @doc """
      Deletes the image with the given index from the `#{unquote(image_list_name)}` list
      """
      @spec unquote(delete_fn_name)(Changeset.t(), Eakins.key()) :: Changeset.t()
      def unquote(delete_fn_name)(changeset, image_index) do
        image_index = to_integer(image_index)

        {_, images} = fetch_field(changeset, unquote(image_list_name))

        {deleted_image, kept_images} = List.pop_at(images, image_index)

        changeset
        |> put_embed(unquote(image_list_name), kept_images)
        |> prepare_changes(fn changeset ->
          case unquote(remove_from_storage_fn_name)(changeset.data, deleted_image) do
            :ok ->
              kept_images = reindex_list_images(kept_images)
              put_embed(changeset, unquote(image_list_name), kept_images)

            {:error, reason} ->
              add_error(changeset, unquote(image_list_name), to_string(reason))
          end
        end)
        |> optimistic_lock(:version)
      end

      @doc """
      Retrieves the image with the given index from the `#{unquote(image_list_name)}` images list. The image is
      ready for diplay at the given aspect ratio and height.

      If there is no image with this index, and the `#{unquote(default_fn_name)}/2` exists, its result is returned. If
      the function doesn't exist, nil is retuned.
      """
      @spec unquote(display_one_fn_name)(
              schema :: t,
              Eakins.key(),
              Eakins.aspect(),
              Eakins.size()
            ) ::
              Image.Display.t() | nil
      def unquote(display_one_fn_name)(%__MODULE__{} = schema, index, aspect, height) do
        index = to_integer(index)

        {found_image, default?} =
          schema
          |> Map.get(unquote(image_list_name), [])
          |> Enum.find(fn %{key: key} -> to_integer(key) == index end)
          |> case do
            %Image.Stored{} = image ->
              {image, false}

            nil ->
              {unquote(default_fn_name)(schema, index, aspect, height), true}
          end

        if is_map(found_image) do
          found_image
          |> Image.Display.new(aspect, height)
          |> Map.put(:default?, default?)
        end
      end

      @doc """
       Returns all images in the `#{unquote(image_list_name)}` list ready do display
       at the given aspect ratio and height
      """
      @spec unquote(display_many_fn_name)(schema :: t, aspect :: Eakins.aspect(), Eakins.size()) ::
              [
                Image.Display.t()
              ]
      def unquote(display_many_fn_name)(%__MODULE__{} = schema, aspect, height) do
        schema
        |> Map.get(unquote(image_list_name), [])
        |> Enum.map(&Image.Display.new(&1, aspect, height))
      end

      @doc """
      Finds a given image by index
      This image is the original image uploaded by the user, and is not suitable for display
      """
      @spec unquote(find_fn_name)(schema :: t, Eakins.index()) :: Image.Stored.t() | nil
      def unquote(find_fn_name)(%__MODULE__{} = schema, index) do
        index = to_integer(index)

        schema
        |> Map.get(unquote(image_list_name), [])
        |> Enum.find(fn %{key: key} -> to_integer(key) == index end)
      end
    end
  end
end
