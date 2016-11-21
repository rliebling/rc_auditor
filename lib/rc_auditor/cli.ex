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
    usage: rc_auditor <rc_ticket_id> <project>
    """
    System.halt(0)
  end
  def process({rc_ticket_id, project}) do
    RcAuditor.Jira.fetch(rc_ticket_id)
    |> RcAuditor.Jira.child_tickets
    |> Stream.map(&RcAuditor.Jira.annotate_qa_approval/1)
    |> Stream.map( fn t -> [t["key"], t["qa_approval"], RcAuditor.Jira.status_name(t), RcAuditor.Jira.summary(t)] end)
    |> Enum.to_list
    |> inspect(pretty: true)
    |> IO.puts
  end

  @doc """
  `argv` can be -h or --help, which returns :help.
  Otherwise it is a Jira ticket ID, project name
  Return a tuple of `{ ticket_id, project }`, or `:help` if help was given.
  """
  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [ help: :boolean],
                               aliases: [ h:
                                          :help
                                        ])
    case parse do
      { [ help: true ], _, _ }
        -> :help
      { _, [ ticket_id, project ], _ }
        -> { ticket_id, project }
      _ -> :help
    end
  end
end

