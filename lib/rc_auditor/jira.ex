defmodule RcAuditor.Jira do

  def fetch(key) do
    Jira.API.get!("/rest/api/2/issue/#{key}").body
  end
  def fetch(key, :changelog) do
    Jira.API.get!("/rest/api/2/issue/#{key}?expand=changelog").body
  end

  def child_tickets(%{"fields" => %{"issuelinks" => links}}) do
    links
    |> Stream.filter(&is_child/1)
    |> Stream.map( &key/1)
    |> Stream.map( fn k -> fetch(k, :changelog) end)
  end

  defp qa_approval( %{"changelog" => %{ "histories" => histories}}) do
    h = histories
        |> Enum.filter(fn h->
                         h["items"]
                         |> Enum.any?(&is_qa_approval?/1)
                       end)
        |> Enum.map(fn a-> %Approval{approver: a["author"]["displayName"],
                                     approved_at: a["created"]}
                    end)
  end

  def is_qa_approval?(%{"field"=>"status", "toString"=>"Approved for RC"}) do
    true
  end
  def is_qa_approval?(_), do: false

  def status_name(t) do
    get_in(t, ["fields","status","name"])
  end
  def summary(t) do
    get_in(t, ["fields","summary"])
  end

  def annotate_qa_approval(ticket) do
    Map.put ticket, "qa_approval", qa_approval(ticket)
  end

  defp is_child( %{"type" => %{"inward" => "child of"}, "outwardIssue"=>issue}) do
    true
  end
  defp is_child(_) do
    false
  end

  defp key( %{"outwardIssue" => %{"key" => key}}) do
    key
  end
end
