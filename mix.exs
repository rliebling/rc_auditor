defmodule RcAuditor.Mixfile do
  use Mix.Project

  def project do
    [app: :rc_auditor,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison]]
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
      {:jira, git: "https://github.com/jeffweiss/jira", tag: "0.0.8"},
      {:earmark, git: "https://github.com/pragdave/earmark", tag: "v1.0.3"}
    ]
  end
end
