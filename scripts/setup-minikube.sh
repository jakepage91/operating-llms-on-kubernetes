#!/bin/bash
set -e

echo "🚀 Setting up Minikube for Restaurant LLM Operations Platform"
echo ""

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ minikube not found. Please install it first:"
    echo "   brew install minikube"
    echo "   or visit: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Check Docker Desktop memory allocation
DOCKER_MEMORY=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo "0")
DOCKER_MEMORY_MB=$((DOCKER_MEMORY / 1024 / 1024))

if [ "${DOCKER_MEMORY_MB}" -gt 0 ] && [ "${DOCKER_MEMORY_MB}" -lt "${MEMORY}" ]; then
    echo "⚠️  Warning: Docker Desktop has only ${DOCKER_MEMORY_MB}MB available"
    echo "   Requested: ${MEMORY}MB"
    echo ""
    echo "   To increase Docker Desktop memory:"
    echo "   1. Open Docker Desktop"
    echo "   2. Settings → Resources → Memory"
    echo "   3. Set to at least 8GB (recommended for LLM workloads)"
    echo "   4. Apply & Restart"
    echo ""
    read -p "Continue with ${DOCKER_MEMORY_MB}MB? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    # Adjust memory to fit within Docker's limits (leave 500MB headroom)
    MEMORY=$((DOCKER_MEMORY_MB - 500))
    echo "📊 Adjusting minikube memory to ${MEMORY}MB"
fi

# Default resource allocations
# Conservative settings that work with Docker Desktop's default limits
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-7168}"  # 7GB (leaves headroom for Docker Desktop)
DISK="${MINIKUBE_DISK:-20g}"

echo "📊 Resource allocation:"
echo "   CPUs: ${CPUS}"
echo "   Memory: ${MEMORY}MB ($(echo "scale=1; ${MEMORY}/1024" | bc)GB)"
echo "   Disk: ${DISK}"
echo ""

# Check if minikube is already running
if minikube status &> /dev/null; then
    echo "⚠️  Minikube is already running."
    read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing minikube cluster..."
        minikube delete
    else
        echo "✅ Using existing minikube cluster"
        exit 0
    fi
fi

# Start minikube
echo "🔧 Starting minikube..."
minikube start \
    --cpus="${CPUS}" \
    --memory="${MEMORY}" \
    --disk-size="${DISK}" \
    --driver=docker

# Enable addons
echo "🔌 Enabling addons..."
minikube addons enable metrics-server

# Verify
echo ""
echo "✅ Minikube started successfully!"
echo ""
echo "📊 Cluster info:"
kubectl cluster-info
echo ""
kubectl get nodes
echo ""

# Set up Docker environment
echo "🐳 To use minikube's Docker daemon (builds images locally):"
echo "   eval \$(minikube docker-env)"
echo ""
echo "   Then build your images:"
echo "   cd restaurant-app/backend"
echo "   docker build -t restaurant-app:latest ."
echo ""

# Next steps
echo "Next steps:"
echo "1. Point your Docker CLI to minikube:"
echo "   eval \$(minikube docker-env)"
echo ""
echo "2. Build the restaurant app image:"
echo "   cd restaurant-app/backend && docker build -t restaurant-app:latest ."
echo ""
echo "3. Deploy the platform:"
echo "   ./scripts/deploy-all.sh"
echo ""
echo "4. Pull a model:"
echo "   kubectl exec -n llm deployment/ollama -- ollama pull llama3.2"
echo ""
echo "5. Access services:"
echo "   kubectl port-forward -n llm svc/open-webui 8080:8080"
echo ""
echo "💡 Tip: Use 'minikube dashboard' to see the Kubernetes dashboard"
echo "💡 Tip: Use 'minikube pause' to pause the cluster (saves battery)"
echo "💡 Tip: Use 'minikube stop' to stop the cluster"
echo "💡 Tip: Use 'minikube delete' to delete the cluster"
