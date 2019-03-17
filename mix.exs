defmodule Binance.MixProject do
  use Mix.Project

  def project do
    [
      app: :binance,
      version: "0.6.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Binance.Supervisor, []},
      applications: [:exconstructor, :poison, :httpoison],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.0"},
      {:poison, "~> 4.0.0"},
      {:exconstructor, "~> 1.1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
      {:mock, "~> 0.3.3", only: :test},
      {:exvcr, "~> 0.10.1", only: :test}
    ]
  end

  defp description do
    """
    Elixir wrapper for the Binance public API
    """
  end

  defp package do
    [
      name: :binance,
      files: ["lib", "config", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["David Mohl"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/dvcrn/binance.ex"}
    ]
  end
end
