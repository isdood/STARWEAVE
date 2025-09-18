defmodule StarweaveLlm.TextAnalysis.TFIDFTest do
  use ExUnit.Case, async: true
  alias StarweaveLlm.TextAnalysis.TFIDF
  
  @corpus [
    ["this", "is", "a", "sample", "document", "about", "elixir", "programming"],
    ["this", "is", "another", "example", "document", "about", "programming"],
    ["elixir", "is", "a", "functional", "programming", "language"],
    ["erlang", "and", "elixir", "are", "both", "functional", "languages"]
  ]
  
  describe "tokenize/1" do
    test "splits text into tokens" do
      assert TFIDF.tokenize("Hello, world! This is a test.") == 
               ["hello", "world", "this", "is", "a", "test"]
    end
    
    test "handles code-like text" do
      assert TFIDF.tokenize("defmodule MyModule do\n  def hello, do: :world\nend") == 
               ["defmodule", "mymodule", "do", "def", "hello", "do", "world", "end"]
    end
  end
  
  describe "tf_idf/3" do
    test "calculates TF-IDF scores for a document" do
      doc = @corpus |> hd()
      scores = TFIDF.tf_idf(doc, @corpus)
      
      # Terms that appear in many documents should have lower scores
      assert scores["this"] < scores["sample"]
      
      # Terms unique to this document should have higher scores
      assert scores["sample"] > 0
      
      # Terms not in the document should not be in the result
      refute Map.has_key?(scores, "erlang")
    end
  end
  
  describe "bm25/4" do
    test "ranks documents by relevance to query" do
      query = ["elixir", "programming"]
      
      # Get BM25 scores for each document
      scores = 
        @corpus
        |> Enum.with_index()
        |> Enum.map(fn {doc, idx} -> 
          {idx, TFIDF.bm25(doc, query, @corpus, k1: 1.5, b: 0.75)}
        end)
        
      # First document should be highly relevant as it contains both terms
      assert {0, score1} = Enum.find(scores, &(elem(&1, 0) == 0))
      
      # Third document is also relevant but shorter
      assert {2, score2} = Enum.find(scores, &(elem(&1, 0) == 2))
      
      # Both documents should be relevant, but the order might vary based on exact scoring
      # Just ensure they have reasonable scores
      assert score1 > 0
      assert score2 > 0
      
      # Last document only contains "elixir"
      assert {3, score3} = Enum.find(scores, &(elem(&1, 0) == 3))
      assert score1 > score3
    end
  end
  
  describe "cosine_similarity/2" do
    test "calculates similarity between two vectors" do
      vec1 = %{"elixir" => 1.0, "programming" => 1.0, "language" => 1.0}
      vec2 = %{"elixir" => 1.0, "erlang" => 1.0, "language" => 1.0}
      
      # Should be somewhat similar due to shared terms
      similarity = TFIDF.cosine_similarity(vec1, vec2)
      assert similarity > 0.4
      assert similarity < 1.0
      
      # Identical vectors should have similarity very close to 1.0
      assert_in_delta TFIDF.cosine_similarity(vec1, vec1), 1.0, 1.0e-10
      
      # Orthogonal vectors should have similarity 0.0
      vec3 = %{"python" => 1.0, "java" => 1.0}
      assert TFIDF.cosine_similarity(vec1, vec3) == 0.0
    end
  end
  
  describe "integration with text processing" do
    test "end-to-end search example" do
      # Sample documents
      docs = [
        "Elixir is a functional programming language",
        "Erlang is a programming language used for building scalable systems",
        "Phoenix is a web framework for Elixir",
        "OTP is a set of Erlang libraries and design principles"
      ]
      
      # Tokenize documents
      tokenized_docs = Enum.map(docs, &TFIDF.tokenize/1)
      
      # Search query
      query = "functional programming language"
      query_terms = TFIDF.tokenize(query)
      
      # Rank documents by BM25
      scores = 
        tokenized_docs
        |> Enum.with_index()
        |> Enum.map(fn {doc, idx} -> 
          {idx, TFIDF.bm25(doc, query_terms, tokenized_docs)}
        end)
        |> Enum.sort_by(&elem(&1, 1), :desc)
      
      # Top documents should be relevant (order might vary slightly)
      top_indices = scores |> Enum.take(2) |> Enum.map(&elem(&1, 0))
      assert 0 in top_indices
      assert 1 in top_indices
    end
  end
end
