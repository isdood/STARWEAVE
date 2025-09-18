# Test Issues Report

This document outlines the current test failures and issues in the STARWEAVE project, organized by component.

## StarweaveLLM Tests

### Ollama Integration Tests
- **File**: `test/starweave_llm/llm/ollama_integration_test.exs`
- **Status**: 7 failures, 5 skipped
- **Issues**:
  - Tests are being skipped due to missing setup or configuration
  - Expected ExUnit setup callback to return `:ok` but got `:skip`
  - Likely related to missing Ollama service or configuration

### Query Service Tests
- **File**: `test/starweave_llm/llm/query_service_test.exs`
- **Status**: Passing
- **Notes**: All tests are currently passing

### BM25 Integration Tests
- **File**: `test/starweave_llm/llm/query_service_bm25_test.exs`
- **Status**: Multiple tests skipped
- **Issues**:
  - Hybrid search tests with BM25 are currently skipped
  - BM25 search integration tests are not running

## StarweaveWeb Tests

### GRPC Client Tests
- **File**: `test/starweave_web/grpc/grpc_client_test.exs`
- **Status**: Passing
- **Notes**: All tests are currently passing

### Pattern Client Tests
- **File**: `test/starweave_web/grpc/pattern_client_test.exs`
- **Status**: 1 test skipped
- **Skipped Test**: "handles server unavailability gracefully"

### Controller Tests
- **Files**:
  - `test/starweave_web/controllers/error_html_test.exs`
  - `test/starweave_web/controllers/error_json_test.exs`
  - `test/starweave_web/controllers/page_controller_test.exs`
- **Status**: All passing

## Known Issues and Warnings

### GRPC Deprecation Warning
- **File**: `lib/starweave_web/grpc/starweave.pb.ex`
- **Issue**: Deprecation warning about using map.field notation
- **Impact**: Warning only, doesn't affect test results
- **Recommended Action**: Update protobuf compiler in a future task

### Unused Aliases
- **File**: `test/grpc/pattern_client_unit_test.exs`
- **Issue**: Unused aliases `PatternResponse` and `StatusResponse`
- **Impact**: Warning only, doesn't affect test results
- **Recommended Action**: Remove unused aliases

## Next Steps

### High Priority
1. Investigate and fix Ollama integration test failures
2. Enable and fix skipped BM25 integration tests
3. Implement the skipped server unavailability test for PatternClient

### Medium Priority
1. Update protobuf compiler to address GRPC deprecation warning
2. Clean up unused aliases in test files
3. Document any test environment requirements (e.g., Ollama service)

### Low Priority
1. Add more test coverage for error cases
2. Document test setup requirements in README
3. Consider adding CI/CD pipeline for automated testing
