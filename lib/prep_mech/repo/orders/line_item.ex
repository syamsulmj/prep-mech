defmodule PrepMech.LineItem do
  @moduledoc """
  A single requested item within an order (e.g. "5 Apples").

  `pickup_status` tracks the shopper's resolution of the item while shopping:

    * `:pending`     — not yet checked (the shopper hasn't reached it)
    * `:picked`      — available and added to the basket
    * `:unavailable` — not available (crossed out; the UI prompts a call)

  There is no separate "substitution" record: an unavailable item is simply
  marked `:unavailable`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PrepMech.Order

  @type t() :: %__MODULE__{}

  @pickup_statuses [:pending, :picked, :unavailable]

  schema "line_items" do
    field :name, :string
    field :quantity, :integer, default: 1
    field :pickup_status, Ecto.Enum, values: @pickup_statuses, default: :pending

    belongs_to :order, Order

    timestamps()
  end

  @doc "The valid pickup statuses."
  def pickup_statuses(), do: @pickup_statuses

  @doc """
  Changeset for creating a line item (name + quantity).

  Used via `cast_assoc/3` from `PrepMech.Order.create_changeset/2`.
  """
  def changeset(line_item, attrs) do
    line_item
    |> cast(attrs, [:name, :quantity])
    |> validate_required([:name, :quantity])
    |> validate_number(:quantity, greater_than: 0)
  end

  @doc """
  Changeset for resolving an item's pickup status while shopping.
  """
  def pickup_changeset(line_item, status) do
    line_item
    |> change(pickup_status: status)
    |> validate_inclusion(:pickup_status, @pickup_statuses)
  end
end
