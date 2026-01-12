#!/bin/bash
set -e

echo "🚀 Deploying LLM Operations Platform to Kubernetes..."
echo ""

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# 1. Deploy namespace
echo "📦 Creating namespace..."
kubectl apply -f kubernetes/namespace.yaml

# 2. Deploy Ollama runtime
echo "📦 Deploying Ollama runtime..."
kubectl apply -f kubernetes/ollama-deployment.yaml
kubectl apply -f kubernetes/ollama-service.yaml
kubectl apply -f kubernetes/example-modelfile.yaml

# 3. Deploy Open WebUI
echo "📦 Deploying Open WebUI..."
kubectl apply -f kubernetes/open-webui-deployment.yaml

# 4. Deploy Restaurant App (if image is available)
if kubectl get deployment restaurant-app -n llm &> /dev/null; then
    echo "📦 Updating Restaurant App..."
    kubectl apply -f kubernetes/restaurant-app-deployment.yaml
else
    echo "⚠️  Skipping Restaurant App deployment (no image built yet)"
    echo "   Build and push the image first:"
    echo "   ./scripts/build-restaurant-app.sh"
fi

# Wait for Ollama
echo ""
echo "⏳ Waiting for Ollama pod to be ready..."
kubectl wait --for=condition=ready pod -l app=ollama -n llm --timeout=180s

# Wait for Open WebUI
echo "⏳ Waiting for Open WebUI pod to be ready..."
kubectl wait --for=condition=ready pod -l app=open-webui -n llm --timeout=120s

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Current status:"
kubectl get pods -n llm
echo ""
kubectl get svc -n llm
echo ""
echo "Next steps:"
echo ""
echo "1️⃣  Pull a base model:"
echo "   kubectl exec -n llm deployment/ollama -- ollama pull llama3.2"
echo ""
echo "2️⃣  Access Open WebUI (port-forward):"
echo "   kubectl port-forward -n llm svc/open-webui 8080:8080"
echo "   Open: http://localhost:8080"
echo ""
echo "3️⃣  Or use mirrord to run Open WebUI locally:"
echo "   cd open-webui"
echo "   mirrord exec --config ../mirrord/config.json -- npm run dev"
echo ""
echo "4️⃣  Test the Restaurant App:"
echo "   kubectl port-forward -n llm svc/restaurant-app 3001:3001"
echo "   curl http://localhost:3001/health"
