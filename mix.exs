defmodule NatsEx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nats_ex,
      version: "0.3.0",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: [extras: ["README.md": [path: "README.md", title: "README"]]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [mod: {NatsEx, []}, extra_applications: [:logger, :crypto, :eex]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.26", only: :dev},
      {:credo, "~> 0.9", only: [:dev, :test]}
    ]
  end

  defp description do
    """
    A pure Elixir Client library for Nats.io messaging system
    """
  end

  defp package do
    [
      name: :nats_ex,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Sarat Chandra <me@saratchandra.in>"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/iamd3vil/nats_ex"
      }
    ]
  end
end
