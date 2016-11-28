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

  defp approval( %{"changelog" => %{ "histories" => histories}}=ticket, label, filter) do
    histories
    |> Enum.filter(fn h->
                     h["items"]
                     |> Enum.any?(filter)
                   end)
    |> Enum.map(fn a-> %Approval{stage: label,
                                 approver: a["author"]["displayName"],
                                 approved_at: a["created"],
                                 approved_for: developer(ticket)}
                end)
  end

  def developer(%{"changelog" => %{ "histories" => histories}}) do
    histories
    |> Enum.filter(fn h->
                     h["items"]
                     |> Enum.any?(&submitted_to_code_review?/1)
                   end)
    |> Enum.map(fn d -> get_in(d, ["author", "displayName"]) end)
    |> Enum.at(-1)
  end

  def submitted_to_code_review?(%{"field"=>"status", "toString"=>"In Code Review"}) do
    true
  end
  def submitted_to_code_review?(_), do: false

  def is_qa_approval?(%{"field"=>"status", "toString"=>"Approved for RC"}) do
    true
  end
  def is_qa_approval?(_), do: false
  def is_cr_approval?(%{"field"=>"status", "toString"=>"Ready for QA"}) do
    true
  end
  def is_cr_approval?(_), do: false

  def status_name(t) do
    get_in(t, ["fields","status","name"])
  end
  def summary(t) do
    get_in(t, ["fields","summary"])
  end

  def annotate_developer(ticket) do
    Map.put ticket, "developer", approval(ticket, "Dev", &submitted_to_code_review?/1)
  end
  def annotate_qa_approval(ticket) do
    Map.put ticket, "qa_approval", approval(ticket, "QA", &is_qa_approval?/1)
  end

  def annotate_cr_approval(ticket) do
    Map.put ticket, "cr_approval", approval(ticket, "CR", &is_cr_approval?/1)
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
