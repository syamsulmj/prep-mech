defmodule PrepMech.Order do
  @moduledoc """
  An order placed by a customer and fulfilled by a personal shopper.

  An order moves through a fixed, forward-only status lifecycle:

      pending -> accepted -> shopping -> on_delivery -> delivered

  It starts life in the shared pool (`:pending`, no `shopper_id`). A shopper
  claims it (`:accepted`), shops the line items, then delivers. The status
  transitions themselves — including the atomic claim and the "all items
  resolved" gate before delivery — live in `PrepMech.Orders`, not here.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PrepMech.LineItem
  alias PrepMech.User

  @type t() :: %__MODULE__{}

  @statuses [:pending, :accepted, :shopping, :on_delivery, :delivered]

  schema "orders" do
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :delivery_address, :string
    field :notes, :string

    field :accepted_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :estimated_delivery_minutes, :integer

    belongs_to :customer, User
    belongs_to :shopper, User

    has_many :line_items, LineItem

    timestamps()
  end

  @doc "The ordered list of valid statuses, earliest first."
  def statuses(), do: @statuses

  @doc """
  Changeset for a customer creating a new order with its line items.

  Requires a `customer_id`, a delivery address, and at least one line item.
  """
  def create_changeset(order \\ %__MODULE__{}, attrs) do
    order
    |> cast(attrs, [:customer_id, :delivery_address, :notes])
    |> validate_required([:customer_id, :delivery_address])
    |> cast_assoc(:line_items, with: &LineItem.changeset/2, required: true)
    |> validate_length(:line_items, min: 1)
    |> assoc_constraint(:customer)
  end

  @doc """
  Changeset for a status transition and its accompanying fields.

  The caller (`PrepMech.Orders`) supplies the already-validated target status
  plus any fields that transition writes (e.g. `shopper_id`, `accepted_at`).
  """
  def status_changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :shopper_id, :accepted_at, :delivered_at])
    |> validate_required([:status])
    |> assoc_constraint(:shopper)
  end
end
