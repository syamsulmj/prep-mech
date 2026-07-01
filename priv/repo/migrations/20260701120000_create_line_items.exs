defmodule PrepMech.Repo.Migrations.CreateLineItems do
  use Ecto.Migration

  def change do
    create table(:line_items) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :quantity, :integer, null: false, default: 1

      # pending = not yet checked, picked = added to basket, unavailable = crossed out.
      add :pickup_status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:line_items, [:order_id])
  end
end
