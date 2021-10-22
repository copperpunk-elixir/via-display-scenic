defmodule ViaDisplayScenic.MixProject do
  use Mix.Project
  @version "0.1.1"

  @all_targets [:rpi, :rpi0, :rpi3, :rpi3a, :rpi4]
  def project do
    [
      app: :via_display_scenic,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:via_utils, path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/via-utils"},
      {:via_navigation, path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/via-navigation"},

      # Scenic dependencies
      {:scenic, "~> 0.10.5"},
      {:scenic_driver_glfw, "~> 0.10.1", targets: :host},
      {:scenic_driver_nerves_rpi, "0.10.0", targets: @all_targets},
      {:scenic_driver_nerves_touch, "0.10.0", targets: @all_targets},
      {:scenic_sensor, "~> 0.7"}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
