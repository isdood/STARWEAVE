# Test Issues Report

## Current Test Failures (as of 2025-09-19)

### QueryService Tests
- **File**: `test/starweave_llm/llm/query_service_test.exs`
- **Issues**:
  1. `test query/3 with conversation history includes conversation history in the prompt`
     - Expected: List
     - Actual: String
     - Error: Expected truthy, got false
     - Line: 325

  2. `test hybrid search functionality combines semantic and keyword search results`
     - Expected: List
     - Actual: String
     - Error: Expected truthy, got false
     - Line: 178

  3. `test query/3 handles empty search results gracefully`
     - Expected: List
     - Actual: Empty string
     - Error: Expected truthy, got false
     - Line: 292

### Warnings
1. **Redefining Modules**:
   - `StarweaveWeb.ConnCase`
   - `StarweaveWeb.GRPCCase`

2. **Unused Aliases**:
   - `PatternResponse` in `test/grpc/pattern_client_unit_test.exs`
   - `StatusResponse` in `test/grpc/pattern_client_unit_test.exs`

3. **Skipped Tests**:
   - `test handles server unavailability gracefully` in `test/starweave_web/grpc/pattern_client_test.exs`

## Notes
- These issues appear unrelated to recent changes in the WorkingMemory implementation
- The main issue seems to be with the return type of QueryService functions, where strings are being returned instead of lists
- Some tests are being skipped and should be addressed in a future update

## Next Steps
1. Investigate QueryService return types
2. Fix the return values to match test expectations
3. Address the skipped tests
4. Clean up unused aliases
5. Resolve module redefinition warnings

## Next Steps

## Fix Task Distributor:
- Address process registration issues
- Ensure proper task distribution and status tracking

## Update Tests:
- Make tests more resilient to timing issues
- Add proper cleanup between tests
- Ensure proper test isolation