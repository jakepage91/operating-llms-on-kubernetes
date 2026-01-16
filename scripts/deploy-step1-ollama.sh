#!/bin/bash
set -e

# Deploy Ollama to Kubernetes
# This script follows the blog post walkthrough

echo "🚀 Deploying Ollama to Kubernetes..."

# Create namespace if it doesn't exist
kubectl create namespace llm --dry-run=client -o yaml | kubectl apply -f -

# Deploy Ollama
echo "📦 Deploying Ollama runtime..."
kubectl apply -f kubernetes/ollama-deployment.yaml
kubectl apply -f kubernetes/ollama-service.yaml

# Wait for Ollama to be ready
echo "⏳ Waiting for Ollama to be ready..."
kubectl wait --for=condition=ready pod -l app=ollama -n llm --timeout=300s

# Check Ollama health
echo "✅ Checking Ollama health..."
kubectl run -i --rm --restart=Never curl --image=curlimages/curl:latest -n llm -- \
  curl -s http://ollama:11434/api/tags || true

echo ""
echo "✅ Ollama deployed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/deploy-step2-open-webui.sh"
echo "  2. Or manually deploy Open WebUI: kubectl apply -f kubernetes/open-webui-deployment.yaml"
