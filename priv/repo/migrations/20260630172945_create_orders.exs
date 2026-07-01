defmodule PrepMech.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :customer_id, references(:users, on_delete: :nilify_all), null: false
      add :shopper_id, references(:users, on_delete: :nilify_all)

      add :status, :string, null: false, default: "pending"
      add :delivery_address, :string, null: false
      add :notes, :text

      add :accepted_at, :utc_datetime
      add :delivered_at, :utc_datetime
      add :estimated_delivery_minutes, :integer

      timestamps()
    end

    create index(:orders, [:status])
    create index(:orders, [:customer_id])
    create index(:orders, [:shopper_id])
  end
end
