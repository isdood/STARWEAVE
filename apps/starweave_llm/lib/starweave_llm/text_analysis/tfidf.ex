defmodule StarweaveLlm.TextAnalysis.TFIDF do
  @moduledoc """
  Implements TF-IDF (Term Frequency-Inverse Document Frequency) and BM25 scoring
  for text documents to improve search relevance.
  
  TF-IDF is a numerical statistic that reflects how important a word is to a document
  in a collection or corpus. BM25 is a ranking function used by search engines to rank
  matching documents according to their relevance to a given search query.
  """
  
  @doc """
  Calculates the TF-IDF scores for terms in a document relative to a corpus.
  
  ## Parameters
    * `document` - The document to score (as a list of terms)
    * `corpus` - A list of documents, where each document is a list of terms
    * `options` - Options for TF-IDF calculation
      * `:smooth` - Whether to use add-one smoothing (default: true)
      * `:idf_smooth` - Whether to use add-one smoothing for IDF (default: true)
      
  ## Returns
  A map of terms to their TF-IDF scores for the document
  """
  @spec tf_idf([String.t()], [[String.t()]], keyword()) :: %{String.t() => float()}
  def tf_idf(document, corpus, options \\ []) do
    smooth = Keyword.get(options, :smooth, true)
    idf_smooth = Keyword.get(options, :idf_smooth, true)
    
    document
    |> Enum.frequencies()
    |> Enum.into(%{}, fn {term, count} ->
      tf_value = tf(count, document, smooth: smooth)
      idf_value = idf(term, corpus, smooth: idf_smooth)
      {term, tf_value * idf_value}
    end)
  end
  
  @doc """
  Calculates the BM25 score for a document relative to a query and corpus.
  
  ## Parameters
    * `document` - The document to score (as a list of terms)
    * `query_terms` - The search query terms (as a list of terms)
    * `corpus` - A list of documents, where each document is a list of terms
    * `options` - Options for BM25 calculation
      * `:k1` - BM25 k1 parameter (default: 1.5)
      * `:b` - BM25 b parameter (default: 0.75)
      * `:avgdl` - Average document length (will be calculated if not provided)
      
  ## Returns
  The BM25 score for the document
  """
  @spec bm25([String.t()], [String.t()], [[String.t()]], keyword()) :: float()
  def bm25(document, query_terms, corpus, options \\ []) do
    k1 = Keyword.get(options, :k1, 1.5)
    b = Keyword.get(options, :b, 0.75)
    avgdl = Keyword.get_lazy(options, :avgdl, fn -> avg_document_length(corpus) end)
    
    doc_length = length(document)
    doc_freqs = Enum.frequencies(document)
    
    query_terms
    |> Enum.uniq()
    |> Enum.reduce(0, fn term, score ->
      tf = (doc_freqs[term] || 0)
      idf_val = idf(term, corpus, smooth: true)
      
      # BM25 term weight calculation
      numerator = tf * (k1 + 1)
      denominator = tf + k1 * (1 - b + b * (doc_length / avgdl))
      
      if denominator > 0 do
        score + idf_val * (numerator / denominator)
      else
        score
      end
    end)
  end
  
  @doc """
  Calculates the average document length in a corpus.
  """
  @spec avg_document_length([[String.t()]]) :: float()
  def avg_document_length(corpus) do
    total_length = Enum.reduce(corpus, 0, &(&2 + length(&1)))
    total_length / max(1, length(corpus))
  end
  
  # Private helper functions
  
  # Term Frequency (TF) calculation
  defp tf(term_count, document, smooth: true) do
    (term_count + 1) / (length(document) + 1)
  end
  
  defp tf(term_count, document, smooth: false) do
    term_count / length(document)
  end
  
  # Inverse Document Frequency (IDF) calculation
  defp idf(term, corpus, smooth: true) do
    n = length(Enum.filter(corpus, &(term in &1)))
    :math.log((length(corpus) + 1) / (n + 1))
  end
  
  defp idf(term, corpus, smooth: false) do
    n = length(Enum.filter(corpus, &(term in &1)))
    if n > 0, do: :math.log(length(corpus) / n), else: 0.0
  end
  
  @doc """
  Tokenizes a string into terms, handling common programming language symbols.
  """
  @spec tokenize(String.t()) :: [String.t()]
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    # Split on word boundaries, keeping common programming symbols as separate tokens
    |> String.split(~r/(?<=\w)(?=[^\w])|(?<=[^\w])(?=\w)|\s+/u, trim: true)
    # Remove any remaining non-word characters (except _)
    |> Enum.map(&String.replace(&1, ~r/^[^\w_]+|[^\w_]+$/u, ""))
    |> Enum.reject(&(&1 == ""))
  end
  
  @doc """
  Calculates the cosine similarity between two term vectors.
  """
  @spec cosine_similarity(%{String.t() => number()}, %{String.t() => number()}) :: float()
  def cosine_similarity(vec1, vec2) do
    dot_product = fn ->
      MapSet.intersection(MapSet.new(Map.keys(vec1)), MapSet.new(Map.keys(vec2)))
      |> Enum.reduce(0, fn k, acc -> acc + vec1[k] * vec2[k] end)
    end
    
    magnitude = fn vec ->
      :math.sqrt(Enum.reduce(vec, 0, fn {_, v}, acc -> acc + :math.pow(v, 2) end))
    end
    
    mag1 = magnitude.(vec1)
    mag2 = magnitude.(vec2)
    
    if mag1 > 0.0 and mag2 > 0.0 do
      dot_product.() / (mag1 * mag2)
    else
      0.0
    end
  end
end
