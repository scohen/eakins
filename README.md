# Eakins

Eakins is a library that takes the pain out of image management in Ecto.
It allows you to have pluggable storage backends for your image data and pluggable
front-ends for all your rescaling needs. Currently, it supports storing images in s3
or on the file system, and supports Imgproxy as a serving frontend.

## Installation

Eakins is available in hex, and can be installed
by adding `eakins` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:eakins, "~> 0.0.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/eakins>.


### Naming
Eakins is named after [Thomas Eakins](https://en.wikipedia.org/wiki/Thomas_Eakins),
an American realist painter who painted pretty clouds.
