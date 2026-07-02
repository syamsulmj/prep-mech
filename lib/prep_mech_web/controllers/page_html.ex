defmodule PrepMechWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PrepMechWeb, :html

  embed_templates "page_html/*"

  @doc "The dashboard tiles, in lifecycle order: {status, label}."
  def status_tiles() do
    [
      pending: "Pending",
      accepted: "Accepted",
      shopping: "Shopping",
      on_delivery: "Out for delivery",
      delivered: "Delivered"
    ]
  end

  def tile_color(:pending), do: "text-st-amber"
  def tile_color(:accepted), do: "text-st-cyan"
  def tile_color(:shopping), do: "text-st-violet"
  def tile_color(:on_delivery), do: "text-st-blue"
  def tile_color(:delivered), do: "text-st-green"

  @doc "A short relative time like \"just now\", \"5 min ago\", \"2 hr ago\", \"3 days ago\"."
  def time_ago(%NaiveDateTime{} = at) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), at, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86_400 -> "#{div(diff, 3600)} hr ago"
      true -> "#{div(diff, 86_400)} #{pluralize(div(diff, 86_400), "day")} ago"
    end
  end

  @doc "True when `at` is within `minutes` (default 10) of now — used for the \"New\" badge."
  def recent?(at, minutes \\ 10)

  def recent?(%NaiveDateTime{} = at, minutes) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), at, :second) < minutes * 60
  end

  defp pluralize(1, word), do: word
  defp pluralize(_n, word), do: word <> "s"
end
