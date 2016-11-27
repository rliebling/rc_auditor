defmodule RcAuditor.GithubPRMap do
  alias RcAuditor.Github

  @doc """
  """
  def start_link(repo_owner, repo_name) do
    Agent.start_link(fn -> %{
      repo_owner: repo_owner,
      repo_name: repo_name,
      cursor: nil,
      map: %{},
    } end)
  end

  @doc """
  Gets a PR by key
  """
  def get(ghmap, key) do
    Agent.get_and_update(ghmap, &find_with_caching(&1, key))
  end

  defp find_with_caching(state, key) do
    case Map.get(state.map, key) do
      nil -> new_state = fetch_next_page(state, key); find_with_caching(new_state, key)
      cached_result -> {cached_result, state}
    end
  end

  defp fetch_next_page(%{cursor: :halt}=state, key) do
    raise "No more PRs to fetch.  #{key} not found"
  end
  defp fetch_next_page(state, key) do
    IO.puts :stderr, "PRMap: fetching a page cursor=#{inspect(state.cursor)}"
    {prs, new_cursor} = Github.pull_requests(state.repo_owner, state.repo_name, state.cursor)
    new_map = Enum.reduce(prs,
                          state.map,
                          fn pr, map -> 
                            title = pr["title"]
                            case jira_key_from_title(title) do
                              nil -> map
                              key -> Map.put(map, key, pr)
                            end
                          end)
    new_cursor = case new_cursor do
      nil -> :halt
      x -> x
    end
    %{state | map: new_map, cursor: new_cursor}
  end

  def jira_key_from_title(title) do
    case Regex.run(~r/^[A-Z]+-[0-9]+/,title) do
      nil -> nil
      t -> Enum.at(t, 0)
    end
  end
end
