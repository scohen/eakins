defmodule Eakins.ImageSizesTest do
  use Eakins.DataCase
  use ExUnitProperties

  alias Eakins.Image

  describe "apply_aspect_ratio/2" do
    test "square ratio" do
      check all(height <- StreamData.positive_integer()) do
        assert Image.apply_aspect_ratio(:square, height) == {height, height}
      end
    end

    test "original ratio" do
      check all(height <- StreamData.positive_integer()) do
        assert Image.apply_aspect_ratio(:original, height) == {0, height}
      end
    end

    test "custom ratio" do
      assert Image.apply_aspect_ratio({1, 1}, 100) == {100, 100}
      assert Image.apply_aspect_ratio({1, 2}, 100) == {50, 100}
      assert Image.apply_aspect_ratio({2, 2}, 100) == {100, 100}
      assert Image.apply_aspect_ratio({1, 3}, 100) == {33, 100}
      assert Image.apply_aspect_ratio({2, 3}, 100) == {67, 100}
      assert Image.apply_aspect_ratio({3, 3}, 100) == {100, 100}
      assert Image.apply_aspect_ratio({1, 4}, 100) == {25, 100}
    end
  end
end
