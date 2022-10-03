defmodule Eakins.MixProject do
  use Mix.Project

  def project do
    [
      app: :eakins,
      version: "0.0.3",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/scohen/eakins",
      aliases: aliases(),
      docs: docs(),
      description: description(),
      package: package()
    ]
  end

  def elixirc_paths(:test), do: ~w(lib test/support)
  def elixirc_paths(_), do: ~w(lib)

  def docs do
    [
      main: "Eakins",
      extras: ["Readme.md"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    ["ecto.reset": ~w(ecto.drop ecto.create ecto.migrate)]
  end

  defp description do
    """
    A library that connects images in your ecto schemas to an image resizing proxy.
    """
  end

  def package do
    [
      name: "eakins",
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/scohen/eakins"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.9.0"},
      {:ecto_sql, "~> 3.9.0"},
      {:ex_aws, "~> 2.4.0", optional: true},
      {:ex_aws_s3, "~> 2.3.0", optional: true},
      {:gettext, "~> 0.20.0"},
      {:inflex, "~> 2.1.0"},
      {:mimerl, "~> 1.2.0"},
      {:plug, "~> 1.13.0"},
      {:ex_doc, "~> 0.28.5", runtime: false, only: :dev},
      {:jason, "~> 1.4.0", optional: true, only: [:test]},
      {:patch, "~> 0.12.0", only: [:test]},
      {:postgrex, "~> 0.16.0", only: [:test]},
      {:stream_data, "~> 0.5.0", only: [:test]}
    ]
  end
end
