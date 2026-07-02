defmodule PrepMechWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by channel tests.

  Enables the SQL sandbox so DB changes are reverted per test, and imports the
  Phoenix channel test conveniences plus the data factory.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint PrepMechWeb.Endpoint

      use PrepMechWeb, :verified_routes

      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import PrepMechWeb.ChannelCase
      import PrepMech.Factory
    end
  end

  setup tags do
    PrepMech.DataCase.setup_sandbox(tags)
    :ok
  end
end
