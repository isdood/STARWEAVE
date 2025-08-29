defmodule StarweaveWeb.MarkdownHelper do
  @moduledoc """
  Helper module for rendering Markdown content to HTML.
  """
  
  @doc """
  Renders Markdown text to HTML.
  
  ## Examples
      iex> render_markdown("**Hello**")
      {:safe, "<p><strong>Hello</strong></p>\n"}
  """
  def render_markdown(markdown) when is_binary(markdown) do
    markdown
    |> Earmark.as_html!()
    |> Phoenix.HTML.raw()
  end
  
  def render_markdown(nil), do: ""
  def render_markdown(other), do: to_string(other)
end
