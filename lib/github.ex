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

  def pr_cursor(repo_owner, repo_name) do
    q = """
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
                }
              }
            }
          }
        }
        """
    pr_items = fn page -> page["repository"]["pullRequests"]["edges"] end
    new_vars_fn = fn 
      nil, _ -> nil
      page, _ -> case page["repository"]["pullRequests"]["pageInfo"]["startCursor"] do
                   nil -> nil
                   x -> %{cursor: x}
                 end
    end
    cursor = 
      %{vars: nil,
        query: q,
        items_fn: pr_items,
        new_vars: new_vars_fn 
      }
  end

  def pull_requests(repo_owner, repo_name) do
    Stream.resource(
                    fn -> fetch_with_cursor(pr_cursor(repo_owner,repo_name)) end,
                    &process_items/1,
                    fn _ -> nil end
                )
  end

  defp process_items({nil, %{vars: nil}}), do: {:halt, nil}
  defp process_items({nil, cursor}) do
    fetch_with_cursor(cursor) |> process_items
  end
  defp process_items({items, cursor}) do
    {items, {nil, cursor}}
  end


  defp fetch_with_cursor(cursor) do
    page = graphql_query( cursor.query, cursor.vars).body["data"]
    new_cursor = %{cursor | vars: cursor.new_vars.(page, cursor.vars) }
    IO.puts "OLD: " <> inspect(cursor)
    IO.puts "NEW: " <> inspect(new_cursor)
    IO.puts "NEW: " <> inspect(page["repository"]["pullRequests"]["pageInfo"])
    { cursor.items_fn.(page), new_cursor }
  end

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

