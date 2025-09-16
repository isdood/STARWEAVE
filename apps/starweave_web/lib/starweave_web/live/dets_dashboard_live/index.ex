defmodule StarweaveWeb.DetsDashboardLive.Index do
  use StarweaveWeb, :live_view
  alias StarweaveCore.Pattern.Storage.DetsPatternStore
  alias StarweaveCore.Intelligence.Storage.DetsWorkingMemory
  require Logger
  
  # Define the DETS table names as module attributes for easy reference
  # Use the same table names as defined in the core modules
  @working_memory_table :starweave_working_memory
  @pattern_store_table :starweave_pattern_store

  @tick_interval 30_000  # 30 seconds

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :tick, @tick_interval)
    end
    
    socket = assign(socket, 
      items: [],
      total_size: 0,
      item_count: 0,
      last_updated: nil,
      error: nil,
      show_modal: false,
      selected_item: nil,
      current_uri: "/dets-dashboard"
    )
    
    {:ok, fetch_dets_data(socket)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _, socket) do
    IO.inspect("Refresh event received")
    {:noreply, fetch_dets_data(socket)}
  end

  def handle_event("show_item", %{"id" => id}, socket) do
    # Find the item by ID and ensure data is properly formatted
    item = 
      socket.assigns.items
      |> Enum.find(&(to_string(&1.id) == to_string(id)))
      
    # Ensure we have a proper map with all required fields
    item_with_formatted_data = 
      if item do
        %{
          id: item.id,
          type: item.type,
          size: item.size,
          inserted_at: item.inserted_at,
          data: item.data,
          raw_data: format_raw_data(item.data)
        }
      end
      
    {:noreply, assign(socket, show_modal: true, selected_item: item_with_formatted_data)}
  end
  
  @impl true
  def handle_event("delete_item", %{"id" => raw_id} = _params, socket) do
    IO.puts("DELETE_ITEM: Received delete request for ID: #{inspect(raw_id)}")
    
    # Clean and parse the ID
    clean_id = 
      raw_id
      |> String.trim(~s("))
      |> String.trim("'")
      
    IO.puts("DELETE_ITEM: Cleaned ID: #{inspect(clean_id)}")
    
    # Try to find the item by ID
    case find_item_by_id(socket.assigns.items, clean_id) do
      nil ->
        IO.puts("DELETE_ITEM_ERROR: Item not found: #{inspect(clean_id)}")
        IO.inspect(socket.assigns.items, label: "Available items")
        {:noreply, put_flash(socket, :error, "Item not found: #{clean_id}")}
        
      item_to_delete ->
        IO.puts("DELETE_ITEM: Found item to delete: #{inspect(item_to_delete)}")
        
        # Delete the item from the appropriate DETS table
        case delete_item(item_to_delete.id) do
          :ok ->
            # Remove the item from the list and update the UI
            updated_items = Enum.reject(socket.assigns.items, &(to_string(&1.id) == to_string(clean_id)))
            
            socket = assign(socket,
              items: updated_items,
              item_count: length(updated_items),
              total_size: Enum.reduce(updated_items, 0, &(&1.size + &2)),
              show_modal: false,
              selected_item: nil,
              last_updated: DateTime.utc_now()
            )
            
            IO.puts("DELETE_ITEM: Successfully deleted item: #{inspect(item_to_delete.id)}")
            {:noreply, put_flash(socket, :info, "Item deleted successfully")}
            
          {:error, reason} ->
            IO.puts("DELETE_ITEM_ERROR: Failed to delete item: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to delete item: #{inspect(reason)}")}
        end
    end
  end
  
  # Helper function to find an item by ID, handling different ID formats
  defp find_item_by_id(items, id) when is_binary(id) do
    # First try direct string comparison
    case Enum.find(items, &(to_string(&1.id) == id)) do
      nil ->
        # If not found, try to parse as Elixir term
        try do
          {term, _} = Code.eval_string(id)
          Enum.find(items, &(&1.id == term))
        rescue
          _ ->
            # If parsing fails, try more flexible comparison
            id_str = id |> String.downcase() |> String.trim()
            Enum.find(items, fn item ->
              item_str = item.id |> to_string() |> String.downcase()
              item_str == id_str || String.ends_with?(item_str, id_str)
            end)
        end
      item ->
        item
    end
  end
  
  defp find_item_by_id(items, id) do
    # For non-string IDs, try direct comparison first
    case Enum.find(items, &(&1.id == id)) do
      nil ->
        # If not found, try string comparison
        Enum.find(items, &(to_string(&1.id) == to_string(id)))
      item ->
        item
    end
  end
  
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_item: nil)}
  end
  
  defp format_raw_data(data) when is_binary(data) do
    if String.valid?(data) do
      data
    else
      inspect(data, pretty: true, limit: :infinity, printable_limit: :infinity)
    end
  end
  
  defp format_raw_data(data) do
    inspect(data, pretty: true, limit: :infinity, printable_limit: :infinity)
  end
  
  defp delete_item(id) when is_binary(id) do
    # Convert string ID to appropriate term if needed
    id_term = 
      case Code.eval_string(id) do
        {term, _} -> term
        _ -> id
      end
    delete_item(id_term)
  end

  defp delete_item(id) do
    # First try to delete from working memory
    case :dets.lookup(@working_memory_table, id) do
      [{^id, _}] -> 
        :dets.delete(@working_memory_table, id)
        :ok
      _ -> 
        # If not in working memory, try pattern store
        case :dets.lookup(@pattern_store_table, id) do
          [{^id, _}] -> 
            :dets.delete(@pattern_store_table, id)
            :ok
          _ -> 
            {:error, :not_found}
        end
    end
  end
  
  defp ensure_dets_tables do
    # The DETS tables are already initialized by the core application
    # We just need to verify they're accessible
    case :dets.info(@working_memory_table) do
      :undefined -> 
        IO.puts("DETS ERROR: Working memory table not found")
        {:error, "Working memory table not initialized. Please ensure the core application is running."}
      _ ->
        IO.puts("DETS: Working memory table is available")
        :ok
    end
  end

  @impl true
  def handle_event("clear_all", _params, socket) do
    IO.puts("CLEAR_ALL: Received clear all request")
    
    # Ensure tables are accessible
    case :dets.info(@working_memory_table) do
      :undefined ->
        error = "Working memory table not found. Is the core application running?"
        IO.puts("CLEAR_ALL_ERROR: #{error}")
        {:noreply, put_flash(socket, :error, error)}
        
      _ ->
        try do
          # Delete all objects from working memory
          :ok = :dets.delete_all_objects(@working_memory_table)
          
          # Clear working memory
          :ok = :dets.delete_all_objects(@working_memory_table)
          :ok = :dets.sync(@working_memory_table)
          
          # Handle pattern store if it exists
          pattern_store_cleared = 
            case :dets.info(@pattern_store_table) do
              :undefined -> 
                IO.puts("CLEAR_ALL: Pattern store table not found, skipping")
                true
              _ ->
                try do
                  :ok = :dets.delete_all_objects(@pattern_store_table)
                  :ok = :dets.sync(@pattern_store_table)
                  true
                rescue
                  e ->
                    IO.puts("CLEAR_ALL: Error clearing pattern store: #{inspect(e)}")
                    false
                end
            end
          
          # Verify working memory is empty
          working_count = case :dets.info(@working_memory_table, :size) do
            :undefined -> 0
            size -> size
          end
          
          # Only check pattern store if we tried to clear it
          pattern_count = if pattern_store_cleared do
            case :dets.info(@pattern_store_table, :size) do
              :undefined -> 0
              size -> size
            end
          else
            0  # If we didn't clear it, consider it cleared for the success check
          end
          
          if working_count == 0 and pattern_count == 0 do
            IO.puts("CLEAR_ALL: Successfully cleared all data")
            {:noreply, 
              socket 
              |> assign(
                items: [],
                item_count: 0,
                total_size: 0,
                last_updated: DateTime.utc_now(),
                show_modal: false,
                selected_item: nil
              )
              |> put_flash(:info, "All data has been cleared successfully")}
          else
            error = "Failed to clear all data. Remaining items: Working=#{working_count}, Patterns=#{pattern_count}"
            IO.puts("CLEAR_ALL_ERROR: #{error}")
            {:noreply, put_flash(socket, :error, error)}
          end
          
        rescue
          e ->
            error = "Error clearing DETS tables: #{inspect(e)}"
            IO.puts("CLEAR_ALL_ERROR: #{error}")
            IO.inspect(__STACKTRACE__)
            {:noreply, put_flash(socket, :error, error)}
        end
    end
  end
  
  # Helper function to update the dashboard UI
  defp update_dashboard_ui(socket) do
    fetch_dets_data(socket)
  end

  @impl true
  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, @tick_interval)
    {:noreply, fetch_dets_data(socket)}
  end

  defp fetch_dets_data(socket) do
    case get_dets_data() do
      {:ok, data} ->
        assign(socket, 
          items: data[:items] || [],
          item_count: data[:item_count] || 0,
          total_size: data[:total_size] || 0,
          last_updated: data[:last_updated] || DateTime.utc_now()
        )
      {:error, reason} ->
        Logger.error("Failed to fetch DETS data: #{inspect(reason)}")
        put_flash(socket, :error, "Failed to fetch data: #{inspect(reason)}")
    end
  end

  defp get_dets_data do
    try do
      # Check if DETS tables exist and are open
      working_memory_items = get_dets_table_items(@working_memory_table, :working_memory)
      pattern_store_items = get_dets_table_items(@pattern_store_table, :pattern_store)
      
      # Combine and format items
      items = (working_memory_items ++ pattern_store_items) |> Enum.map(&format_item/1)
      
      # Calculate total size
      total_size = Enum.reduce(items, 0, &(&1.size + &2))
      
      {:ok, %{
        items: items,
        total_size: total_size,
        item_count: length(items),
        last_updated: DateTime.utc_now()
      }}
    rescue
      e ->
        Logger.error("Error in get_dets_data: #{inspect(e)}")
        {:error, e}
    end
  end
  
  defp get_dets_table_items(table, type) do
    case :dets.info(table) do
      info when is_list(info) ->
        case :dets.safe_fixtable(table, true) do
          :ok ->
            try do
              :dets.match_object(table, :_)
              |> Enum.map(fn {id, data} ->
                %{
                  id: format_data(id),
                  data: data,
                  type: type,
                  size: :erlang.external_size(data),
                  inserted_at: DateTime.utc_now(),
                  raw_data: inspect(data, pretty: true, limit: :infinity, printable_limit: :infinity)
                }
              end)
            after
              :dets.safe_fixtable(table, false)
            end
          _ ->
            Logger.warning("Could not fix table #{inspect(table)} for reading")
            []
        end
      _ ->
        Logger.debug("DETS table #{inspect(table)} not found or not open")
        []
    end
  end
  
  defp format_data(data) when is_tuple(data) or is_list(data) or is_map(data) do
    inspect(data, pretty: true, limit: 50, printable_limit: 50)
  end
  
  defp format_data(data) when is_binary(data) do
    if String.valid?(data) && String.length(data) > 50 do
      String.slice(data, 0..49) <> "..."
    else
      data
    end
  end
  
  defp format_data(data), do: inspect(data)

  defp format_item(%{} = item) do
    # Ensure all required fields are present with defaults
    Map.merge(
      %{
        id: "",
        data: nil,
        type: :unknown,
        size: 0,
        inserted_at: DateTime.utc_now(),
        raw_data: ""
      },
      item
    )
  end
  
  defp format_item(item) when is_map(item) do
    # Handle case where item is a map but not a struct
    format_item(Map.new(item))
  end
  
  defp format_item(item) do
    # Fallback for any other case
    %{
      id: inspect(item[:id] || "unknown"),
      data: item[:data],
      type: item[:type] || :unknown,
      size: item[:size] || 0,
      inserted_at: item[:inserted_at] || DateTime.utc_now(),
      raw_data: inspect(item, pretty: true)
    }
  end
  
  defp format_memory(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{(bytes / 1_000_000_000) |> Float.round(2)} GB"
      bytes >= 1_000_000 -> "#{(bytes / 1_000_000) |> Float.round(2)} MB"
      bytes >= 1_000 -> "#{(bytes / 1_000) |> Float.round(2)} KB"
      true -> "#{bytes} bytes"
    end
  end
  
  defp format_timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  
  defp format_timestamp(_), do: "N/A"
end
