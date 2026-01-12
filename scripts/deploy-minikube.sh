#!/bin/bash
set -e

echo "🚀 Deploying to Minikube..."
echo ""

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Start it first:"
    echo "   ./scripts/setup-minikube.sh"
    exit 1
fi

# Check if kubectl is configured for minikube
if ! kubectl config current-context | grep -q "minikube"; then
    echo "⚠️  kubectl is not pointing to minikube. Switching context..."
    kubectl config use-context minikube
fi

echo "📊 Current context:"
kubectl config current-context
echo ""

# 1. Deploy namespace
echo "📦 Creating namespace..."
kubectl apply -f kubernetes/namespace.yaml

# 2. Deploy Ollama runtime (minikube version with reduced resources)
echo "📦 Deploying Ollama runtime (minikube optimized)..."
kubectl apply -f kubernetes/ollama-deployment-minikube.yaml
kubectl apply -f kubernetes/ollama-service.yaml
kubectl apply -f kubernetes/example-modelfile.yaml

# 3. Deploy Open WebUI (uses standard deployment)
echo "📦 Deploying Open WebUI..."
kubectl apply -f kubernetes/open-webui-deployment.yaml

# 4. Deploy Restaurant App (if image exists)
echo "📦 Checking for restaurant-app image..."
if eval $(minikube docker-env) && docker images | grep -q "restaurant-app.*latest"; then
    echo "✅ restaurant-app:latest found, deploying..."
    kubectl apply -f kubernetes/restaurant-app-deployment-minikube.yaml
else
    echo "⚠️  restaurant-app:latest not found in minikube's Docker."
    echo "   Build it first with:"
    echo "   eval \$(minikube docker-env)"
    echo "   cd restaurant-app/backend && docker build -t restaurant-app:latest ."
    echo ""
    echo "   Or use the helper script:"
    echo "   ./scripts/build-for-minikube.sh"
    echo ""
    echo "   Skipping restaurant-app deployment for now..."
fi

# Wait for Ollama
echo ""
echo "⏳ Waiting for Ollama pod to be ready (this may take 1-2 minutes)..."
kubectl wait --for=condition=ready pod -l app=ollama -n llm --timeout=300s || {
    echo "❌ Ollama pod failed to start. Check logs:"
    echo "   kubectl logs -n llm -l app=ollama"
    exit 1
}

# Wait for Open WebUI
echo "⏳ Waiting for Open WebUI pod to be ready..."
kubectl wait --for=condition=ready pod -l app=open-webui -n llm --timeout=180s || {
    echo "⚠️  Open WebUI pod not ready yet. Check status:"
    echo "   kubectl get pods -n llm"
}

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Current status:"
kubectl get pods -n llm
echo ""
kubectl get svc -n llm
echo ""

# Get minikube IP
MINIKUBE_IP=$(minikube ip)

echo "🌐 Access URLs:"
echo ""
echo "Open WebUI:"
echo "  Port-forward: kubectl port-forward -n llm svc/open-webui 8080:8080"
echo "  Then visit:   http://localhost:8080"
echo ""

if kubectl get svc -n llm restaurant-app &> /dev/null; then
    echo "Restaurant App:"
    echo "  NodePort:     http://${MINIKUBE_IP}:30001"
    echo "  Port-forward: kubectl port-forward -n llm svc/restaurant-app 3001:3001"
    echo "  Then visit:   http://localhost:3001/health"
    echo ""
fi

echo "Ollama:"
echo "  Port-forward: kubectl port-forward -n llm svc/ollama 11434:11434"
echo "  Then test:    curl http://localhost:11434/api/tags"
echo ""

echo "Next steps:"
echo ""
echo "1️⃣  Pull a model (use a small model for local testing):"
echo "   kubectl exec -n llm deployment/ollama -- ollama pull llama3.2"
echo ""
echo "2️⃣  Access Open WebUI:"
echo "   kubectl port-forward -n llm svc/open-webui 8080:8080 &"
echo "   open http://localhost:8080"
echo ""
echo "3️⃣  Test the Restaurant App:"
echo "   kubectl port-forward -n llm svc/restaurant-app 3001:3001 &"
echo "   curl http://localhost:3001/health"
echo ""
echo "4️⃣  Monitor resources:"
echo "   kubectl top nodes"
echo "   kubectl top pods -n llm"
echo ""
echo "💡 Tips:"
echo "   - Use small models (llama3.2, phi3) for local testing"
echo "   - Run 'minikube dashboard' to see the Kubernetes dashboard"
echo "   - Run 'minikube pause' when not using to save battery"
echo "   - Run 'minikube logs' if something goes wrong"
