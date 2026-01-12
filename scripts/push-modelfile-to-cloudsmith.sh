#!/bin/bash
set -e

# Usage: ./push-modelfile-to-cloudsmith.sh <model-name> <version>
# Example: ./push-modelfile-to-cloudsmith.sh restaurant-chef v1.0.0

MODEL_NAME="${1:-restaurant-chef}"
VERSION="${2:-v1.0.0}"
CLOUDSMITH_ORG="${CLOUDSMITH_ORG:-your-org}"
CLOUDSMITH_REPO="${CLOUDSMITH_REPO:-llm-models}"

echo "📦 Exporting model: ${MODEL_NAME}"

# Check if model exists in cluster
if ! kubectl exec -n llm deployment/ollama -- ollama list | grep -q "${MODEL_NAME}"; then
    echo "❌ Model '${MODEL_NAME}' not found in cluster"
    echo "Available models:"
    kubectl exec -n llm deployment/ollama -- ollama list
    exit 1
fi

# Export the model
echo "⬇️  Exporting model from cluster..."
kubectl exec -n llm deployment/ollama -- ollama save "${MODEL_NAME}" > "${MODEL_NAME}-${VERSION}.tar"

FILE_SIZE=$(du -h "${MODEL_NAME}-${VERSION}.tar" | cut -f1)
echo "✅ Exported: ${MODEL_NAME}-${VERSION}.tar (${FILE_SIZE})"

# Check if cloudsmith CLI is installed
if ! command -v cloudsmith &> /dev/null; then
    echo ""
    echo "⚠️  Cloudsmith CLI not found. Install it with:"
    echo "   pip install cloudsmith-cli"
    echo ""
    echo "Then configure your API key:"
    echo "   cloudsmith config --token <your-api-key>"
    echo ""
    echo "For now, the model file is saved as: ${MODEL_NAME}-${VERSION}.tar"
    exit 1
fi

# Push to Cloudsmith
echo "📤 Pushing to Cloudsmith: ${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}"
cloudsmith push raw "${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}" "${MODEL_NAME}-${VERSION}.tar" \
    --name "${MODEL_NAME}" \
    --version "${VERSION}" \
    --summary "LLM model: ${MODEL_NAME}" \
    --description "Ollama model for restaurant operations" \
    --tags "ollama,llm,${MODEL_NAME}"

echo "✅ Successfully pushed to Cloudsmith!"
echo ""
echo "To pull this model on another system:"
echo "  1. Download from Cloudsmith:"
echo "     cloudsmith dl raw ${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO} ${MODEL_NAME}-${VERSION}.tar"
echo ""
echo "  2. Import into Ollama:"
echo "     kubectl cp ${MODEL_NAME}-${VERSION}.tar llm/\${POD_NAME}:/tmp/"
echo "     kubectl exec -n llm deployment/ollama -- ollama load ${MODEL_NAME} /tmp/${MODEL_NAME}-${VERSION}.tar"
