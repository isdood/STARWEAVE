defmodule StarweaveLlm.TextAnalysis do
  @moduledoc """
  Provides text analysis functionality including tokenization, TF-IDF, and BM25 scoring.
  This module serves as the main interface for all text analysis operations.
  """
  
  alias StarweaveLlm.TextAnalysis.TFIDF
  
  @doc """
  Tokenizes the input text into terms, handling common programming language symbols.
  """
  @spec tokenize(String.t()) :: [String.t()]
  defdelegate tokenize(text), to: TFIDF
  
  @doc """
  Calculates TF-IDF scores for terms in a document relative to a corpus.
  
  ## Parameters
    * `document` - The document to score (as a list of terms)
    * `corpus` - A list of documents, where each document is a list of terms
    * `opts` - Options for TF-IDF calculation
      * `:smooth` - Whether to use add-one smoothing (default: true)
      * `:idf_smooth` - Whether to use add-one smoothing for IDF (default: true)
  """
  @spec tf_idf([String.t()], [[String.t()]], keyword()) :: %{String.t() => float()}
  defdelegate tf_idf(document, corpus, opts \\ []), to: TFIDF
  
  @doc """
  Calculates the BM25 score for a document relative to a query and corpus.
  
  ## Parameters
    * `document` - The document to score (as a list of terms)
    * `query_terms` - The search query terms (as a list of terms)
    * `corpus` - A list of documents, where each document is a list of terms
    * `opts` - Options for BM25 calculation
      * `:k1` - BM25 k1 parameter (default: 1.5)
      * `:b` - BM25 b parameter (default: 0.75)
      * `:avgdl` - Average document length (will be calculated if not provided)
  """
  @spec bm25([String.t()], [String.t()], [[String.t()]], keyword()) :: float()
  defdelegate bm25(document, query_terms, corpus, opts \\ []), to: TFIDF
  
  @doc """
  Calculates the cosine similarity between two term vectors.
  """
  @spec cosine_similarity(%{String.t() => number()}, %{String.t() => number()}) :: float()
  defdelegate cosine_similarity(vec1, vec2), to: TFIDF
  
  @doc """
  Extracts the most relevant terms from a document based on TF-IDF scores.
  
  ## Parameters
    * `document` - The document to analyze (as a string or list of terms)
    * `corpus` - The corpus of documents
    * `opts` - Options
      * `:top_n` - Number of top terms to return (default: 10)
      * `:min_term_length` - Minimum term length to consider (default: 2)
      
  ## Returns
  A list of `{term, score}` tuples, sorted by score in descending order
  """
  @spec extract_keywords(String.t() | [String.t()], [[String.t()]], keyword()) :: [{String.t(), float()}]
  def extract_keywords(document, corpus, opts \\ [])
  
  def extract_keywords(document, corpus, opts) when is_binary(document) do
    document
    |> tokenize()
    |> extract_keywords(corpus, opts)
  end
  
  def extract_keywords(document_terms, corpus, opts) when is_list(document_terms) do
    top_n = Keyword.get(opts, :top_n, 10)
    min_length = Keyword.get(opts, :min_term_length, 2)
    
    # Filter out short terms
    filtered_terms = Enum.filter(document_terms, &(String.length(&1) >= min_length))
    
    # Calculate TF-IDF scores
    tfidf_scores = tf_idf(filtered_terms, corpus, opts)
    
    # Sort by score in descending order and take top N
    tfidf_scores
    |> Enum.sort_by(fn {_term, score} -> -score end)
    |> Enum.take(top_n)
  end
  
  @doc """
  Scores documents based on their relevance to the query using BM25.
  
  ## Parameters
    * `documents` - A list of documents, where each document is a map with at least an `:id` and `:content` field
    * `query` - The search query (string)
    * `opts` - Options for BM25 calculation
      
  ## Returns
  A list of `{document, score}` tuples, sorted by score in descending order
  """
  @spec rank_documents([map()], String.t(), keyword()) :: [{map(), float()}]
  def rank_documents(documents, query, opts \\ []) when is_binary(query) do
    # Tokenize the query and documents
    query_terms = tokenize(query)
    
    # Convert documents to a list of token lists for the corpus
    corpus = 
      documents
      |> Enum.map(fn doc -> 
        if is_binary(doc.content) do
          tokenize(doc.content)
        else
          []
        end
      end)
    
    # Score each document using BM25
    documents
    |> Enum.map(fn doc ->
      doc_terms = if is_binary(doc.content), do: tokenize(doc.content), else: []
      score = bm25(doc_terms, query_terms, corpus, opts)
      {doc, score}
    end)
    |> Enum.sort_by(fn {_doc, score} -> -score end)
  end
end
