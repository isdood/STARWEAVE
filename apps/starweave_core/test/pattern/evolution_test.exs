defmodule StarweaveCore.Pattern.EvolutionTest do
  use ExUnit.Case, async: true
  alias StarweaveCore.Pattern
  alias StarweaveCore.Pattern.Evolution
  
  describe "evolve/3" do
    test "adds new pattern when no similar patterns exist" do
      patterns = [
        %Pattern{id: "1", data: "hello world", energy: 0.5}
      ]
      
      new_pattern = %Pattern{id: "2", data: "completely different", energy: 0.5}
      result = Evolution.evolve(patterns, new_pattern)
      
      assert length(result) == 2
      assert Enum.any?(result, &(&1.id == "2"))
    end
    
    test "merges similar patterns when similarity is above threshold" do
      patterns = [
        %Pattern{id: "1", data: "hello world", energy: 0.5, metadata: %{use_count: 5}}
      ]
      
      new_pattern = %Pattern{id: "2", data: "hello there", energy: 0.5}
      result = Evolution.evolve(patterns, new_pattern, merge_threshold: 0.3)
      
      assert length(result) == 1
      assert hd(result).id != "1" and hd(result).id != "2"
      assert String.contains?(hd(result).data, "hello")
      assert hd(result).metadata.use_count == 5
    end
  end
  
  describe "merge_similar/2" do
    test "merges identical patterns" do
      patterns = [
        %Pattern{id: "1", data: "hello world", energy: 0.5},
        %Pattern{id: "2", data: "hello world", energy: 0.5}
      ]
      
      result = Evolution.merge_similar(patterns, 0.9)  # High threshold to ensure match
      
      assert length(result) == 1
      assert String.contains?(hd(result).data, "hello world")
      assert hd(result).energy == 0.5  # Average of the two
    end
    
    test "does not merge dissimilar patterns" do
      patterns = [
        %Pattern{id: "1", data: "hello world", energy: 0.5},
        %Pattern{id: "2", data: "completely different", energy: 0.5}
      ]
      
      result = Evolution.merge_similar(patterns, 0.9)  # High threshold
      
      assert length(result) == 2
    end
  end
  
  describe "split_large/2" do
    test "splits large patterns into smaller ones" do
      patterns = [
        %Pattern{id: "1", data: "First sentence. Second sentence. Third sentence.", energy: 0.8}
      ]
      
      result = Evolution.split_large(patterns, 0.9)  # Low threshold to force split
      
      assert length(result) > 1
      assert Enum.all?(result, &(String.length(&1.data) > 0))
    end
    
    test "does not split small, coherent patterns" do
      patterns = [
        %Pattern{id: "1", data: "Short and coherent.", energy: 0.8}
      ]
      
      result = Evolution.split_large(patterns, 0.5)
      
      assert length(result) == 1
      assert hd(result).id == "1"
    end
  end
  
  describe "update_pattern_metadata/2" do
    test "updates metadata for matched pattern" do
      now = System.system_time(:second)
      patterns = [
        %Pattern{id: "1", data: "hello", metadata: %{use_count: 5, last_used: now - 100}},
        %Pattern{id: "2", data: "world", metadata: %{use_count: 1, last_used: now - 200}}
      ]
      
      updated = Evolution.update_pattern_metadata(patterns, %Pattern{id: "1", data: "hello"})
      
      assert length(updated) == 2
      updated_1 = Enum.find(updated, &(&1.id == "1"))
      assert updated_1.metadata.use_count == 6
      assert updated_1.metadata.last_used > now - 10  # Should be very recent
      
      # Other pattern should be unchanged
      updated_2 = Enum.find(updated, &(&1.id == "2"))
      assert updated_2.metadata.use_count == 1
    end
  end
end
