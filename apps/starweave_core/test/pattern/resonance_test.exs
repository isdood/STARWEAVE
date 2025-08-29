defmodule StarweaveCore.Pattern.ResonanceTest do
  use ExUnit.Case, async: true
  alias StarweaveCore.Pattern
  alias StarweaveCore.Pattern.Resonance
  
  describe "calculate_resonance/3" do
    test "returns empty list when no patterns match threshold" do
      patterns = [
        %Pattern{id: "1", data: "hello world"},
        %Pattern{id: "2", data: "testing 123"}
      ]
      
      new_pattern = %Pattern{id: "3", data: "completely different"}
      assert [] = Resonance.calculate_resonance(patterns, new_pattern, threshold: 0.5)
    end
    
    test "returns matching patterns above threshold" do
      patterns = [
        %Pattern{id: "1", data: "hello world"},
        %Pattern{id: "2", data: "hello there"},
        %Pattern{id: "3", data: "completely different"}
      ]
      
      new_pattern = %Pattern{id: "4", data: "hello friend"}
      
      result = Resonance.calculate_resonance(patterns, new_pattern, threshold: 0.1)
      assert length(result) == 2
      # Check that both patterns are in the result (order doesn't matter for this test)
      assert Enum.any?(result, fn {_, %Pattern{id: id}} -> id == "1" end)
      assert Enum.any?(result, fn {_, %Pattern{id: id}} -> id == "2" end)
    end
  end
  
  describe "update_energy/3" do
    test "adds new pattern with initial energy" do
      patterns = []
      new_pattern = %Pattern{id: "1", data: "hello world"}
      
      [result] = Resonance.update_energy(patterns, new_pattern)
      assert result.energy > 0
    end
    
    test "increases energy of similar patterns" do
      patterns = [
        %Pattern{id: "1", data: "hello world", energy: 0.5}
      ]
      
      new_pattern = %Pattern{id: "2", data: "hello there"}
      [updated, _] = Resonance.update_energy(patterns, new_pattern)
      
      assert updated.energy > 0.5
    end
    
    test "applies decay to non-matching patterns" do
      patterns = [
        %Pattern{id: "1", data: "hello world", energy: 0.5}
      ]
      
      new_pattern = %Pattern{id: "2", data: "completely different"}
      [_, updated] = Resonance.update_energy(patterns, new_pattern)
      
      assert updated.energy < 0.5
    end
  end
  
  describe "similarity/2" do
    test "returns 1.0 for identical patterns" do
      pattern = %Pattern{id: "1", data: "hello world"}
      assert 1.0 == Resonance.similarity(pattern, pattern)
    end
    
    test "returns 0.0 for completely different patterns" do
      p1 = %Pattern{id: "1", data: "hello world"}
      p2 = %Pattern{id: "2", data: "completely different"}
      assert 0.0 == Resonance.similarity(p1, p2)
    end
    
    test "returns value between 0 and 1 for partial matches" do
      p1 = %Pattern{id: "1", data: "hello world"}
      p2 = %Pattern{id: "2", data: "hello there"}
      similarity = Resonance.similarity(p1, p2)
      assert similarity > 0.0
      assert similarity < 1.0
    end
  end
end
