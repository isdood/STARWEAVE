defmodule StarweaveLlm.SelfKnowledge.ElixirCodeParserTest do
  use ExUnit.Case, async: true
  alias StarweaveLlm.SelfKnowledge.ElixirCodeParser

  @test_module ~S/
  defmodule Example.User do
    @moduledoc """
    This is a test module for User functionality.
    """

    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            email: String.t()
          }

    defstruct [:id, :name, :email]

    @doc """
    Creates a new user with the given name and email.
    """
    @spec create(String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
    def create(name, email) when is_binary(name) and is_binary(email) do
      if String.contains?(email, "@") do
        {:ok, %__MODULE__{id: System.unique_integer([:positive]), name: name, email: email}}
      else
        {:error, "Invalid email format"}
      end
    end

    @doc """
    Updates a user's email address.
    """
    @spec update_email(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
    def update_email(%__MODULE__{} = user, new_email) when is_binary(new_email) do
      if String.contains?(new_email, "@") do
        {:ok, %{user | email: new_email}}
      else
        {:error, "Invalid email format"}
      end
    end
  end
  /

  test "parses module documentation" do
    result = ElixirCodeParser.parse(@test_module, "test.ex")
    assert %{docs: %{module: %{content: module_doc}}} = result
    assert String.contains?(module_doc, "This is a test module for User functionality.")
  end

  test "extracts function documentation" do
    result = ElixirCodeParser.parse(@test_module, "test.ex")
    assert %{docs: %{functions: [%{content: create_doc}, %{content: update_doc}]}} = result
    assert String.contains?(create_doc, "Creates a new user")
    assert String.contains?(update_doc, "Updates a user's email")
  end

  test "extracts function specs" do
    result = ElixirCodeParser.parse(@test_module, "test.ex")
    assert %{functions: [%{spec: create_spec}, %{spec: update_spec}]} = result
    assert String.contains?(create_spec, "@spec create")
    assert String.contains?(update_spec, "@spec update_email")
  end

  test "extracts types" do
    result = ElixirCodeParser.parse(@test_module, "test.ex")
    assert %{types: [%{name: :t, definition: definition}]} = result
    assert String.contains?(definition, "%__MODULE__{")
  end

  test "extracts module attributes" do
    result = ElixirCodeParser.parse(@test_module, "test.ex")
    assert %{attributes: attributes} = result
    assert is_map(attributes)
  end

  test "extracts references" do
    result = ElixirCodeParser.parse(@test_module, "test.ex")
    assert %{references: %{modules: modules, functions: functions}} = result
    assert is_list(modules)
    assert is_list(functions)
  end

  test "handles invalid code gracefully" do
    result = ElixirCodeParser.parse("defmodule Invalid {}", "invalid.ex")
    assert %{content: _} = result
  end
end
