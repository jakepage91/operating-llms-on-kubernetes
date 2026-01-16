#!/bin/bash
set -e

# Update the llm-gateway deployment to use a specific version from Cloudsmith
# Usage: ./update-gateway-image.sh <version>
# Example: ./update-gateway-image.sh v1.0.0

VERSION="${1}"
CLOUDSMITH_ORG="${CLOUDSMITH_ORG:-metalbear}"
CLOUDSMITH_REPO="${CLOUDSMITH_REPO:-llm-ops}"
IMAGE_NAME="llm-gateway"
FULL_IMAGE_NAME="docker.cloudsmith.io/${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}/${IMAGE_NAME}"

if [ -z "$VERSION" ]; then
    echo "❌ Error: Version is required"
    echo ""
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.0.0"
    echo ""
    exit 1
fi

DEPLOYMENT_FILE="llm-gateway/k8s/deployment.yaml"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "❌ Error: Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi

echo "📝 Updating deployment to use ${FULL_IMAGE_NAME}:${VERSION}"

# Update the image in the deployment file
sed -i.bak "s|image:.*llm-gateway.*|image: ${FULL_IMAGE_NAME}:${VERSION}|g" "$DEPLOYMENT_FILE"

# Also update imagePullPolicy to Always for registry images
sed -i.bak "s|imagePullPolicy:.*|imagePullPolicy: Always|g" "$DEPLOYMENT_FILE"

echo "✅ Updated $DEPLOYMENT_FILE"
echo ""
echo "Changes:"
echo "  image: ${FULL_IMAGE_NAME}:${VERSION}"
echo "  imagePullPolicy: Always"
echo ""

# Show the diff
if command -v diff &> /dev/null && [ -f "${DEPLOYMENT_FILE}.bak" ]; then
    echo "Diff:"
    diff "${DEPLOYMENT_FILE}.bak" "$DEPLOYMENT_FILE" || true
    echo ""
fi

echo "To deploy the updated version:"
echo "  kubectl apply -f $DEPLOYMENT_FILE"
echo ""
echo "Or run:"
echo "  ./scripts/deploy-step3-gateway.sh"
