defmodule Spades.MixProject do
  use Mix.Project

  def project do
    [
      app: :spades,
      version: "0.1.0",
      elixir: "~> 1.17.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Spades.Application, []},
      extra_applications: [:logger, :runtime_tools, :mnesia]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.6.5"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, "~> 0.15"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.18.0"},
      {:phoenix_live_dashboard, "~> 0.5"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:pow, "~> 1.0.19"},
      {:swoosh, "~> 0.25.1"},
      {:hackney, "~> 1.9"},
      {:parent, "~> 0.9.0"},
      {:accessible, "~> 0.2.1"},
      {:ex_check, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 1.4.0", only: :dev, runtime: false},
      {:dialyxir, ">= 1.0.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.setup": ["cmd --cd assets npm install"],
      "assets.build": ["cmd --cd assets npm run build"],
      "assets.deploy": ["cmd --cd assets npm run deploy", "phx.digest"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
