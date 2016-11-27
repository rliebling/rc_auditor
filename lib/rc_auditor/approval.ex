defmodule Approval do
  defstruct stage: "", approver: "", approved_at: nil, link: nil

  def to_md([], label), do: "#{label} | Not found | "
  def to_md(a, label) do
    a
    |> Enum.map(fn a->
      label <> "|" <> a.approver <> "|" <> a.approved_at
    end)
    |> Enum.join("\n")
  end

end
