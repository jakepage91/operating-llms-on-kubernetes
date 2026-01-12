# Restaurant LLM Operations Platform

A production-ready demonstration of LLM operations on Kubernetes, combining **Ollama runtime**, **Open WebUI**, and a custom **restaurant operations app** to show the complete workflow from experimentation to deployment.

## Overview

This repository demonstrates how to:
- Deploy Ollama as an LLM runtime service in Kubernetes
- Deploy a custom application (restaurant ops) that uses the LLM
- Use Open WebUI to experiment with model parameters
- Freeze your final configuration into a Modelfile
- Version and distribute Modelfiles via Cloudsmith

**Key principle**: Everything runs in Kubernetes. Use mirrord to interact with in-cluster services during development and testing.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Kubernetes Cluster (namespace: llm)                │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Ollama     │  │ Restaurant   │  │  Open     │ │
│  │   Runtime    │  │     App      │  │  WebUI    │ │
│  │  :11434      │  │   :3001      │  │  :8080    │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                 │       │
│         │   ← calls ─────┘                 │       │
│         │                                   │       │
│         └──────────── calls ────────────────┘       │
└─────────────────────────────────────────────────────┘
         ↑                                    ↑
         │                                    │
    (mirrord)                            (mirrord)
         │                                    │
┌────────┴────────┐                  ┌───────┴────────┐
│  Restaurant App │                  │   Open WebUI   │
│  Local Dev      │                  │   Local Dev    │
│  (optional)     │                  │  (parameter    │
│                 │                  │   testing)     │
└─────────────────┘                  └────────────────┘
```

## Repository Structure

```
restaurant-llm-ops/
├── README.md                          # This file
├── kubernetes/                        # K8s manifests
│   ├── namespace.yaml                # llm namespace
│   ├── ollama-deployment.yaml        # Ollama runtime
│   ├── ollama-service.yaml           # Ollama service (11434)
│   ├── open-webui-deployment.yaml    # Open WebUI
│   ├── restaurant-app-deployment.yaml # Restaurant app
│   └── example-modelfile.yaml        # Sample Modelfiles
│
├── restaurant-app/                    # Demo application
│   ├── backend/                      # Express + TypeScript
│   │   ├── Dockerfile                # Container image
│   │   └── src/                      # Source code
│   └── frontend/                     # React UI (optional)
│
├── open-webui/                        # Vendored Open WebUI source
│   └── (git subtree from upstream)
│
├── mirrord/                           # Local dev config
│   └── config.json                   # Mirrord settings
│
├── scripts/                           # Automation
│   ├── deploy-all.sh                 # Deploy everything
│   ├── build-restaurant-app.sh       # Build container image
│   └── push-modelfile-to-cloudsmith.sh # Push to registry
│
└── docs/                              # Documentation
    ├── glossary.md                   # Terms and concepts
    └── workflow.md                   # Detailed guides
```

---

## Glossary (Quick Reference)

| Term | Definition |
|------|------------|
| **Ollama** | An LLM runtime (like Docker for AI models) that runs models and serves them via API |
| **Runtime** | The service that loads models and handles inference requests (Ollama) |
| **Model** | The AI weights/parameters (e.g., llama3.2, mistral) |
| **Modelfile** | A declarative config file (like Dockerfile) that defines a custom model with system prompt and parameters |
| **Open WebUI** | A web interface for Ollama (like ChatGPT UI) for testing and experimentation |
| **Temperature** | Randomness control (0.0 = deterministic, 1.0+ = creative) |
| **Top-p** | Nucleus sampling threshold (0.9 = balanced, 1.0 = maximum diversity) |
| **Mirrord** | A tool that runs local processes as if they're inside the Kubernetes cluster |

See [docs/glossary.md](docs/glossary.md) for complete definitions.

---

## The Complete Workflow

### Phase 1: Deploy to Kubernetes

Deploy the complete stack to your Kubernetes cluster.

#### Prerequisites
- kubectl with cluster access
- Docker (for building images)
- Kubernetes cluster with sufficient resources (4GB+ RAM recommended)

#### Using Minikube (Local Testing)

If you're testing locally with minikube:

**First, configure Docker Desktop memory:**
1. Open Docker Desktop → Settings → Resources
2. Set Memory to **8GB minimum** (10GB recommended for comfortable LLM operations)
3. Apply & Restart

Then start minikube:

```bash
# Start minikube with appropriate resources
# Allocate 7GB RAM to minikube (safe default, leaves headroom)
minikube start --cpus=4 --memory=7168 --disk-size=20g

# Enable metrics-server (optional, for resource monitoring)
minikube addons enable metrics-server

# Verify minikube is running
kubectl get nodes
```

**Important for local development:**

1. **Use minikube's Docker daemon** (avoids pushing to external registry):
   ```bash
   # Point your shell to minikube's Docker daemon
   eval $(minikube docker-env)

   # Now build images - they'll be available in minikube
   cd restaurant-app/backend
   docker build -t restaurant-app:latest .
   ```

2. **Update image pull policy** in `kubernetes/restaurant-app-deployment.yaml`:
   ```yaml
   spec:
     containers:
     - name: restaurant-app
       image: restaurant-app:latest
       imagePullPolicy: Never  # Don't try to pull from registry
   ```

3. **Access services** via minikube:
   ```bash
   # Option 1: Port-forward (recommended)
   kubectl port-forward -n llm svc/open-webui 8080:8080
   kubectl port-forward -n llm svc/restaurant-app 3001:3001

   # Option 2: Minikube service (opens browser)
   minikube service open-webui -n llm

   # Option 3: Get minikube IP and use NodePort
   minikube ip
   # Then change services to type: NodePort
   ```

4. **Resource considerations for 16GB machine:**
   - Ollama will use 2-4GB RAM (adjust in `kubernetes/ollama-deployment.yaml` if needed)
   - Keep model sizes small (use llama3.2 3B instead of larger models)
   - Consider reducing replicas to 1 for all services

**Stopping minikube:**
```bash
# Pause (preserves state)
minikube pause

# Stop (shuts down but preserves config)
minikube stop

# Delete (removes everything)
minikube delete
```

#### Step 1.1: Deploy Ollama Runtime

```bash
# Deploy all Kubernetes resources
./scripts/deploy-all.sh
```

This deploys:
- Ollama runtime (llm/ollama)
- Open WebUI (llm/open-webui)
- Restaurant app placeholder (update image later)

#### Step 1.2: Pull a Base Model

```bash
# Pull llama3.2 (recommended for testing - fast and capable)
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# Or try other models:
# kubectl exec -n llm deployment/ollama -- ollama pull mistral
# kubectl exec -n llm deployment/ollama -- ollama pull phi3

# List available models
kubectl exec -n llm deployment/ollama -- ollama list
```

#### Step 1.3: Build and Deploy Restaurant App

```bash
# Build the container image
./scripts/build-restaurant-app.sh

# If using a registry, push it:
export REGISTRY=your-registry.com/your-org
./scripts/build-restaurant-app.sh

# Update the image in kubernetes/restaurant-app-deployment.yaml
# Then deploy:
kubectl apply -f kubernetes/restaurant-app-deployment.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l app=restaurant-app -n llm --timeout=120s
```

#### Step 1.4: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n llm

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# ollama-xxxxxxxxxx-xxxxx           1/1     Running   0          2m
# open-webui-xxxxxxxxxx-xxxxx       1/1     Running   0          2m
# restaurant-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

---

### Phase 2: Experiment with Parameters (Open WebUI)

Use Open WebUI to test different models, prompts, and parameters before freezing your configuration.

#### Option A: Access via Port-Forward

```bash
# Forward Open WebUI to localhost
kubectl port-forward -n llm svc/open-webui 8080:8080

# Open in browser
open http://localhost:8080
```

#### Option B: Run Open WebUI Locally with Mirrord (Recommended)

This gives you the full development experience with hot-reload while connecting to the cluster.

```bash
# Install mirrord (if not already installed)
curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash

# Vendor Open WebUI source (if not done yet)
git subtree add --prefix open-webui https://github.com/open-webui/open-webui.git main --squash

# Run Open WebUI locally with mirrord
cd open-webui

# Backend
cd backend
pip install -r requirements.txt
mirrord exec --config ../../mirrord/config.json -- python main.py

# Frontend (in another terminal)
cd open-webui
npm install
npm run dev

# Open browser
open http://localhost:8080
```

**Why use mirrord?**
- Full access to cluster services (Ollama at `ollama:11434`)
- Hot-reload for fast iteration
- No need to rebuild/redeploy for every change

#### Step 2.1: Experiment in Open WebUI

1. **Open the chat interface** at http://localhost:8080
2. **Select your model** (e.g., llama3.2)
3. **Write a system prompt** for restaurant operations:
   ```
   You are a restaurant operations assistant. Analyze tonight's orders and provide:
   - A brief summary of trends
   - 3-4 actionable recommendations for kitchen prep
   - Any urgent staff notifications

   Be concise, direct, and use kitchen language. No pleasantries.
   ```
4. **Test with sample input**:
   ```
   Tonight's orders:
   - Table 5: Caesar Salad, Grilled Salmon (no croutons)
   - Table 3: Margherita Pizza
   - Table 8: Ribeye Steak (medium-rare), Mashed Potatoes
   - Table 2: Pasta Carbonara
   - Table 12: Caesar Salad, Grilled Chicken

   What should the kitchen prepare for?
   ```
5. **Adjust parameters**:
   - Try **temperature 0.2** (consistent, focused)
   - Try **temperature 0.8** (creative, varied)
   - Try **top_p 0.9** (balanced)
   - Try **top_p 0.95** (more diverse)
6. **Find your sweet spot** - notice how parameters affect output style

#### Step 2.2: Record Your Final Configuration

Once you're satisfied, note down:
- **Model**: `llama3.2`
- **Temperature**: e.g., `0.2`
- **Top-p**: e.g., `0.9`
- **System prompt**: Your final prompt text

---

### Phase 3: Freeze Configuration into Modelfile

Lock your tested configuration into a Modelfile for reproducible deployments.

#### Step 3.1: Create a Modelfile

Create `kubernetes/modelfiles/restaurant-chef-v1.modelfile`:

```dockerfile
FROM llama3.2

SYSTEM You are a restaurant operations assistant. Analyze tonight's orders and provide:
- A brief summary of trends
- 3-4 actionable recommendations for kitchen prep
- Any urgent staff notifications

Be concise, direct, and use kitchen language. No pleasantries.

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 2048
PARAMETER repeat_penalty 1.1
```

#### Step 3.2: Build the Custom Model in Cluster

```bash
# Copy Modelfile to the Ollama pod
POD_NAME=$(kubectl get pod -n llm -l app=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl cp kubernetes/modelfiles/restaurant-chef-v1.modelfile llm/${POD_NAME}:/tmp/restaurant-chef.modelfile

# Build the custom model
kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /tmp/restaurant-chef.modelfile

# Verify it was created
kubectl exec -n llm deployment/ollama -- ollama list
```

You should see:
```
NAME               SIZE    MODIFIED
restaurant-chef    2.0GB   10 seconds ago
llama3.2           2.0GB   1 hour ago
```

#### Step 3.3: Test the Custom Model

```bash
# Test via CLI
kubectl exec -n llm deployment/ollama -- ollama run restaurant-chef "Tonight we have 10 steak orders. What should we prep?"

# Or update restaurant app to use it (see restaurant-app/backend/src/index.ts)
# Change: model = 'restaurant-chef'
```

---

### Phase 4: Push to Cloudsmith

Version and distribute your custom model.

#### Step 4.1: Install Cloudsmith CLI

```bash
pip install cloudsmith-cli

# Configure with your API key
cloudsmith config --token YOUR_API_KEY
```

Get your API key from: https://cloudsmith.io/user/settings/api/

#### Step 4.2: Push the Modelfile

```bash
# Export and push to Cloudsmith
export CLOUDSMITH_ORG=your-org
export CLOUDSMITH_REPO=llm-models

./scripts/push-modelfile-to-cloudsmith.sh restaurant-chef v1.0.0
```

This will:
1. Export the model from Ollama
2. Create a tarball (`restaurant-chef-v1.0.0.tar`)
3. Push to Cloudsmith raw repository

#### Step 4.3: Version in Git

```bash
# Commit the Modelfile
git add kubernetes/modelfiles/restaurant-chef-v1.modelfile
git commit -m "Add restaurant-chef v1.0.0 Modelfile

- Temperature: 0.2 (consistent recommendations)
- Top-p: 0.9 (balanced sampling)
- System prompt: Restaurant operations focused
"

# Tag the release
git tag v1.0.0-restaurant-chef
git push --tags
```

#### Step 4.4: Deploy on Another Cluster

```bash
# Download from Cloudsmith
cloudsmith dl raw your-org/llm-models restaurant-chef-v1.0.0.tar

# Copy to new cluster's Ollama pod
kubectl cp restaurant-chef-v1.0.0.tar llm/${POD_NAME}:/tmp/

# Load into Ollama
kubectl exec -n llm deployment/ollama -- ollama load restaurant-chef /tmp/restaurant-chef-v1.0.0.tar

# Verify
kubectl exec -n llm deployment/ollama -- ollama list
```

---

## Local Development (Optional)

While the primary workflow has everything in Kubernetes, you can use mirrord for local development of the restaurant app.

### Running Restaurant App Locally

```bash
cd restaurant-app/backend

# Install dependencies
npm install

# Run with mirrord (connects to cluster Ollama)
mirrord exec --config ../../mirrord/config.json -- npm run dev

# In another terminal, run frontend
cd restaurant-app/frontend
npm install
npm run dev

# Open browser
open http://localhost:5173
```

**Why develop locally?**
- Faster iteration (no container rebuild/push)
- Easy debugging
- Hot-reload with tsx watch

**When to use**:
- Adding new features to the restaurant app
- Debugging issues
- Testing prompt changes quickly

---

## Testing the Restaurant App

### Via kubectl port-forward

```bash
# Forward the service
kubectl port-forward -n llm svc/restaurant-app 3001:3001

# Test the API
curl http://localhost:3001/health

curl -X POST http://localhost:3001/api/recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "temperature": 0.2,
    "top_p": 0.9,
    "model": "restaurant-chef"
  }'
```

### Via the test script

```bash
./scripts/test-restaurant-api.sh
```

---

## Key Design Decisions

### Why Everything in Kubernetes?
- **Production parity**: Dev/test environment matches production
- **Scalability**: Easy to add replicas, load balancers
- **Isolation**: Namespace separation, network policies
- **Observability**: Prometheus metrics, logging, tracing

### Why Open WebUI for Parameter Testing?
- **Interactive**: Real-time feedback on parameter changes
- **Visual**: Easy to compare outputs side-by-side
- **Feature-rich**: Supports templates, RAG, function calling
- **Standard tool**: Widely used in the LLM community

### Why Mirrord for Local Access?
- **Full cluster access**: DNS, services, secrets, configmaps
- **No port-forwarding juggling**: Seamless connectivity
- **Environment parity**: Same network as production
- **Fast iteration**: Edit code locally, test against cluster services

### Why Cloudsmith?
- **Artifact management**: Purpose-built for storing and versioning binary artifacts
- **Access control**: Fine-grained permissions (public, private, team-based)
- **CDN**: Fast downloads globally
- **Metadata**: Tag models with versions, descriptions, checksums

---

## Troubleshooting

### Ollama pod not starting
```bash
# Check logs
kubectl logs -n llm -l app=ollama

# Check resources
kubectl describe pod -n llm -l app=ollama

# Common fix: Increase memory limits in ollama-deployment.yaml
```

### Restaurant app can't reach Ollama
```bash
# Check service DNS
kubectl exec -n llm deployment/restaurant-app -- nslookup ollama

# Test connectivity
kubectl exec -n llm deployment/restaurant-app -- curl http://ollama:11434/api/tags
```

### Mirrord connection fails
```bash
# Check cluster access
kubectl auth can-i get pods -n llm

# Check mirrord config
cat mirrord/config.json

# Try with verbose logging
mirrord exec --config mirrord/config.json -vvv -- npm run dev
```

### Model generation is too slow
- Use a smaller model (llama3.2 instead of llama3:70b)
- Add GPU support (uncomment GPU limits in ollama-deployment.yaml)
- Reduce context window (num_ctx: 1024 instead of 4096)

---

## Quick Start (TL;DR)

```bash
# 1. Deploy everything to Kubernetes
./scripts/deploy-all.sh
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# 2. Build and deploy restaurant app
./scripts/build-restaurant-app.sh
kubectl apply -f kubernetes/restaurant-app-deployment.yaml

# 3. Access Open WebUI to test parameters
kubectl port-forward -n llm svc/open-webui 8080:8080
open http://localhost:8080

# 4. Create Modelfile with your chosen parameters
kubectl cp kubernetes/modelfiles/restaurant-chef-v1.modelfile llm/${POD_NAME}:/tmp/restaurant-chef.modelfile
kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /tmp/restaurant-chef.modelfile

# 5. Push to Cloudsmith
./scripts/push-modelfile-to-cloudsmith.sh restaurant-chef v1.0.0

# Done!
```

**Time to production-ready LLM config**: ~20 minutes

---

## Vendoring Strategy

### Open WebUI: Git Subtree
```bash
git subtree add --prefix open-webui https://github.com/open-webui/open-webui.git main --squash
```

**Why?**
- ✅ Full source code included (not just a pointer)
- ✅ Can modify locally
- ✅ Easy updates: `git subtree pull ...`
- ✅ Preserves license

---

## Next Steps

1. **Add monitoring**: Prometheus + Grafana for metrics
2. **Add CI/CD**: Automate builds and deployments
3. **Add auth**: Secure Open WebUI and restaurant app
4. **Add database**: Store orders and recommendations
5. **Add RAG**: Vector DB for historical context
6. **Fine-tune**: Train LoRA adapters on your data

---

## Resources

- [Ollama Documentation](https://ollama.ai/docs)
- [Modelfile Specification](https://github.com/ollama/ollama/blob/main/docs/modelfile.md)
- [Open WebUI](https://docs.openwebui.com)
- [Mirrord](https://mirrord.dev/docs)
- [Cloudsmith](https://help.cloudsmith.io/)

---

## License

MIT License - See [LICENSE](LICENSE)

---

## Acknowledgments

- [Ollama](https://ollama.ai/) - The LLM runtime
- [Open WebUI](https://github.com/open-webui/open-webui) - Web interface for Ollama
- [Mirrord](https://mirrord.dev/) - Local Kubernetes development tool
- [ndouglas-cloudsmith/huggingface-kubernetes](https://github.com/ndouglas-cloudsmith/huggingface-kubernetes) - Original K8s manifests inspiration
