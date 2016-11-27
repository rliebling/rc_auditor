defmodule RcAuditor.CLI do
  @moduledoc """
  Handle the command line parsing and the dispatch to
  the various functions that end up
  auditing an RC in Jira and Github
  """
  def run(argv) do
    parse_args(argv)
    |> process
  end

  def process(:help) do
    IO.puts """
    usage: rc_auditor <rc_ticket_id> <repo_owner> <repo_name>
    """
    System.halt(0)
  end
  def process({rc_ticket_id, repo_owner, repo_name}) do
    {:ok, ghmap} = RcAuditor.GithubPRMap.start_link(repo_owner, repo_name)
    RcAuditor.Jira.fetch(rc_ticket_id)
    |> RcAuditor.Jira.child_tickets
#|> Stream.map(fn t->IO.puts(:stderr, t["key"]); t end)
    |> Stream.filter(fn t-> same_project?(t["key"], rc_ticket_id) end)
    |> Stream.map(&RcAuditor.Jira.annotate_qa_approval/1)
    |> Stream.map(&RcAuditor.Jira.annotate_cr_approval/1)
    |> Stream.map(&(RcAuditor.Github.annotate_pull_request(&1, ghmap)))
    |> Stream.map(&presentation/1)
    |> Enum.join("\n")
    |> IO.puts
  end

  defp same_project?(key1, key2) do
    Regex.run(~r/[A-Z]+-/, key1) == Regex.run(~r/[A-Z]+-/, key2)
  end

### API-1211 Patron ID must be unique, cannot edit patron info
#Review Type | Reviewed By | Reviewed At|
#:------| :----|:-----------:|:------------|-----------:|
#Code/J| Andrea Sprega| 2016-11-10T03:45:12.366-0800
#QA/J        | Giuseppe Bruno| 2016-11-10T06:21:29.020-0800
  defp presentation(t) do
    "## " <> t["key"] <> ": " <> RcAuditor.Jira.summary(t)
    ~s'''
## #{t["key"]}: #{RcAuditor.Jira.summary(t)}
Review Type | Reviewed By | Reviewed At|
:------| :----|:-----------:|:------------|-----------:|
#{Approval.to_md(t["cr_approval"], "Code/J")}
#{Approval.to_md(t["gh_approval"], "Code/GH")}
#{Approval.to_md(t["qa_approval"], "QA")}
  '''
  end


  @doc """
  `argv` can be -h or --help, which returns :help.
  Otherwise it is a Jira ticket ID, repo_owner, repo_name
  Return a tuple of `{ ticket_id, repo_owner, repo_name }`, or `:help` if help was given.
  """
  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [ help: :boolean],
                               aliases: [ h:
                                          :help
                                        ])
    case parse do
      { [ help: true ], _, _ }
        -> :help
      { _, [ ticket_id, repo_owner, repo_name ], _ }
        -> { ticket_id, repo_owner, repo_name }
      _ -> :help
    end
  end
end

