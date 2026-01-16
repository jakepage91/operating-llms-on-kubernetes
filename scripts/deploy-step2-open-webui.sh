#!/bin/bash
set -e

# Deploy Open WebUI to Kubernetes
# This script follows the blog post walkthrough

echo "🚀 Deploying Open WebUI..."

# Deploy Open WebUI (configured to route through llm-gateway)
echo "📦 Deploying Open WebUI..."
kubectl apply -f kubernetes/open-webui-deployment.yaml

# Wait for Open WebUI to be ready
echo "⏳ Waiting for Open WebUI to be ready..."
kubectl wait --for=condition=ready pod -l app=open-webui -n llm --timeout=300s

# Set up port forwarding
echo ""
echo "✅ Open WebUI deployed successfully!"
echo ""
echo "To access Open WebUI:"
echo "  kubectl port-forward svc/open-webui 3000:8080 -n llm"
echo ""
echo "Then open: http://localhost:3000"
echo ""
echo "Next steps:"
echo "  1. Deploy the LLM Gateway: ./scripts/deploy-step3-gateway.sh"
echo "  2. Or run the gateway locally with mirrord: ./scripts/run-gateway-locally.sh"
