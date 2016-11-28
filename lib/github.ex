defmodule RcAuditor.Github do
  use HTTPoison.Base

  def approvals(repo_owner, repo_name, pr_number) do
    post "/graphql",
        approvals_query(repo_owner, repo_name, pr_number),
        [{"Content-Type", "application/json"}]
  end

  def approvals_query(repo_owner, repo_name, pr_number) do
    """
    {
      repository(owner: "#{repo_owner}", name: "#{repo_name}") {
        id
        name
        pullRequest(number: #{pr_number}) {
          number
          author {
            id
          }
          body
          reviews(first: 10, states: APPROVED) {
            edges {
              node {
                author {
                  name
                  email
                  login
                }
                bodyText
                submittedAt
                head {
                  oid
                }
              }
            }
          }
        }
      }
    }
    """
    |> graphql_query
  end

  def pr_query(repo_owner, repo_name) do
    """
      query PRs($cursor :String) {
        repository(owner: "#{repo_owner}", name: "#{repo_name}") {
          id
          name
          pullRequests(last: 30, before: $cursor) {
            pageInfo {
              endCursor
              hasNextPage
              hasPreviousPage
              startCursor
            }
            totalCount
            edges{
              node {
                number
                title
                author {
                  name
                  login
                }
                id
                reviews(last: 30, states: APPROVED) {
                  edges {
                    node {
                      author {
                        login
                        name
                      }
                      state
                      head {
                       oid
                      }
                      submittedAt
                      url
                    }
                  }
                }
              }
            }
          }
        }
      }
    """
  end

  def annotate_pull_request(ticket, ghmap) do
    key = ticket["key"]
    pr = RcAuditor.GithubPRMap.get(ghmap, key)
    ticket
    |> Map.put("gh_approval", approval(pr))
    |> Map.put("pr_author", pr_author(pr))
  end

  def pr_author(nil), do: nil
  def pr_author(pr) do
    IO.puts :stderr, "PR_AUTHOR: " <> inspect(pr, pretty: true)
    case get_in(pr, ["author", "name"]) do
      nil -> get_in(pr, ["author", "login"])
      "" -> get_in(pr, ["author", "login"])
      name -> name
    end
  end

  def approval(nil), do: [%Approval{}]
  def approval(pr) do
    # merged_sha = pr["headRef"]["target"]["oid"]
    # IO.puts :stderr, "Merged sha=#{merged_sha} #{inspect(pr, pretty: true)}"
    # IO.puts :stderr, "APPROVAL: " <> pr["title"] <> inspect(pr["reviews"])
    pr["reviews"]["edges"]
    # |> Stream.map(fn rvw -> IO.puts(:stderr, "RVW:" <> inspect(rvw, pretty: true)); rvw end)
    |> Stream.map(fn node -> node["node"] end)
    # |> Stream.filter(fn rvw -> rvw["head"]["oid"]==merged_sha end)
    |> Stream.map(fn rvw -> %Approval{stage: "GH",
                              approver: get_in(rvw, ["author", "name"]) || get_in(rvw, ["author", "login"]),
                              approved_at: rvw["submittedAt"],
                              approved_for: pr_author(pr),
                              link: rvw["url"]}
                  end)
    |> Enum.to_list
  end

  def pull_requests(repo_owner, repo_name, cursor) do
    vars = pr_vars(repo_owner, repo_name, cursor)
    query = pr_query(repo_owner, repo_name)
    raw = graphql_query( query, vars).body
    IO.puts :stderr, inspect(raw, pretty: true)
    page = raw["data"]
    new_cursor = page["repository"]["pullRequests"]["pageInfo"]["startCursor"]

    prs = Enum.map(page["repository"]["pullRequests"]["edges"],&(&1["node"]))
    {prs, new_cursor}
  end

  def pr_vars(repo_owner, repo_name, nil),do: %{repo_owner: repo_owner, repo_name: repo_name}
  def pr_vars(repo_owner, repo_name, cursor),do: %{repo_owner: repo_owner, repo_name: repo_name, cursor: cursor}

  def graphql_query(query, vars \\ nil) do
    post_body = query |> to_post_struct(vars) |> Poison.encode!
    post!("/graphql", post_body, [{"Content-Type", "application/json"}])
  end

  defp to_post_struct(query, nil), do: %{"query": query}
  defp to_post_struct(query, vars), do: %{"query": query, "variables": vars}


  ### HTTPoison stuff
  defp config_or_env(key, env_var) do
    Application.get_env(:github, key, System.get_env(env_var))
  end

  defp token do
    config_or_env(:token, "GITHUB_TOKEN")
  end

  ### HTTPoison.Base callbacks
  def process_url(url) do
    "https://api.github.com" <> url
  end

  def process_response_body(body) do
    body
    |> decode_body
  end

  def process_request_headers(headers) do
    [{"authorization", authorization_header}|headers]
  end

  defp decode_body(""), do: ""
  defp decode_body(body), do: body |> Poison.decode!

  ### Internal Helpers
  def authorization_header do
    "bearer #{token}"
  end
end

