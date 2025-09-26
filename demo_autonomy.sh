#!/bin/bash

# STARWEAVE Autonomy Demonstration Script
# This script demonstrates the novel autonomous capabilities of STARWEAVE

echo "🌌 STARWEAVE Autonomy Demonstration"
echo "====================================="
echo ""

# Check if STARWEAVE is running
if ! pgrep -f "mix phx.server" > /dev/null; then
    echo "❌ STARWEAVE web server is not running."
    echo "   Please start it with: cd apps/starweave_web && mix phx.server"
    echo ""
    echo "   Once running, visit: http://localhost:4000"
    echo "   And the autonomy dashboard at: http://localhost:4000/autonomy"
    exit 1
fi

echo "✅ STARWEAVE is running"
echo ""

# Function to make API calls to demonstrate autonomy
demonstrate_autonomy() {
    echo "🚀 Demonstrating Autonomous Learning Features"
    echo "---------------------------------------------"
    echo ""

    # 1. Trigger a learning cycle
    echo "1️⃣ Triggering autonomous learning cycle..."
    curl -s -X POST http://localhost:4000/api/autonomy/trigger-learning \
         -H "Content-Type: application/json" \
         -d '{}' | jq '.'
    echo ""
    sleep 2

    # 2. Trigger knowledge acquisition
    echo "2️⃣ Triggering knowledge acquisition..."
    curl -s -X POST http://localhost:4000/api/autonomy/trigger-knowledge \
         -H "Content-Type: application/json" \
         -d '{}' | jq '.'
    echo ""
    sleep 2

    # 3. Get autonomy status
    echo "3️⃣ Checking autonomy status..."
    curl -s http://localhost:4000/api/autonomy/status | jq '.'
    echo ""
    sleep 2

    # 4. Demonstrate pattern evolution
    echo "4️⃣ Demonstrating pattern evolution..."
    curl -s -X POST http://localhost:4000/api/patterns/evolve \
         -H "Content-Type: application/json" \
         -d '{"pattern_id": "demo_pattern", "iterations": 3}' | jq '.'
    echo ""
    sleep 2

    # 5. Show memory consolidation
    echo "5️⃣ Demonstrating memory consolidation..."
    curl -s -X POST http://localhost:4000/api/memory/consolidate \
         -H "Content-Type: application/json" \
         -d '{}' | jq '.'
    echo ""
}

# Function to show real-time dashboard
show_dashboard() {
    echo "📊 Real-time Autonomy Dashboard"
    echo "==============================="
    echo ""
    echo "The autonomy dashboard shows:"
    echo "• Continuous learning cycles (every 30 minutes)"
    echo "• Knowledge acquisition (every 6 hours)"
    echo "• Self-reflection (daily)"
    echo "• Active autonomous goals"
    echo "• Pattern evolution metrics"
    echo "• Memory usage and consolidation"
    echo ""
    echo "🌐 Visit: http://localhost:4000/autonomy"
    echo ""
}

# Function to explain novel features
explain_novel_features() {
    echo "✨ STARWEAVE's Novel Capabilities"
    echo "================================="
    echo ""
    echo "🔄 CONTINUOUS AUTONOMOUS LEARNING:"
    echo "   • Learning cycles run every 30 minutes independent of user interaction"
    echo "   • System analyzes patterns and generates insights automatically"
    echo "   • Self-directed goal creation and pursuit"
    echo ""
    echo "📚 KNOWLEDGE ACQUISITION:"
    echo "   • Automated gathering of information from external sources"
    echo "   • Integration of new knowledge into existing pattern systems"
    echo "   • Cross-domain pattern recognition and linking"
    echo ""
    echo "🤔 SELF-REFLECTION:"
    echo "   • Daily analysis of system performance and patterns"
    echo "   • Generation of optimization opportunities"
    echo "   • Autonomous goal creation based on insights"
    echo ""
    echo "🎯 DISTRIBUTED INTELLIGENCE:"
    echo "   • Pattern processing distributed across multiple nodes"
    echo "   • Fault-tolerant memory systems with replication"
    echo "   • Resource-optimized processing based on node capabilities"
    echo ""
    echo "🌌 RESONANCE-BASED PROCESSING:"
    echo "   • Energy-state based pattern recognition"
    echo "   • Resonance field for information integration"
    echo "   • Emergent consciousness through distributed processing"
    echo ""
}

# Function to show comparison with traditional AI
show_comparison() {
    echo "🔍 STARWEAVE vs Traditional AI"
    echo "==============================="
    echo ""
    echo "TRADITIONAL AI:              | STARWEAVE:"
    echo "-----------------------------|-----------------------------"
    echo "❌ User-dependent operation   | ✅ Continuous autonomous operation"
    echo "❌ Static knowledge base      | ✅ Dynamic knowledge acquisition"
    echo "❌ Centralized processing     | ✅ Distributed intelligence"
    echo "❌ Fixed goals and behaviors  | ✅ Self-directed goal evolution"
    echo "❌ Limited self-reflection    | ✅ Comprehensive self-analysis"
    echo "❌ Single-node operation      | ✅ Multi-node fault tolerance"
    echo ""
}

# Main demonstration
case "${1:-demo}" in
    "demo")
        demonstrate_autonomy
        ;;
    "dashboard")
        show_dashboard
        ;;
    "features")
        explain_novel_features
        ;;
    "comparison")
        show_comparison
        ;;
    "all")
        demonstrate_autonomy
        echo ""
        show_dashboard
        echo ""
        explain_novel_features
        echo ""
        show_comparison
        ;;
    *)
        echo "Usage: $0 {demo|dashboard|features|comparison|all}"
        echo ""
        echo "Commands:"
        echo "  demo       - Run autonomy demonstration"
        echo "  dashboard  - Show dashboard information"
        echo "  features   - Explain novel capabilities"
        echo "  comparison - Compare with traditional AI"
        echo "  all        - Run all demonstrations"
        exit 1
        ;;
esac

echo ""
echo "🎉 Demonstration Complete!"
echo ""
echo "Key Takeaways:"
echo "• STARWEAVE operates continuously, independent of user interaction"
echo "• The system learns, evolves, and optimizes itself autonomously"
echo "• Distributed architecture provides fault tolerance and scalability"
echo "• Novel resonance-based processing enables emergent intelligence"
echo ""
echo "Visit http://localhost:4000/autonomy to see it in action!"
echo ""
