defmodule StarweaveLlm.SelfKnowledge.CodeCrossReferencerTest do
  use ExUnit.Case, async: true
  
  import ExUnit.CaptureLog
  alias StarweaveLlm.SelfKnowledge.CodeCrossReferencer
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  
  # Mock KnowledgeBase implementation for testing
  defmodule MockKnowledgeBase do
    use GenServer
    @behaviour StarweaveLlm.SelfKnowledge.KnowledgeBase
    
    def start_link(_opts) do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    @impl true
    def init(state) do
      {:ok, state}
    end

    @test_docs %{
      "lib/user.ex" => %{
        parsed_content: %{
          module: "User",
          docs: %{
            module: %{content: "User related functionality"},
            functions: [
              %{content: "Creates a new user", name: "create"},
              %{content: "Updates a user's email", name: "update_email"}
            ]
          },
          types: [
            %{name: "t", spec: "@type t() :: %__MODULE__{id: integer(), name: String.t(), email: String.t()}"}
          ],
          functions: [
            %{
              name: "create",
              arity: 2,
              spec: "@spec create(String.t(), String.t()) :: {:ok, User.t()} | {:error, String.t()}",
              calls: ["String.contains?", "System.unique_integer"],
              line: 10
            },
            %{
              name: "update_email",
              arity: 2,
              spec: "@spec update_email(integer(), String.t()) :: {:ok, User.t()} | {:error, String.t()}",
              calls: ["String.contains?", "Ecto.Changeset"],
              line: 25
            },
            %{
              name: "send_welcome_email",
              arity: 1,
              spec: "@spec send_welcome_email(User.t()) :: :ok",
              calls: ["Email.send_welcome", "Logger.info"],
              line: 40
            }
          ]
        }
      },
      "lib/email.ex" => %{
        parsed_content: %{
          module: "Email",
          docs: %{
            module: %{content: "Email related functionality"},
            functions: [
              %{content: "Sends a welcome email", name: "send_welcome"}
            ]
          },
          functions: [
            %{
              name: "send_welcome",
              arity: 1,
              spec: "@spec send_welcome(User.t()) :: :ok | {:error, String.t()}",
              calls: ["Bamboo.Email.new", "Bamboo.Mailer.deliver_now"],
              line: 5
            }
          ]
        }
      }
    }

    @impl true
    def handle_call(:get_all_documents, _from, state) do
      {:reply, get_all_documents(nil), state}
    end
    
    @impl true
    def handle_call({:get, key}, _from, state) do
      {:reply, get(nil, key), state}
    end
    
    @impl true
    def handle_call(_, _from, state) do
      {:reply, :ok, state}
    end

    def get_all_documents(_) do
      {:ok, @test_docs}
    end
    
    def get(_, "_last_indexed"), do: {:ok, %{last_updated: :os.system_time(:second)}}
    def get(_, _), do: {:error, :not_found}

    def child_spec(opts) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [opts]},
        type: :worker,
        restart: :permanent,
        shutdown: 500
      }
    end
  end
  
  # Setup block for all tests
  setup do
    # Start the mock knowledge base
    {:ok, kb_pid} = start_supervised(MockKnowledgeBase)
    %{knowledge_base: kb_pid}
  end
  
  describe "find_references/2" do
    test "finds references to a module", %{knowledge_base: kb} do
      references = CodeCrossReferencer.find_references(kb, "String")
      assert length(references) > 0
      assert Enum.any?(references, &match?(%{type: :module, name: "String"}, &1))
    end

    test "finds references to a function", %{knowledge_base: kb} do
      references = CodeCrossReferencer.find_references(kb, "create")
      assert length(references) > 0
      assert Enum.any?(references, &match?(%{type: :function, name: "User.create"}, &1))
    end
    
    test "handles non-existent files gracefully" do
      defmodule FailingKnowledgeBase do
        use GenServer
        @behaviour StarweaveLlm.SelfKnowledge.KnowledgeBase

        def start_link(_opts) do
          GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
        end

        @impl true
        def init(state) do
          {:ok, state}
        end
        
        @impl true
        def handle_call(:get_all_documents, _from, state) do
          {:reply, {:error, :not_found}, state}
        end
        
        @impl true
        def handle_call({:get, _}, _from, state) do
          {:reply, {:error, :not_found}, state}
        end

        def child_spec(opts) do
          %{
            id: __MODULE__,
            start: {__MODULE__, :start_link, [opts]},
            type: :worker,
            restart: :temporary,
            shutdown: 500
          }
        end
      end

      # Start the failing knowledge base
      {:ok, pid} = FailingKnowledgeBase.start_link([])
      
      # Test that it handles the error case gracefully
      assert {:error, _} = CodeCrossReferencer.build_relationship_graph(pid)
      
      # Clean up
      Process.exit(pid, :normal)
    end
  end
  
  describe "find_callers/2" do
    test "finds functions that call another function", %{knowledge_base: kb} do
      assert {:ok, graph} = CodeCrossReferencer.build_relationship_graph(kb)
      callers = CodeCrossReferencer.find_callers(graph, "String.contains?")
      
      # Should find both User.create and User.update_email calling String.contains?
      assert length(callers) == 2
      assert Enum.any?(callers, &match?(%{module: "User", function: "create"}, &1))
      assert Enum.any?(callers, &match?(%{module: "User", function: "update_email"}, &1))
    end
    
    test "finds functions that call a module function with arity", %{knowledge_base: kb} do
      assert {:ok, graph} = CodeCrossReferencer.build_relationship_graph(kb)
      callers = CodeCrossReferencer.find_callers(graph, "String.contains?/2")
      
      assert length(callers) == 2
      assert Enum.any?(callers, &match?(%{module: "User", function: "create"}, &1))
    end
    
    test "returns empty list when no callers found", %{knowledge_base: kb} do
      assert {:ok, graph} = CodeCrossReferencer.build_relationship_graph(kb)
      assert CodeCrossReferencer.find_callers(graph, "Nonexistent.function") == []
    end
  end
  
  describe "build_relationship_graph/1" do
    test "builds a graph with modules and functions", %{knowledge_base: kb} do
      assert {:ok, graph} = CodeCrossReferencer.build_relationship_graph(kb)
      
      # Check that modules were added as vertices
      assert :digraph.vertices(graph) |> Enum.any?(&match?({:module, _}, &1))
      
      # Check that functions were added as vertices
      assert :digraph.vertices(graph) |> Enum.any?(&match?({:function, _}, &1))
      
      # Check that calls were added as edges
      assert :digraph.edges(graph) != []
    end
    
    test "handles errors from knowledge base" do
      defmodule FailingKnowledgeBase do
        use GenServer
        @behaviour StarweaveLlm.SelfKnowledge.KnowledgeBase
        
        def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
        def init(state), do: {:ok, state}
        
        @impl true
        def handle_call(:get_all_documents, _from, state) do
          {:reply, {:error, :database_down}, state}
        end
        
        @impl true
        def handle_call({:get, _}, _from, state) do
          {:reply, {:error, :not_found}, state}
        end
        
        def child_spec(opts) do
          %{
            id: __MODULE__,
            start: {__MODULE__, :start_link, [opts]},
            type: :worker,
            restart: :temporary,
            shutdown: 500
          }
        end
      end
      
      {:ok, pid} = start_supervised(FailingKnowledgeBase)
      
      assert {:error, :database_down} = CodeCrossReferencer.build_relationship_graph(pid)
      
      # Clean up
      Process.exit(pid, :normal)
    end
  end
  
  describe "find_related_types/2" do
    test "finds functions that use a specific type in their specs", %{knowledge_base: kb} do
      assert {:ok, graph} = CodeCrossReferencer.build_relationship_graph(kb)
      types = CodeCrossReferencer.find_related_types(graph, "User.t")
      
      # Should find send_welcome function that takes User.t as parameter
      assert Enum.any?(types, &match?(%{name: "send_welcome", type: :function_with_type_reference}, &1))
    end
    
    test "handles non-existent types gracefully", %{knowledge_base: kb} do
      assert {:ok, graph} = CodeCrossReferencer.build_relationship_graph(kb)
      assert CodeCrossReferencer.find_related_types(graph, "NonExistentType") == []
    end
  end
end
