defmodule StarweaveLlm.MemoryIntegrationTest do
  use ExUnit.Case, async: true
  alias StarweaveLlm.MemoryIntegration
  alias StarweaveCore.Pattern
  alias StarweaveCore.PatternStore

  setup do
    # Clear the pattern store before each test
    PatternStore.clear()
    :ok
  end

  describe "retrieve_memories/1" do
    test "retrieves relevant memories based on query" do
      # Add some test patterns
      pattern1 = %Pattern{
        id: "test1",
        data: "Weather is sunny today",
        metadata: %{type: "memory"},
        energy: 1.0,
        inserted_at: System.system_time(:millisecond)
      }
      
      pattern2 = %Pattern{
        id: "test2", 
        data: "Temperature is 25 degrees",
        metadata: %{type: "memory"},
        energy: 1.0,
        inserted_at: System.system_time(:millisecond)
      }
      
      :ok = PatternStore.put(pattern1.id, pattern1)
      :ok = PatternStore.put(pattern2.id, pattern2)
      
      query = %{
        query: "weather",
        limit: 5,
        min_relevance: 0.3
      }
      
      memories = MemoryIntegration.retrieve_memories(query)
      
      assert length(memories) > 0
      assert hd(memories).content =~ "Weather"
    end

    test "respects limit parameter" do
      # Add multiple patterns
      for i <- 1..10 do
        pattern = %Pattern{
          id: "test#{i}",
          data: "Test memory #{i}",
          metadata: %{type: "memory"},
          energy: 1.0,
          inserted_at: System.system_time(:millisecond)
        }
        :ok = PatternStore.put(pattern.id, pattern)
      end
      
      query = %{
        query: "test",
        limit: 3,
        min_relevance: 0.1
      }
      
      memories = MemoryIntegration.retrieve_memories(query)
      assert length(memories) == 3
    end

    test "filters by minimum relevance" do
      pattern = %Pattern{
        id: "test1",
        data: "Completely unrelated content",
        metadata: %{type: "memory"},
        energy: 1.0,
        inserted_at: System.system_time(:millisecond)
      }
      
              :ok = PatternStore.put(pattern.id, pattern)
      
      query = %{
        query: "weather",
        limit: 5,
        min_relevance: 0.5
      }
      
      memories = MemoryIntegration.retrieve_memories(query)
      assert memories == []
    end
  end

  describe "consolidate_memories/1" do
    test "handles empty memory list" do
      result = MemoryIntegration.consolidate_memories([])
      assert result == "No relevant memories found."
    end

    test "handles single memory" do
      memory =         %{
          id: "test1",
          content: "Weather is sunny",
          relevance_score: 0.8,
          timestamp: DateTime.from_unix!(System.system_time(:millisecond), :millisecond),
          pattern_data: %{}
        }
      
      result = MemoryIntegration.consolidate_memories([memory])
      assert result =~ "Weather is sunny"
    end

    test "consolidates multiple memories by relevance" do
      timestamp = DateTime.from_unix!(System.system_time(:millisecond), :millisecond)
      memories = [
        %{
          id: "high1",
          content: "Highly relevant memory 1",
          relevance_score: 0.9,
          timestamp: timestamp,
          pattern_data: %{}
        },
        %{
          id: "high2", 
          content: "Highly relevant memory 2",
          relevance_score: 0.85,
          timestamp: timestamp,
          pattern_data: %{}
        },
        %{
          id: "medium1",
          content: "Medium relevance memory",
          relevance_score: 0.6,
          timestamp: timestamp,
          pattern_data: %{}
        },
        %{
          id: "low1",
          content: "Low relevance memory",
          relevance_score: 0.3,
          timestamp: timestamp,
          pattern_data: %{}
        }
      ]
      
      result = MemoryIntegration.consolidate_memories(memories)
      
      assert result =~ "Highly relevant"
      assert result =~ "Related"
      assert result =~ "Highly relevant memory 1"
      assert result =~ "Medium relevance memory"
    end
  end

  describe "store_memory/2" do
    test "stores memory with default metadata" do
      content = "Test memory content"
      
      assert {:ok, memory_id} = MemoryIntegration.store_memory(content)
      assert is_binary(memory_id)
      assert String.starts_with?(memory_id, "memory_")
    end

    test "stores memory with custom metadata" do
      content = "Test memory content"
      metadata = %{source: "test", priority: "high"}
      
      assert {:ok, memory_id} = MemoryIntegration.store_memory(content, metadata)
      
      # Verify the pattern was stored
      pattern = PatternStore.get(memory_id)
      assert pattern != nil
      assert pattern.data == content
      assert pattern.metadata.source == "test"
      assert pattern.metadata.priority == "high"
      assert pattern.metadata.type == "memory"
    end
  end

  describe "update_memory_energy/2" do
    test "updates memory energy" do
      # Store a memory first
      {:ok, memory_id} = MemoryIntegration.store_memory("Test content")
      
      # Update its energy
      assert :ok = MemoryIntegration.update_memory_energy(memory_id, 2.5)
      
      # Verify the update
      pattern = PatternStore.get(memory_id)
      assert pattern.energy == 2.5
    end

    test "handles non-existent memory" do
      result = MemoryIntegration.update_memory_energy("nonexistent", 1.0)
      assert {:error, :memory_not_found} = result
    end
  end

  describe "search_memories/2" do
    test "performs comprehensive memory search" do
      # Add test patterns
      pattern1 = %Pattern{
        id: "test1",
        data: "Weather is sunny today",
        metadata: %{type: "memory"},
        energy: 1.0,
        inserted_at: System.system_time(:millisecond)
      }
      
      pattern2 = %Pattern{
        id: "test2",
        data: "Temperature is 25 degrees",
        metadata: %{type: "memory"},
        energy: 1.0,
        inserted_at: System.system_time(:millisecond)
      }
      
      :ok = PatternStore.put(pattern1.id, pattern1)
      :ok = PatternStore.put(pattern2.id, pattern2)
      
      memories = MemoryIntegration.search_memories("weather", limit: 5, min_relevance: 0.3)
      
      assert length(memories) > 0
      assert hd(memories).content =~ "Weather"
    end

    test "respects search options" do
      # Add multiple patterns
      for i <- 1..10 do
        pattern = %Pattern{
          id: "test#{i}",
          data: "Test memory #{i}",
          metadata: %{type: "memory"},
          energy: 1.0,
          inserted_at: System.system_time(:millisecond)
        }
        :ok = PatternStore.put(pattern.id, pattern)
      end
      
      memories = MemoryIntegration.search_memories("test", limit: 3, min_relevance: 0.1)
      assert length(memories) == 3
    end
  end
end
