defmodule StarweaveCore.PatternStore do
  @moduledoc """
  In-memory pattern store backed by ETS.
  """
  use GenServer

  alias StarweaveCore.Pattern

  @table :starweave_patterns

  # Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec put(Pattern.t()) :: :ok
  def put(%Pattern{} = pattern), do: GenServer.call(__MODULE__, {:put, pattern})

  @spec get(String.t()) :: Pattern.t() | nil
  def get(id) when is_binary(id) do
    case :ets.lookup(@table, id) do
      [{^id, pattern}] -> pattern
      _ -> nil
    end
  end

  @spec all() :: [Pattern.t()]
  def all, do: :ets.tab2list(@table) |> Enum.map(fn {_id, p} -> p end)

  @spec clear() :: :ok
  def clear, do: GenServer.call(__MODULE__, :clear)

  # GenServer

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:put, %Pattern{} = pattern}, _from, state) do
    now = System.system_time(:millisecond)
    stored = %Pattern{pattern | inserted_at: pattern.inserted_at || now}
    true = :ets.insert(@table, {stored.id, stored})
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end
end
