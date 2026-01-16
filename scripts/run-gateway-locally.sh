#!/bin/bash
set -e

# Run LLM Gateway locally with mirrord
# This script demonstrates the fast iteration workflow from the blog post

echo "🔄 Running LLM Gateway locally with mirrord..."
echo ""
echo "This will:"
echo "  1. Mirror traffic from the in-cluster llm-gateway to your local process"
echo "  2. Allow you to edit llm-gateway/config.yaml and restart instantly"
echo "  3. Enable fast policy iteration without rebuilding containers"
echo ""

# Check if mirrord is installed
if ! command -v mirrord &> /dev/null; then
  echo "❌ mirrord is not installed"
  echo ""
  echo "Install mirrord:"
  echo "  macOS: brew install metalbear-co/mirrord/mirrord"
  echo "  Linux: curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash"
  echo ""
  exit 1
fi

# Check if the llm-gateway deployment exists
if ! kubectl get deployment llm-gateway -n llm-gateway &> /dev/null; then
  echo "⚠️  LLM Gateway is not deployed to the cluster"
  echo ""
  echo "Deploy it first:"
  echo "  ./scripts/deploy-step3-gateway.sh"
  echo ""
  exit 1
fi

# Check if Python dependencies are installed
if ! python3 -c "import fastapi" 2>/dev/null; then
  echo "📦 Installing Python dependencies..."
  cd llm-gateway
  pip install -r requirements.txt
  cd ..
fi

echo "✅ Prerequisites met"
echo ""
echo "Starting local gateway with mirrord..."
echo "Traffic from Open WebUI will now be mirrored to your local process"
echo ""
echo "To test policy changes:"
echo "  1. Edit llm-gateway/config.yaml"
echo "  2. Press Ctrl+C to stop the process"
echo "  3. Run this script again to restart with new config"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Change to llm-gateway directory and run with mirrord
cd llm-gateway
mirrord exec -f ../mirrord/config.json -- python3 -m app.main
