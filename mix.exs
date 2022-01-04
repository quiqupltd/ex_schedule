defmodule ExSchedule.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_schedule,
      version: "0.2.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ExSchedule",
      package: package(),
      description: description(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
      {:excoveralls, "~> 0.8", only: :test}
    ]
  end

  defp description, do: "Library to run tasks in an interval basis"

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", ".formatter.exs"],
      maintainers: ["Dimitris Zorbas", "Luiz Varela"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/quiqupltd/ex_schedule"}

    ]
  end
end
