PROTOC_GEN_ELIXIR := $(shell which protoc-gen-elixir)

.PHONY: protobuf

protobuf:
	@echo "Generating Elixir code from protobuf..."
	@mkdir -p lib/starweave_llm/image_generation/generated
	@protoc --elixir_out=plugins=grpc:./lib/starweave_llm/image_generation/generated \
	  -I./lib/starweave_llm/image_generation/protos \
	  -I$(MIX_DEPS_PATH)/google_protos/priv/protos \
	  google/protobuf/timestamp.proto \
	  lib/starweave_llm/image_generation/protos/starweave.proto
	@echo "Protobuf files generated in lib/starweave_llm/image_generation/generated"
