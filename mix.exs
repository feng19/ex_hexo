defmodule ExHexo.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_hexo,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.5"},
      {:earmark, "~> 1.4"},
      {:makeup, "~> 1.0"},
      {:sitemap, "~> 1.1"},
      {:file_system, "~> 0.2"}
    ]
  end

  defp escript do
    [
      name: "ex-hexo",
      main_module: ExHexo
    ]
  end
end
