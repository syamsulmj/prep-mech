defmodule PrepMech.Accounts do
  @moduledoc """
  This module is used for managing all accounts related business logic contexts.

  Covers user registration (customer & shopper), password authentication, and
  the lookups used to load the current user from the session.
  """

  alias PrepMech.Repo
  alias PrepMech.User

  ## Lookups

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user by id. Raises `Ecto.NoResultsError` if not found.

  Use this when the id is trusted (e.g. loading the current user from the
  session) and a missing user is a programmer error.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by id, or `nil` if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a single user by email, or `nil` if not found.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  ## Registration

  @doc """
  Registers a customer.

  ## Examples

      iex> register_customer(%{name: "Jane", email: "jane@example.com", password: "secret123"})
      {:ok, %User{role: :customer}}

      iex> register_customer(%{email: "bad"})
      {:error, %Ecto.Changeset{}}

  """
  def register_customer(attrs), do: register_user(attrs, :customer_registration)

  @doc """
  Registers a shopper. See `register_customer/1`.
  """
  def register_shopper(attrs), do: register_user(attrs, :shopper_registration)

  defp register_user(attrs, type) do
    %User{}
    |> User.changeset(attrs, type)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for tracking registration form changes.

  Used by the signup controller to render the form and re-render it with
  errors. Pass the role-specific type (`:customer_registration` or
  `:shopper_registration`) so the form validates the right way.

  ## Examples

      iex> change_user_registration(%User{})
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(user \\ %User{}, attrs \\ %{}, type \\ :customer_registration) do
    User.changeset(user, attrs, type)
  end

  ## Authentications

  @spec authenticate_user(String.t(), String.t()) :: {:ok, User.t()} | {:error, :unauthorized}
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    with %User{} = user <- get_user_by_email(email),
         true <- User.valid_password?(user, password) do
      {:ok, user}
    else
      _ -> {:error, :unauthorized}
    end
  end
end
