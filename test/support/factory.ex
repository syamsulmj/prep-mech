defmodule PrepMech.Factory do
  @moduledoc """
  ExMachina factories for building test data.

  Two ways to make a user, for two different needs:

    * `insert(:user)` / `build(:user)` — produces a `%User{}` struct with
      `:password_hashed` already set. ExMachina's `insert` writes the struct
      straight to the DB and BYPASSES the changeset, so the hash must be
      pre-computed here. Use this when you need a user that already exists.

    * `valid_registration_attrs/1` — a plain attribute map with the *virtual*
      `:password` (plaintext). Pass this to `Accounts.register_customer/1` or
      `register_shopper/1`, which run it through the changeset that hashes.

  Both use the same plaintext, `valid_password/0`, so a user built with
  `insert(:user)` can be authenticated with `valid_password()` in tests.
  """

  use ExMachina.Ecto, repo: PrepMech.Repo

  alias PrepMech.User

  @doc "The plaintext password backing every factory-built user."
  def valid_password, do: "hello world!"

  def user_factory do
    %User{
      name: "Test User",
      email: sequence(:email, &"user-#{&1}@example.com"),
      phone: "012-3456789",
      address: "1 Test Street",
      role: :customer,
      password_hashed: Bcrypt.hash_pwd_salt(valid_password())
    }
  end

  @doc """
  A plain attribute map suitable for the registration changeset.

  Uses the virtual `:password` field (plaintext), not `:password_hashed`,
  so it flows correctly through `Accounts.register_customer/1` &
  `register_shopper/1`. Override any field via `attrs`.
  """
  def valid_registration_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "New User",
      email: sequence(:email, &"new-#{&1}@example.com"),
      phone: "012-3456789",
      address: "1 Test Street",
      password: valid_password()
    })
  end
end
