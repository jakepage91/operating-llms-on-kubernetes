#!/bin/bash
set -e

echo "🔨 Building restaurant app (backend + frontend) for minikube..."

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

# Build backend image
echo "📦 Building restaurant-app-backend:latest..."
cd restaurant-app/backend
docker build -t restaurant-app-backend:latest .
cd ../..
echo "✅ Backend image built"

# Build frontend image
echo "📦 Building restaurant-app-frontend:latest..."
cd restaurant-app/frontend
docker build -t restaurant-app-frontend:latest .
cd ../..
echo "✅ Frontend image built"

echo ""
echo "✅ All images built successfully!"
echo ""
echo "🔍 Verify the images:"
docker images | grep restaurant-app
echo ""
echo "Next steps:"
echo "1. Deploy:"
echo "   kubectl apply -f kubernetes/restaurant-app-backend-minikube.yaml"
echo "   kubectl apply -f kubernetes/restaurant-app-frontend-minikube.yaml"
echo ""
echo "   Or use the deploy script:"
echo "   ./scripts/deploy-minikube.sh"
echo ""
echo "2. Check status:"
echo "   kubectl get pods -n llm"
echo ""
echo "3. Access the app:"
echo "   kubectl port-forward -n llm svc/restaurant-app-frontend 8080:80"
echo "   open http://localhost:8080"
