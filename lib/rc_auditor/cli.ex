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
    child_tix = RcAuditor.Jira.fetch(rc_ticket_id)
    |> RcAuditor.Jira.child_tickets
    |> Enum.filter(fn t-> same_project?(t["key"], rc_ticket_id) end)
    |> Enum.sort(&(ticket_key_number(&1) < ticket_key_number(&2)))

    header(child_tix, rc_ticket_id) <> report(child_tix, repo_owner, repo_name)
    |> Earmark.to_html
    |> IO.puts
  end

  defp header(child_tix, rc_ticket_id) do
    toc = child_tix
    |> Stream.map(fn t -> key=t["key"]; "* [#{key}: #{RcAuditor.Jira.summary(t)}](##{key})" end)
    |> Enum.join("\n")
    "# Audit for ticket #{rc_ticket_id}\n## Table of Contents" <> "\n" <> toc <> "\n---\n"
  end

  defp report(child_tix, repo_owner, repo_name) do
    {:ok, ghmap} = RcAuditor.GithubPRMap.start_link(repo_owner, repo_name)

    child_tix
    |> Stream.map(&RcAuditor.Jira.annotate_developer/1)
    |> Stream.map(&RcAuditor.Jira.annotate_qa_approval/1)
    |> Stream.map(&RcAuditor.Jira.annotate_cr_approval/1)
    |> Stream.map(&(RcAuditor.Github.annotate_pull_request(&1, ghmap)))
    |> Stream.map(&presentation/1)
    |> Enum.join("\n")
  end

  defp same_project?(key1, key2) do
    Regex.run(~r/[A-Z]+-/, key1) == Regex.run(~r/[A-Z]+-/, key2)
  end

  defp ticket_key_number(t) do
    Regex.run(~r/[A-Z]+-([0-9]+)/,t["key"]) |> Enum.at(1) |> String.to_integer
  end



  defp presentation(t) do
    "## " <> t["key"] <> ": " <> RcAuditor.Jira.summary(t)
    ~s'''
## #{t["key"]}: #{RcAuditor.Jira.summary(t)}
{: ##{t["key"]}}

| Action | By    |    At   | Valid? |
| :----  | :---  | :------ | :---:  |
#{Approval.to_md(t["developer"], "Jira Dev")}
#{Approval.to_md(t["cr_approval"], "Jira CR")}
#{Approval.to_md(t["gh_approval"], "Github CR")}
#{Approval.to_md(t["qa_approval"], "QA")}
---
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

