#!/bin/bash
set -e

echo "🚀 Deploying Ollama to Kubernetes..."

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Apply manifests
echo "📦 Creating namespace..."
kubectl apply -f kubernetes/namespace.yaml

echo "📦 Deploying Ollama..."
kubectl apply -f kubernetes/ollama-deployment.yaml

echo "📦 Creating service..."
kubectl apply -f kubernetes/ollama-service.yaml

echo "📦 Creating example Modelfiles ConfigMap..."
kubectl apply -f kubernetes/example-modelfile.yaml

# Wait for deployment
echo "⏳ Waiting for Ollama pod to be ready..."
kubectl wait --for=condition=ready pod -l app=ollama -n llm --timeout=180s

echo "✅ Ollama deployed successfully!"
echo ""
echo "Next steps:"
echo "  1. Pull a model:"
echo "     kubectl exec -n llm deployment/ollama -- ollama pull llama3.2"
echo ""
echo "  2. Test the API:"
echo "     kubectl port-forward -n llm svc/ollama 11434:11434"
echo "     curl http://localhost:11434/api/tags"
echo ""
echo "  3. Run the restaurant app (see restaurant-app/README.md)"
