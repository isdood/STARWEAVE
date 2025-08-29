defmodule StarweaveCore.Pattern.TemporalTest do
  use ExUnit.Case, async: true
  alias StarweaveCore.Pattern
  alias StarweaveCore.Pattern.Temporal
  
  describe "detect_sequence/2" do
    test "returns empty list for empty input" do
      assert [] == Temporal.detect_sequence([])
    end
    
    test "detects sequences in ordered patterns" do
      patterns = [
        %Pattern{id: "1", data: "start", inserted_at: 1000},
        %Pattern{id: "2", data: "middle", inserted_at: 2000},
        %Pattern{id: "3", data: "end", inserted_at: 3000}
      ]
      
      result = Temporal.detect_sequence(patterns, window_size: 3)
      assert length(result) > 0
      assert Enum.any?(result, fn seq -> 
        length(seq) == 3 && 
        Enum.map(seq, & &1.id) == ["1", "2", "3"]
      end)
    end
    
    test "respects window size" do
      patterns = [
        %Pattern{id: "1", data: "a", inserted_at: 1000},
        %Pattern{id: "2", data: "b", inserted_at: 2000},
        %Pattern{id: "3", data: "c", inserted_at: 3000}
      ]
      
      result = Temporal.detect_sequence(patterns, window_size: 2)
      assert length(result) == 2
      assert Enum.any?(result, &(length(&1) == 2))
    end
  end
  
  describe "analyze_relationship/2" do
    test "analyzes temporal relationship between patterns" do
      p1 = %Pattern{id: "1", data: "hello", inserted_at: 1000}
      p2 = %Pattern{id: "2", data: "world", inserted_at: 2000}
      
      result = Temporal.analyze_relationship(p1, p2)
      
      assert result.time_diff == 1000
      assert result.order == :before
      assert is_float(result.similarity)
    end
  end
  
  describe "find_recurring_sequences/2" do
    test "finds recurring sequences" do
      patterns = [
        %Pattern{id: "1", data: "a", inserted_at: 1000},
        %Pattern{id: "2", data: "b", inserted_at: 2000},
        %Pattern{id: "3", data: "a", inserted_at: 3000},
        %Pattern{id: "4", data: "b", inserted_at: 4000}
      ]
      
      result = Temporal.find_recurring_sequences(patterns, 2)
      assert length(result) > 0
      
      # Should find the [a, b] sequence
      assert Enum.any?(result, fn seq ->
        Enum.map(seq, & &1.id) == ["1", "2"] ||
        Enum.map(seq, & &1.id) == ["3", "4"]
      end)
    end
    
    test "respects minimum sequence length" do
      patterns = [
        %Pattern{id: "1", data: "a", inserted_at: 1000},
        %Pattern{id: "2", data: "b", inserted_at: 2000},
        %Pattern{id: "3", data: "a", inserted_at: 3000},
        %Pattern{id: "4", data: "b", inserted_at: 4000}
      ]
      
      # Should find sequences of length 2
      result = Temporal.find_recurring_sequences(patterns, 2)
      assert length(result) > 0
      assert Enum.all?(result, &(length(&1) >= 2))
      
      # For min_length=3, we should get sequences of at least length 3
      result = Temporal.find_recurring_sequences(patterns, 3)
      assert Enum.all?(result, &(length(&1) >= 3))
    end
  end
end
