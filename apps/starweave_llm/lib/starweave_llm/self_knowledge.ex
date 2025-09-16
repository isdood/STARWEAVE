defmodule StarweaveLLM.SelfKnowledge do
  @moduledoc """
  Self-knowledge system for STARWEAVE that enables the AI to understand and reason about its own codebase.
  """

  use GenServer
  require Logger

  alias __MODULE__.CodeIndexer
  alias __MODULE__.KnowledgeBase
  alias __MODULE__.QueryEngine

  @table_name :starweave_self_knowledge
  @dets_file ~c"self_knowledge.dets"
  @check_interval :timer.minutes(5)  # Check for changes every 5 minutes

  # Public API

  @doc """
  Starts the SelfKnowledge GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Query the self-knowledge base with natural language.
  """
  def query(question) when is_binary(question) do
    GenServer.call(__MODULE__, {:query, question})
  end

  @doc """
  Force a reindex of the codebase.
  """
  def reindex do
    GenServer.cast(__MODULE__, :reindex)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    # Ensure the data directory exists
    :ok = File.mkdir_p(Application.app_dir(:starweave_llm, "priv/data"))
    dets_path = Path.join(Application.app_dir(:starweave_llm, "priv/data"), @dets_file)
    
    # Initialize the knowledge base
    {:ok, knowledge_base} = KnowledgeBase.start_link(
      table_name: @table_name,
      dets_path: dets_path
    )

    # Initial index
    if File.exists?(dets_path) do
      :ok = KnowledgeBase.load(knowledge_base)
    else
      :ok = index_codebase(knowledge_base)
    end

    # Schedule periodic checks
    schedule_check()

    {:ok, %{knowledge_base: knowledge_base}}
  end

  @impl true
  def handle_call({:query, question}, _from, %{knowledge_base: kb} = state) do
    results = QueryEngine.query(kb, question)
    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_cast(:reindex, %{knowledge_base: kb} = state) do
    Logger.info("Starting manual reindex of codebase")
    :ok = index_codebase(kb)
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_for_changes, %{knowledge_base: kb} = state) do
    if CodeIndexer.codebase_changed?(kb) do
      Logger.info("Detected code changes, reindexing...")
      :ok = index_codebase(kb)
    end
    schedule_check()
    {:noreply, state}
  end

  # Private functions

  defp index_codebase(knowledge_base) do
    with {:ok, files} <- CodeIndexer.find_source_files(),
         :ok <- KnowledgeBase.clear(knowledge_base),
         :ok <- CodeIndexer.index_files(knowledge_base, files) do
      :ok = KnowledgeBase.persist(knowledge_base)
      Logger.info("Successfully indexed #{length(files)} files")
      :ok
    else
      error ->
        Logger.error("Failed to index codebase: #{inspect(error)}")
        error
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check_for_changes, @check_interval)
  end
end
