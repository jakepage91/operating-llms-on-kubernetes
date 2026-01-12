# Complete Command Reference

All commands needed to set up, deploy, and run this repository.

---

## Initial Setup

### Create the Repository
```bash
# Create and initialize
mkdir restaurant-llm-ops
cd restaurant-llm-ops
git init
git branch -M main

# Create .gitignore and other files (see SETUP.md)

# Add all files
git add .
git commit -m "Initial commit"

# Add remote and push
git remote add origin https://github.com/your-org/restaurant-llm-ops.git
git push -u origin main
git tag v1.0.0
git push --tags
```

### Vendor Open WebUI
```bash
git subtree add --prefix open-webui https://github.com/open-webui/open-webui.git main --squash
```

### Make Scripts Executable
```bash
chmod +x scripts/*.sh
```

---

## Kubernetes Deployment

### Deploy Ollama
```bash
# Using the script
./scripts/deploy-ollama.sh

# Or manually
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/ollama-deployment.yaml
kubectl apply -f kubernetes/ollama-service.yaml
kubectl apply -f kubernetes/example-modelfile.yaml
```

### Verify Deployment
```bash
# Check pod status
kubectl get pods -n llm

# Wait for ready
kubectl wait --for=condition=ready pod -l app=ollama -n llm --timeout=180s

# View logs
kubectl logs -n llm -l app=ollama -f

# Check service
kubectl get svc -n llm
```

### Pull a Model
```bash
# Pull llama3.2 (recommended)
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# Or other models
kubectl exec -n llm deployment/ollama -- ollama pull mistral
kubectl exec -n llm deployment/ollama -- ollama pull phi3

# List models
kubectl exec -n llm deployment/ollama -- ollama list
```

### Test Ollama API
```bash
# Port-forward
kubectl port-forward -n llm svc/ollama 11434:11434

# In another terminal, test
curl http://localhost:11434/api/tags

# Test generation
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

---

## Local Development Setup

### Install Dependencies
```bash
# Automated setup
./scripts/setup-local-dev.sh

# Or manually:
# Backend
cd restaurant-app/backend
npm install
cd ../..

# Frontend
cd restaurant-app/frontend
npm install
cd ../..
```

### Install Mirrord
```bash
curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash

# Verify installation
mirrord --version
```

---

## Running the Restaurant App

### Backend (with mirrord)
```bash
cd restaurant-app/backend
mirrord exec --config ../../mirrord/config.json -- npm run dev
```

### Backend (without mirrord, using port-forward)
```bash
# Terminal 1: Port-forward
kubectl port-forward -n llm svc/ollama 11434:11434

# Terminal 2: Run backend
cd restaurant-app/backend
export OLLAMA_HOST=http://localhost:11434
npm run dev
```

### Frontend
```bash
cd restaurant-app/frontend
npm run dev
```

### Test the API
```bash
./scripts/test-restaurant-api.sh

# Or manually
curl -X POST http://localhost:3001/api/recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "temperature": 0.2,
    "top_p": 0.9,
    "model": "llama3.2"
  }'
```

### Open in Browser
```bash
# macOS
open http://localhost:5173

# Linux
xdg-open http://localhost:5173

# Or just navigate to: http://localhost:5173
```

---

## Running Open WebUI (Optional)

### Backend (Python)
```bash
cd open-webui/backend
pip install -r requirements.txt

# With mirrord
mirrord exec --config ../../mirrord/config.json -- python main.py

# Without mirrord (port-forward required)
export OLLAMA_API_BASE_URL=http://localhost:11434
python main.py
```

### Frontend (Svelte)
```bash
cd open-webui
npm install
npm run dev
```

---

## Creating Custom Models

### Create a Modelfile
```bash
# Create the file
cat > kubernetes/modelfiles/restaurant-chef-v1.modelfile <<'EOF'
FROM llama3.2

SYSTEM You are a restaurant operations assistant. Provide direct, actionable recommendations in kitchen language. No pleasantries.

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 2048
EOF
```

### Build the Custom Model
```bash
# Copy Modelfile to pod
POD_NAME=$(kubectl get pod -n llm -l app=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl cp kubernetes/modelfiles/restaurant-chef-v1.modelfile llm/${POD_NAME}:/tmp/restaurant-chef.modelfile

# Build the model
kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /tmp/restaurant-chef.modelfile

# Verify
kubectl exec -n llm deployment/ollama -- ollama list
```

### Test the Custom Model
```bash
kubectl exec -n llm deployment/ollama -- ollama run restaurant-chef "Analyze these orders: Table 5: Caesar Salad, Grilled Salmon"
```

### Use in the App
Update `restaurant-app/backend/src/index.ts`:
```typescript
model = 'restaurant-chef'
```

Or just change the model name in the frontend UI.

---

## Exporting and Storing Models

### Export a Model
```bash
kubectl exec -n llm deployment/ollama -- ollama save restaurant-chef > restaurant-chef-v1.tar
```

### Push to S3
```bash
aws s3 cp restaurant-chef-v1.tar s3://your-bucket/models/restaurant-chef-v1.tar
```

### Push to Cloudsmith
```bash
cloudsmith push ollama your-org/llm-models restaurant-chef-v1.tar
```

### Import on Another Cluster
```bash
# Download from S3
aws s3 cp s3://your-bucket/models/restaurant-chef-v1.tar .

# Copy to pod
POD_NAME=$(kubectl get pod -n llm -l app=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl cp restaurant-chef-v1.tar llm/${POD_NAME}:/tmp/

# Import (note: exact import command may vary by Ollama version)
kubectl exec -n llm deployment/ollama -- ollama import restaurant-chef /tmp/restaurant-chef-v1.tar
```

---

## Git Operations

### Update Open WebUI
```bash
git subtree pull --prefix open-webui https://github.com/open-webui/open-webui.git main --squash
```

### Commit Changes
```bash
git add .
git commit -m "Your commit message"
git push
```

### Tag a Release
```bash
git tag v1.1.0
git push --tags
```

---

## Debugging and Troubleshooting

### Check Ollama Pod Logs
```bash
kubectl logs -n llm -l app=ollama -f
```

### Describe Pod (for errors)
```bash
kubectl describe pod -n llm -l app=ollama
```

### Exec into Ollama Pod
```bash
POD_NAME=$(kubectl get pod -n llm -l app=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n llm -it ${POD_NAME} -- /bin/bash
```

### Check Mirrord Connection
```bash
mirrord exec --config mirrord/config.json -- curl http://ollama:11434/api/tags
```

### View Backend Logs
```bash
# If running with npm run dev, logs appear in the terminal
# Or check for errors:
cd restaurant-app/backend
npm run dev 2>&1 | tee backend.log
```

### View Frontend Logs
```bash
# Browser console (F12 → Console)
# Or Vite logs in terminal
cd restaurant-app/frontend
npm run dev
```

---

## Cleanup

### Delete Kubernetes Resources
```bash
kubectl delete namespace llm

# Or individually
kubectl delete deployment -n llm ollama
kubectl delete service -n llm ollama
kubectl delete configmap -n llm example-modelfiles
```

### Stop Local Processes
```bash
# Stop backend: Ctrl+C in the terminal
# Stop frontend: Ctrl+C in the terminal
```

### Remove Local Dependencies
```bash
rm -rf restaurant-app/backend/node_modules
rm -rf restaurant-app/frontend/node_modules
rm -rf open-webui/node_modules
```

---

## Production Deployment (Future)

### Containerize Backend
```bash
# Create Dockerfile for backend
cd restaurant-app/backend
docker build -t restaurant-backend:v1 .
docker push your-registry/restaurant-backend:v1

# Create K8s deployment
kubectl apply -f kubernetes/restaurant-backend-deployment.yaml
```

### Containerize Frontend
```bash
# Build static assets
cd restaurant-app/frontend
npm run build

# Serve with nginx
docker build -t restaurant-frontend:v1 .
docker push your-registry/restaurant-frontend:v1

# Deploy
kubectl apply -f kubernetes/restaurant-frontend-deployment.yaml
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Deploy Ollama | `./scripts/deploy-ollama.sh` |
| Pull model | `kubectl exec -n llm deployment/ollama -- ollama pull llama3.2` |
| Run backend | `cd restaurant-app/backend && mirrord exec --config ../../mirrord/config.json -- npm run dev` |
| Run frontend | `cd restaurant-app/frontend && npm run dev` |
| Test API | `./scripts/test-restaurant-api.sh` |
| View logs | `kubectl logs -n llm -l app=ollama -f` |
| Create model | `kubectl exec -n llm deployment/ollama -- ollama create <name> -f /tmp/modelfile` |
| List models | `kubectl exec -n llm deployment/ollama -- ollama list` |

---

**For more details, see:**
- [README.md](./README.md) - Overview and quick start
- [SETUP.md](./SETUP.md) - Repository setup from scratch
- [docs/workflow.md](./docs/workflow.md) - Detailed development workflow
- [docs/glossary.md](./docs/glossary.md) - Term definitions
