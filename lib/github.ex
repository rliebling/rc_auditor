defmodule RcAuditor.Github do
  use HTTPoison.Base

  def approvals do
    post "/graphql", approvals_query, [{"Content-Type", "application/json"}]
  end
  def approvals_query do
    """
    {
      repository(owner: "Vendini", name: "ct-api") {
        id
        name
        pullRequest(number: 277) {
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
    |> to_post_struct
    |> Poison.encode!
  end

  defp to_post_struct(query), do: %{"query": query}


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

