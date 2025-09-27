#!/bin/bash

# STARWEAVE Autonomous System Startup Script
# This script initializes the complete autonomous intelligence system

echo "🌌 STARWEAVE Autonomous Intelligence System"
echo "=========================================="
echo ""

# Function to check if a process is running
is_running() {
    pgrep -f "$1" > /dev/null
}

# Function to start a component if not already running
start_component() {
    local component_name="$1"
    local start_command="$2"

    if ! is_running "$component_name"; then
        echo "🚀 Starting $component_name..."
        eval "$start_command"
        sleep 2
    else
        echo "✅ $component_name already running"
    fi
}

# Function to wait for component to be ready
wait_for_component() {
    local component_name="$1"
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if is_running "$component_name"; then
            echo "✅ $component_name is ready"
            return 0
        fi

        echo "⏳ Waiting for $component_name (attempt $attempt/$max_attempts)..."
        sleep 3
        attempt=$((attempt + 1))
    done

    echo "❌ $component_name failed to start"
    return 1
}

echo "📋 Checking prerequisites..."
echo ""

# Check if Elixir/Mix is available
if ! command -v mix &> /dev/null; then
    echo "❌ Mix (Elixir) is not installed or not in PATH"
    exit 1
fi

# Check if STARWEAVE directory exists
if [ ! -d "/home/isdood/STARWEAVE" ]; then
    echo "❌ STARWEAVE directory not found at /home/isdood/STARWEAVE"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Change to STARWEAVE directory
cd /home/isdood/STARWEAVE

# Start the web application first
echo "🌐 Starting STARWEAVE Web Application..."
echo ""

start_component "mix phx.server" "cd apps/starweave_web && mix phx.server"

if ! wait_for_component "mix phx.server"; then
    echo "❌ Failed to start web application"
    exit 1
fi

echo ""
echo "🤖 Starting Individual Autonomous Components..."
echo ""

# Start the learning orchestrator
start_component "StarweaveCore.Autonomous.LearningOrchestrator" \
    "elixir --name learning@127.0.0.1 --cookie starweave -S mix run -e 'StarweaveCore.Autonomous.LearningOrchestrator.start_link(); :timer.sleep(:infinity)'"

# Start the web knowledge acquirer
start_component "StarweaveCore.Autonomous.WebKnowledgeAcquirer" \
    "elixir --name knowledge@127.0.0.1 --cookie starweave -S mix run -e 'StarweaveCore.Autonomous.WebKnowledgeAcquirer.start_link(); :timer.sleep(:infinity)'"

# Start the self-modification agent
start_component "StarweaveCore.Autonomous.SelfModificationAgent" \
    "elixir --name modification@127.0.0.1 --cookie starweave -S mix run -e 'StarweaveCore.Autonomous.SelfModificationAgent.start_link(); :timer.sleep(:infinity)'"

echo ""
echo "🎯 Starting Autonomous System Integrator..."
echo ""

# Start the autonomous system integrator (coordinates everything)
start_component "StarweaveCore.Autonomous.SystemIntegrator" \
    "cd apps/starweave_core && elixir --name starweave@127.0.0.1 --cookie starweave -S mix run -e 'StarweaveCore.Autonomous.SystemIntegrator.start_link(); :timer.sleep(:infinity)'"

if ! wait_for_component "StarweaveCore.Autonomous.SystemIntegrator"; then
    echo "❌ Failed to start system integrator"
    exit 1
fi

echo ""
echo "🔗 Initializing Autonomous System Integration..."
echo ""

# Initialize the integrated autonomous system
if elixir --name integration@127.0.0.1 --cookie starweave -e "
  {:ok, _} = Node.start(:integration@127.0.0.1)
  Node.set_cookie(:starweave)
  Node.connect(:starweave@127.0.0.1)

  # Wait for nodes to connect
  :timer.sleep(2000)

  # Start the system integrator
  case StarweaveCore.Autonomous.SystemIntegrator.start_autonomous_system() do
    {:ok, message} ->
      IO.puts(\"✅ Autonomous system integration: \#{message}\")
    {:error, reason} ->
      IO.puts(\"❌ Failed to start autonomous system: \#{reason}\")
      System.halt(1)
  end
"; then
    echo "✅ Autonomous system integration completed"
else
    echo "❌ Failed to initialize autonomous system integration"
    exit 1
fi

echo ""
echo "🎉 STARWEAVE Autonomous Intelligence System Started!"
echo ""
echo "🌐 Web Interface: http://localhost:4000"
echo "📊 Autonomy Dashboard: http://localhost:4000/autonomy"
echo ""
echo "🔄 The system will now:"
echo "   • Learn autonomously every 30 minutes"
echo "   • Acquire new knowledge every 6 hours"
echo "   • Perform self-reflection daily"
echo "   • Create tools to achieve autonomous goals"
echo "   • Evolve patterns and optimize performance"
echo ""
echo "📈 Monitor progress at: http://localhost:4000/autonomy"
echo ""
echo "To stop the system:"
echo "   Press Ctrl+C or run: pkill -f 'mix\|elixir'"
echo ""

# Keep the script running to show status
echo "🔍 System Status:"
echo "================="

# Show running processes
echo ""
echo "Active Processes:"
ps aux | grep -E "(mix|elixir|starweave)" | grep -v grep | head -10

echo ""
echo "✅ System startup complete!"
echo "Visit http://localhost:4000/autonomy to see autonomous intelligence in action!"
echo ""

# Keep script alive to monitor system
while true; do
    sleep 60

    # Check if key processes are still running
    if ! is_running "mix phx.server"; then
        echo "❌ Web server stopped. Restarting system..."
        exit 1
    fi

    if ! is_running "StarweaveCore.Autonomous.SystemIntegrator"; then
        echo "❌ System integrator stopped. Restarting autonomous system..."
        exit 1
    fi
done
