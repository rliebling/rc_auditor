# RcAuditor

**TODO: Add description**


## Instructions
```
export JIRA_USERNAME=rliebling@vendini.com
export JIRA_PASSWORD=XXXXXXXXX
export JIRA_HOST=https://vendini.atlassian.net

# need to setup a token in github (for individual https://github.com/settings/tokens)
# I think it needs 'repo' access and maybe also admin:org access - only needs ReadOnly
export GITHUB_TOKEN=XXXXXXXXXXXXXXXXXX

 mix run -e 'RcAuditor.CLI.run(["API-1263", "Vendini", "vendini-api"])'
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `rc_auditor` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:rc_auditor, "~> 0.1.0"}]
    end
    ```

  2. Ensure `rc_auditor` is started before your application:

    ```elixir
    def application do
      [applications: [:rc_auditor]]
    end
    ```

