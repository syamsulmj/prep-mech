defmodule PrepMechWeb.JobHTML do
  @moduledoc """
  The shopper's working view for a claimed job (`JobController.show`).
  """

  use PrepMechWeb, :html

  embed_templates "job_html/*"

  @doc "Label for the button that advances to the next status, or nil at the end."
  def next_action_label(:accepted), do: "Start shopping"
  def next_action_label(:shopping), do: "Out for delivery"
  def next_action_label(:on_delivery), do: "Mark delivered"
  def next_action_label(_), do: nil

  @doc "True once every line item has been resolved (nothing still pending)."
  def all_resolved?(line_items), do: Enum.all?(line_items, &(&1.pickup_status != :pending))

  def item_state_label(:picked), do: "Picked"
  def item_state_label(:unavailable), do: "Unavailable"
  def item_state_label(:pending), do: "Pending"

  def item_state_class(:picked), do: "text-st-green"
  def item_state_class(:unavailable), do: "text-st-red"
  def item_state_class(:pending), do: "text-ui-text-3"
end
