defmodule Starweave.Pattern.MetadataEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Starweave.Pattern do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :id, 1, type: :string
  field :data, 2, type: :bytes
  field :metadata, 3, repeated: true, type: Starweave.Pattern.MetadataEntry, map: true
  field :timestamp, 4, type: :double
end

defmodule Starweave.PatternRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :pattern, 1, type: Starweave.Pattern
  field :context, 2, repeated: true, type: :string
end

defmodule Starweave.PatternResponse.ConfidencesEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :float
end

defmodule Starweave.PatternResponse.MetadataEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Starweave.PatternResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :request_id, 1, type: :string, json_name: "requestId"
  field :labels, 2, repeated: true, type: :string

  field :confidences, 3,
    repeated: true,
    type: Starweave.PatternResponse.ConfidencesEntry,
    map: true

  field :error, 4, type: :string
  field :metadata, 5, repeated: true, type: Starweave.PatternResponse.MetadataEntry, map: true
end

defmodule Starweave.StatusRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :detailed, 1, type: :bool
end

defmodule Starweave.StatusResponse.MetricsEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Starweave.StatusResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :status, 1, type: :string
  field :version, 2, type: :string
  field :uptime, 3, type: :int64
  field :metrics, 4, repeated: true, type: Starweave.StatusResponse.MetricsEntry, map: true
end

defmodule Starweave.PatternService.Service do
  @moduledoc false

  use GRPC.Service, name: "starweave.PatternService", protoc_gen_elixir_version: "0.15.0"

  rpc :RecognizePattern, Starweave.PatternRequest, Starweave.PatternResponse

  rpc :StreamPatterns, stream(Starweave.PatternRequest), stream(Starweave.PatternResponse)

  rpc :GetStatus, Starweave.StatusRequest, Starweave.StatusResponse
end

defmodule Starweave.PatternService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Starweave.PatternService.Service
end
