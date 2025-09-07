defmodule StarweaveWeb.EtsDashboardLive.Index do
  use StarweaveWeb, :live_view
  alias StarweaveCore.Intelligence.WorkingMemory
  require Logger

  @tick_interval 30_000  # 30 seconds

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :tick, @tick_interval)
    end
    socket = assign(socket, current_uri: "/ets-dashboard", last_entry_count: 0)
    {:ok, fetch_data(socket)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _, socket) do
    {:noreply, fetch_data(socket)}
  end

  def handle_event("show_memory", %{"context" => context, "key" => key}, socket) do
    memory = WorkingMemory.retrieve(String.to_atom(context), String.to_atom(key))
    
    details = 
      case memory do
        {:ok, value} ->
          "Context: #{context}\nKey: #{key}\nValue: #{inspect(value, pretty: true)}"
        _ ->
          "Memory not found"
      end
    
    {:noreply, assign(socket, show_modal: true, selected_memory_details: details)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_memory_details: nil)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{last_entry_count: last_count}} = socket) do
    # Only fetch data if the dashboard is actually visible
    if Phoenix.LiveView.connected?(socket) do
      new_socket = fetch_data(socket)
      current_count = new_socket.assigns.stats.total_entries
      
      # Only log if there's a significant change in entry count
      if last_count != 0 and abs(current_count - last_count) > 0 do
        Logger.debug("ETS Dashboard: Entry count changed from #{last_count} to #{current_count}")
      end
      
      Process.send_after(self(), :tick, @tick_interval)
      {:noreply, assign(new_socket, :last_entry_count, current_count)}
    else
      # If the dashboard isn't visible, just reschedule the tick without updating
      Process.send_after(self(), :tick, @tick_interval)
      {:noreply, socket}
    end
  end

  defp fetch_data(socket) do
    # Get the ETS table reference
    table = :starweave_working_memory
    now = DateTime.utc_now()
    last_count = get_in(socket.assigns, [:stats, :total_entries]) || 0
    
    # Initialize default values
    assigns = %{
      stats: %{total_contexts: 0, total_entries: 0},
      memory_entries: [],
      last_updated: format_timestamp(now),
      show_modal: false,
      selected_memory_details: nil,
      current_uri: ""  # Required by LiveView
    }
    
    # Check if the ETS table exists
    case :ets.info(table) do
      :undefined ->
        Logger.warning("ETS table #{inspect(table)} does not exist")
        assign(socket, assigns)
        
      _table_info ->
        # Get all entries from ETS
        entries = 
          :ets.match_object(table, :_)
          |> Enum.map(fn 
            {{context, key}, %{value: value} = meta} -> {context, key, value, meta}
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)
          
        # Only log on first load or when there's a significant change in entries
        current_count = length(entries)
        if last_count == 0 or abs(current_count - last_count) > 0 do
          Logger.debug("ETS entries: #{current_count} (was: #{last_count})")
        end
        
        # Sort entries by timestamp and importance
        sorted_entries = 
          entries
          |> Enum.sort_by(
            fn {_context, _key, _value, %{timestamp: ts, importance: imp}} ->
              DateTime.to_unix(ts) * imp
            end,
            :desc
          )
        
        # Group by context for stats
        entries_by_context = Enum.group_by(sorted_entries, fn {context, _, _, _} -> context end)
        
        # Calculate stats
        stats = %{
          total_entries: length(entries),
          total_contexts: map_size(entries_by_context)
        }
        
        # Update assigns with the new data
        assign(socket, %{
          stats: stats,
          memory_entries: sorted_entries,
          last_updated: format_timestamp(now),
          show_modal: Map.get(socket.assigns, :show_modal, false),
          selected_memory_details: Map.get(socket.assigns, :selected_memory_details, nil),
          current_uri: ""
        })
    end
  end

  defp format_timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  
  defp format_timestamp(_), do: "N/A"
end
