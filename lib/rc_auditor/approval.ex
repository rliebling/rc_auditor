defmodule Approval do
  defstruct stage: "", approver: "", approved_at: nil, link: nil, approved_for: nil

  def to_md([], label), do: "| #{label} | Not found | | | "
  def to_md(a, label) do
    a
    |> Enum.map(fn a->
      "| " <> label <> " | " <> (a.approver || "<none>") <> " | " <> (a.approved_at||"") <> " | " <> valid?(a) <> " |"
    end)
    |> Enum.join("\n")
  end

  def valid?(a) do
    case a.approved_for != nil && a.approver != nil && a.approved_for != a.approver do
      true -> "VALID"
      false -> ""
    end
  end

end
