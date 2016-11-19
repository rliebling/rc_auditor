defmodule CliTest do
  use ExUnit.Case
  doctest RcAuditor

  import RcAuditor.CLI, only: [parse_args: 1]

  test ":help returned by option parsing with -h and --help options" do
    assert parse_args(["-h",
                       "anything"]) == :help
    assert parse_args(["--help", "anything"]) == :help
  end

  test "two values returned if two given" do
    assert parse_args(["API-1141", "vendini_api"]) == { "API-1141", "vendini_api" }
  end
end


