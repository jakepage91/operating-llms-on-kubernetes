#!/bin/bash
set -e

echo "🔧 Setting up local development environment..."
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+ first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install npm first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Check mirrord
if ! command -v mirrord &> /dev/null; then
    echo "⚠️  mirrord not found. Installing..."
    curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash
    echo "✅ mirrord installed"
else
    echo "✅ mirrord already installed"
fi
echo ""

# Install backend dependencies
echo "📦 Installing restaurant-app backend dependencies..."
cd restaurant-app/backend
npm install
cd ../..
echo "✅ Backend dependencies installed"
echo ""

# Install frontend dependencies
echo "📦 Installing restaurant-app frontend dependencies..."
cd restaurant-app/frontend
npm install
cd ../..
echo "✅ Frontend dependencies installed"
echo ""

# Check cluster access
echo "🔍 Checking Kubernetes cluster access..."
if kubectl auth can-i get pods -n llm &> /dev/null; then
    echo "✅ Cluster access confirmed"
else
    echo "⚠️  Cannot access cluster. Ensure you have kubectl configured."
fi
echo ""

# Check Ollama deployment
echo "🔍 Checking Ollama deployment..."
if kubectl get deployment -n llm ollama &> /dev/null; then
    echo "✅ Ollama deployment found"
    POD_STATUS=$(kubectl get pods -n llm -l app=ollama -o jsonpath='{.items[0].status.phase}')
    echo "   Pod status: ${POD_STATUS}"

    if [ "${POD_STATUS}" != "Running" ]; then
        echo "⚠️  Ollama pod is not running. Deploy with: ./scripts/deploy-ollama.sh"
    fi
else
    echo "⚠️  Ollama not deployed. Deploy with: ./scripts/deploy-ollama.sh"
fi
echo ""

echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Deploy Ollama (if not done):"
echo "   ./scripts/deploy-ollama.sh"
echo ""
echo "2. Pull a model:"
echo "   kubectl exec -n llm deployment/ollama -- ollama pull llama3.2"
echo ""
echo "3. Run backend:"
echo "   cd restaurant-app/backend"
echo "   mirrord exec --config ../../mirrord/config.json -- npm run dev"
echo ""
echo "4. Run frontend (in another terminal):"
echo "   cd restaurant-app/frontend"
echo "   npm run dev"
echo ""
echo "5. Open browser:"
echo "   http://localhost:5173"
