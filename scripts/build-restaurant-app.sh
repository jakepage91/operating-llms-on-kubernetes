#!/bin/bash
set -e

IMAGE_NAME="${IMAGE_NAME:-restaurant-app:latest}"
REGISTRY="${REGISTRY:-}"

echo "🔨 Building restaurant app container image..."

cd restaurant-app/backend

# Build the image
docker build -t "${IMAGE_NAME}" .

if [ -n "${REGISTRY}" ]; then
    echo "📤 Pushing to registry: ${REGISTRY}"
    FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}"
    docker tag "${IMAGE_NAME}" "${FULL_IMAGE}"
    docker push "${FULL_IMAGE}"
    echo "✅ Pushed: ${FULL_IMAGE}"
else
    echo "✅ Built: ${IMAGE_NAME}"
    echo ""
    echo "To push to a registry:"
    echo "  export REGISTRY=your-registry.com/your-org"
    echo "  ./scripts/build-restaurant-app.sh"
fi

cd ../..

echo ""
echo "Next steps:"
echo "  1. Update kubernetes/restaurant-app-deployment.yaml with your image name"
echo "  2. Deploy: kubectl apply -f kubernetes/restaurant-app-deployment.yaml"
