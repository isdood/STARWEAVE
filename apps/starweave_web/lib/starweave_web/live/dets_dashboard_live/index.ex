defmodule StarweaveWeb.DetsDashboardLive.Index do
  use StarweaveWeb, :live_view
  alias StarweaveCore.Pattern.Storage.DetsPatternStore
  alias StarweaveCore.Intelligence.Storage.DetsWorkingMemory
  require Logger
  
  # Define the DETS table names as module attributes for easy reference
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
  
  def handle_event("delete_item", %{"id" => id}, socket) do
    # Get the item being deleted to calculate size adjustment
    deleted_item = Enum.find(socket.assigns.items, &(&1.id == id))
    
    # Determine which store to delete from based on the item type
    case delete_item(id) do
      :ok ->
        # Remove the item from the list and update the UI
        updated_items = Enum.reject(socket.assigns.items, &(&1.id == id))
        updated_count = socket.assigns.item_count - 1
        updated_size = max(0, socket.assigns.total_size - (deleted_item.size || 0))
        
        socket = assign(socket,
          items: updated_items,
          item_count: updated_count,
          total_size: updated_size,
          show_modal: false,
          selected_item: nil
        )
        
        {:noreply, put_flash(socket, :info, "Item deleted successfully")}
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete item: #{inspect(reason)}")}
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

  @impl true
  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, @tick_interval)
    {:noreply, fetch_dets_data(socket)}
  end

  defp fetch_dets_data(socket) do
    case get_dets_data() do
      {:ok, data} ->
        assign(socket, 
          items: data.items,
          total_size: data.total_size,
          item_count: data.item_count,
          last_updated: data.last_updated,
          error: nil
        )
      
      {:error, reason} ->
        Logger.error("Failed to fetch DETS data: #{inspect(reason)}")
        assign(socket, error: "Failed to fetch DETS data: #{inspect(reason)}")
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

  defp format_item(item) do
    # Add any additional formatting or processing here
    item
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
