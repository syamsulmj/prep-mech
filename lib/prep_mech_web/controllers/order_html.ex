defmodule PrepMechWeb.OrderHTML do
  @moduledoc """
  HTML views for the customer order flow (index, new, show) plus the small
  interior components they share: the status chip, a themed input, and the
  lifecycle stepper helpers.
  """

  use PrepMechWeb, :html

  embed_templates "order_html/*"

  @lifecycle [:pending, :accepted, :shopping, :on_delivery, :delivered]

  # ---------- themed input ----------

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :rest, :global, include: ~w(placeholder required autocomplete)

  def ui_input(assigns) do
    ~H"""
    <div>
      <label for={@field.id} class="mb-1.5 block text-sm text-ui-text-2">{@label}</label>
      <input
        type={@type}
        name={@field.name}
        id={@field.id}
        value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
        class="ui-input"
        {@rest}
      />
      <p :for={msg <- Enum.map(@field.errors, &translate_error/1)} class="mt-1 text-xs text-st-red">
        {msg}
      </p>
    </div>
    """
  end

  # ---------- line-item form row ----------

  @doc """
  One editable line-item row (name + quantity + remove).

  Used both for the initial row in the form and inside the `<template>` the JS
  clones — rendering from one component keeps them identical, so the field
  names never drift. `sync()` in app.js renumbers `index` on the client;
  Plug needs `line_items[0][name]`, `line_items[1][name]` (indexed) — a bare
  `line_items[][name]` collapses every row into one.
  """
  attr :index, :integer, required: true

  def line_item_row(assigns) do
    ~H"""
    <div class="line-item grid grid-cols-[1fr_64px_36px] gap-2">
      <input
        type="text"
        name={"order[line_items][#{@index}][name]"}
        placeholder="Item name"
        class="ui-input li-name"
      />
      <input
        type="number"
        name={"order[line_items][#{@index}][quantity]"}
        value="1"
        min="1"
        class="ui-input text-center li-qty"
        aria-label="Quantity"
      />
      <button
        type="button"
        class="remove-item grid place-items-center rounded-md border border-ui-line-soft text-ui-text-3 hover:text-ui-text"
        aria-label="Remove item"
      >
        &times;
      </button>
    </div>
    """
  end

  # ---------- lifecycle stepper ----------

  @doc "The ordered lifecycle steps, for rendering the stepper."
  def lifecycle_steps(), do: @lifecycle

  @doc "Where a given step sits relative to the order's current status."
  def step_state(current, step) do
    ci = Enum.find_index(@lifecycle, &(&1 == current))
    si = Enum.find_index(@lifecycle, &(&1 == step))

    cond do
      si < ci -> :done
      si == ci -> :now
      true -> :todo
    end
  end

  def step_label(:pending), do: "Placed"
  def step_label(:accepted), do: "Accepted"
  def step_label(:shopping), do: "Shopping"
  def step_label(:on_delivery), do: "Delivery"
  def step_label(:delivered), do: "Done"

  def bead_class(:done), do: "border-st-amber bg-st-amber"
  def bead_class(:now), do: "border-st-amber bg-st-amber ring-2 ring-st-amber/30"
  def bead_class(:todo), do: "border-ui-line bg-ui-surface"

  def step_label_class(:done), do: "text-ui-text-2"
  def step_label_class(:now), do: "text-ui-text font-medium"
  def step_label_class(:todo), do: "text-ui-text-3"

  # ---------- line items ----------

  def item_box_class(:picked), do: "border-st-green bg-st-green/10 text-st-green"
  def item_box_class(:unavailable), do: "border-st-red bg-st-red/10 text-st-red"
  def item_box_class(:pending), do: "border-dashed border-ui-line text-transparent"

  def item_box_icon(:picked), do: "✓"
  def item_box_icon(:unavailable), do: "✕"
  def item_box_icon(:pending), do: ""

  def item_name_class(:picked), do: "text-ui-text"
  def item_name_class(:unavailable), do: "text-ui-text-3 line-through"
  def item_name_class(:pending), do: "text-ui-text-2"

  # ---------- shopper panel ----------

  def shopper_status_text(:accepted), do: "accepted your order"
  def shopper_status_text(:shopping), do: "is shopping"
  def shopper_status_text(:on_delivery), do: "is on the way"
  def shopper_status_text(:delivered), do: "delivered your order"
  def shopper_status_text(_), do: "assigned"

  @doc "e.g. \"2 of 5 items resolved\"."
  def resolved_count(line_items) do
    total = length(line_items)
    resolved = Enum.count(line_items, &(&1.pickup_status != :pending))
    "#{resolved} of #{total} items resolved"
  end
end
