#!/bin/bash
set -e

# Build and push LLM Gateway to Cloudsmith
# Usage: ./build-and-push-gateway.sh [version]
# Example: ./build-and-push-gateway.sh v1.0.0

VERSION="${1:-v1.0.0}"
CLOUDSMITH_ORG="${CLOUDSMITH_ORG:-metalbear}"
CLOUDSMITH_REPO="${CLOUDSMITH_REPO:-llm-ops}"
IMAGE_NAME="llm-gateway"
FULL_IMAGE_NAME="docker.cloudsmith.io/${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}/${IMAGE_NAME}"

echo "🔨 Building LLM Gateway v${VERSION}"
echo "Registry: ${FULL_IMAGE_NAME}"
echo ""

# Navigate to llm-gateway directory
cd llm-gateway

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t "${IMAGE_NAME}:${VERSION}" .
docker tag "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:latest"

# Tag for Cloudsmith
docker tag "${IMAGE_NAME}:${VERSION}" "${FULL_IMAGE_NAME}:${VERSION}"
docker tag "${IMAGE_NAME}:${VERSION}" "${FULL_IMAGE_NAME}:latest"

echo "✅ Image built successfully"
echo ""
echo "Images created:"
echo "  - ${IMAGE_NAME}:${VERSION}"
echo "  - ${IMAGE_NAME}:latest"
echo "  - ${FULL_IMAGE_NAME}:${VERSION}"
echo "  - ${FULL_IMAGE_NAME}:latest"
echo ""

# Check if user wants to push
read -p "Push to Cloudsmith? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Push cancelled"
    echo ""
    echo "To push later, run:"
    echo "  docker push ${FULL_IMAGE_NAME}:${VERSION}"
    echo "  docker push ${FULL_IMAGE_NAME}:latest"
    exit 0
fi

# Check if logged into Cloudsmith
echo "🔐 Checking Cloudsmith authentication..."
if ! docker login docker.cloudsmith.io 2>/dev/null; then
    echo ""
    echo "⚠️  Not logged into Cloudsmith. Please log in first:"
    echo ""
    echo "  docker login docker.cloudsmith.io"
    echo "  Username: Your Cloudsmith username"
    echo "  Password: Your Cloudsmith API key"
    echo ""
    echo "To get an API key:"
    echo "  1. Go to https://cloudsmith.io/user/settings/api/"
    echo "  2. Create a new API key with 'Read' and 'Write' permissions"
    echo ""
    exit 1
fi

# Push to Cloudsmith
echo "📤 Pushing to Cloudsmith..."
docker push "${FULL_IMAGE_NAME}:${VERSION}"
docker push "${FULL_IMAGE_NAME}:latest"

echo ""
echo "✅ Successfully pushed to Cloudsmith!"
echo ""
echo "Image available at:"
echo "  ${FULL_IMAGE_NAME}:${VERSION}"
echo "  ${FULL_IMAGE_NAME}:latest"
echo ""
echo "To use in Kubernetes:"
echo "  Update llm-gateway/k8s/deployment.yaml:"
echo "    image: ${FULL_IMAGE_NAME}:${VERSION}"
echo ""
echo "Or run:"
echo "  ./scripts/update-gateway-image.sh ${VERSION}"
