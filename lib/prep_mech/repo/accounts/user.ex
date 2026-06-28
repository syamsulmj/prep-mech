defmodule PrepMech.User do
  use Ecto.Schema
  import Ecto.Changeset

  @roles [:customer, :shopper]

  schema "users" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :address, :string
    field :role, Ecto.Enum, values: @roles, default: :customer

    field :password, :string, virtual: true
    field :password_hashed, :string

    timestamps()
  end

  @doc """
  List of roles
  """
  def roles(), do: @roles

  @doc """
  Variantions of changeset for specific usecases
  """
  def changeset(user \\ %__MODULE__{}, attrs, user_type)

  def changeset(user, attrs, :customer_registration) do
    user
    |> cast(attrs, [:name, :email, :phone, :address, :password, :role])
    |> put_change(:role, :customer)
    |> registration_changeset()
  end

  def changeset(user, attrs, :shopper_registration) do
    user
    |> cast(attrs, [:name, :email, :phone, :address, :password, :role])
    |> put_change(:role, :shopper)
    |> registration_changeset()
  end

  def changeset(user, attrs, :update) do
    user
    |> cast(attrs, [:name, :email, :phone, :address, :role])
    |> validate_required([:name, :email, :role])
  end

  defp registration_changeset(change) do
    change
    |> validate_required([:name])
    |> validate_email()
    |> validate_password_complexity()
    |> put_pass_hash()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, PrepMech.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password_complexity(change) do
    change
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
  end

  defp put_pass_hash(change) do
    case change do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        change
        |> put_change(:password_hashed, Bcrypt.hash_pwd_salt(pass))
        |> delete_change(:password)

      _ ->
        change
    end
  end

  @doc """
  Verifies a plaintext password against the stored hash.

  Returns `false` (and runs a dummy hash to keep response timing constant)
  when there is no user or no stored hash, to mitigate user-enumeration
  timing attacks during login.
  """
  def valid_password?(%__MODULE__{password_hashed: hashed}, password)
      when is_binary(hashed) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
