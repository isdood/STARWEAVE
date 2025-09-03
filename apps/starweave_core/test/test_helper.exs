# Configure ExUnit
ExUnit.start(
  # Capture logs during tests
  capture_log: true,
  # Show the test that is currently running
  trace: true,
  # Don't print the full stacktrace for expected test failures
  stacktrace: false
)

# Configure logger for tests
:ok = Logger.configure(level: :warning)
:ok = Logger.configure_backend(:console, metadata: [])
