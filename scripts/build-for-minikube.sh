#!/bin/bash
set -e

echo "🔨 Building restaurant app for minikube..."

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Start it first:"
    echo "   ./scripts/setup-minikube.sh"
    exit 1
fi

# Check if we're using minikube's Docker daemon
if ! docker info | grep -q "minikube"; then
    echo "⚠️  Not using minikube's Docker daemon. Switching now..."
    eval $(minikube docker-env)
fi

# Build the image
echo "📦 Building restaurant-app:latest..."
cd restaurant-app/backend
docker build -t restaurant-app:latest .
cd ../..

echo "✅ Image built successfully!"
echo ""
echo "🔍 Verify the image:"
docker images | grep restaurant-app
echo ""
echo "Next steps:"
echo "1. Update kubernetes/restaurant-app-deployment.yaml:"
echo "   Set imagePullPolicy: Never"
echo ""
echo "2. Deploy:"
echo "   kubectl apply -f kubernetes/restaurant-app-deployment.yaml"
echo ""
echo "3. Check status:"
echo "   kubectl get pods -n llm"
