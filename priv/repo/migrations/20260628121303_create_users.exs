defmodule PrepMech.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :phone, :string
      add :address, :string
      add :role, :string, null: false

      add :password_hashed, :string, null: false

      timestamps()
    end

    create unique_index(:users, :email)
  end
end
