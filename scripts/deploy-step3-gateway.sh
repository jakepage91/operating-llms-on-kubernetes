#!/bin/bash
set -e

# Deploy LLM Gateway to Kubernetes
# This script follows the blog post walkthrough

echo "🚀 Deploying LLM Gateway..."

# Create namespace if it doesn't exist
kubectl create namespace llm-gateway --dry-run=client -o yaml | kubectl apply -f -

# Build the gateway container image
echo "🔨 Building LLM Gateway container..."
cd llm-gateway
docker build -t llm-gateway:latest .
cd ..

# For minikube, load the image
if kubectl config current-context | grep -q "minikube"; then
  echo "📦 Loading image into minikube..."
  minikube image load llm-gateway:latest
fi

# Deploy the gateway
echo "📦 Deploying LLM Gateway..."
kubectl apply -f llm-gateway/k8s/namespace.yaml
kubectl apply -f llm-gateway/k8s/configmap.yaml
kubectl apply -f llm-gateway/k8s/secret.yaml
kubectl apply -f llm-gateway/k8s/deployment.yaml
kubectl apply -f llm-gateway/k8s/service.yaml

# Wait for gateway to be ready
echo "⏳ Waiting for LLM Gateway to be ready..."
kubectl wait --for=condition=ready pod -l app=llm-gateway -n llm-gateway --timeout=300s

# Check gateway health
echo "✅ Checking LLM Gateway health..."
kubectl run -i --rm --restart=Never curl --image=curlimages/curl:latest -n llm-gateway -- \
  curl -s http://llm-gateway/healthz || true

echo ""
echo "✅ LLM Gateway deployed successfully!"
echo ""
echo "The traffic flow is now:"
echo "  Open WebUI → LLM Gateway → Ollama"
echo ""
echo "To test locally with mirrord (recommended for policy iteration):"
echo "  ./scripts/run-gateway-locally.sh"
echo ""
echo "To view gateway logs:"
echo "  kubectl logs -f -l app=llm-gateway -n llm-gateway"
