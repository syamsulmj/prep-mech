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
end
