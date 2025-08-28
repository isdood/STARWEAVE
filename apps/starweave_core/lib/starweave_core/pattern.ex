defmodule StarweaveCore.Pattern do
  @moduledoc """
  Core pattern representation used by the engine.
  """

  @enforce_keys [:id, :data]
  defstruct [
    :id,
    :data,
    metadata: %{},
    energy: 0.0,
    inserted_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          data: String.t(),
          metadata: map(),
          energy: number(),
          inserted_at: integer() | nil
        }
end


