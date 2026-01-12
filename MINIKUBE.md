# Minikube Setup Guide

Complete guide for running the Restaurant LLM Operations Platform on minikube with a 16GB RAM machine.

## Quick Start

```bash
# 1. Setup minikube (one time)
./scripts/setup-minikube.sh

# 2. Point Docker to minikube
eval $(minikube docker-env)

# 3. Build restaurant app image
./scripts/build-for-minikube.sh

# 4. Deploy everything
./scripts/deploy-minikube.sh

# 5. Pull a small model
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# 6. Access Open WebUI
kubectl port-forward -n llm svc/open-webui 8080:8080
open http://localhost:8080
```

---

## Prerequisites

- **Docker Desktop** installed and running
  - **Memory configured to 8GB minimum** (10GB recommended)
  - Settings → Resources → Memory → 8GB → Apply & Restart
- **Minikube** installed: `brew install minikube`
- **kubectl** installed: `brew install kubectl`
- **16GB RAM machine** recommended (but can work with 8GB if careful)

---

## Step-by-Step Setup

### 0. Configure Docker Desktop Memory (Important!)

Before starting minikube, ensure Docker Desktop has enough memory allocated:

1. **Open Docker Desktop**
2. **Go to Settings** (gear icon) → **Resources** → **Memory**
3. **Set Memory to at least 8GB** (10GB recommended)
4. **Click "Apply & Restart"**
5. **Wait for Docker to restart**

**Why?** Minikube runs inside Docker Desktop's VM, so it's limited by Docker's memory allocation. By default, Docker Desktop only allocates ~4-6GB, which isn't enough for running LLMs.

**Verify Docker has enough memory:**
```bash
docker info | grep -i memory
# Should show at least 8GB
```

### 1. Start Minikube

```bash
./scripts/setup-minikube.sh
```

This will:
- Start minikube with 4 CPUs, 8GB RAM, 20GB disk
- Enable metrics-server addon
- Verify the cluster is running

**Manual alternative:**
```bash
minikube start --cpus=4 --memory=7168 --disk-size=20g
minikube addons enable metrics-server
```

### 2. Configure Docker to Use Minikube's Daemon

```bash
# Run this in your current terminal
eval $(minikube docker-env)

# Verify it's working
docker info | grep minikube
```

**Why?** This ensures images you build are available inside minikube without needing to push to a registry.

**Important:** You need to run `eval $(minikube docker-env)` in each new terminal session.

### 3. Build the Restaurant App Image

```bash
./scripts/build-for-minikube.sh
```

This builds the `restaurant-app:latest` image in minikube's Docker daemon.

**Verify:**
```bash
docker images | grep restaurant-app
```

### 4. Deploy All Services

```bash
./scripts/deploy-minikube.sh
```

This deploys:
- Ollama runtime (with reduced resource limits for local)
- Open WebUI
- Restaurant app (if image was built)

**Verify:**
```bash
kubectl get pods -n llm
kubectl get svc -n llm
```

All pods should show `Running` and `1/1` ready.

### 5. Pull an LLM Model

```bash
# Use a small model for local testing (3B parameters)
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# Or try these small models:
# kubectl exec -n llm deployment/ollama -- ollama pull phi3      # 3.8B params
# kubectl exec -n llm deployment/ollama -- ollama pull gemma:2b  # 2B params

# List models
kubectl exec -n llm deployment/ollama -- ollama list
```

**Model size guide:**
- `llama3.2` (3B): ~2GB download, fast inference, good quality
- `phi3`: ~2.3GB download, very fast, decent quality
- `gemma:2b`: ~1.4GB download, fastest, basic quality
- `mistral`: ~4.1GB download, slower but better quality

**Recommendation:** Use `llama3.2` for the best balance.

### 6. Access Services

#### Open WebUI (Web Interface)

```bash
# Port-forward in the background
kubectl port-forward -n llm svc/open-webui 8080:8080 &

# Open in browser
open http://localhost:8080
```

#### Restaurant App

```bash
# Port-forward
kubectl port-forward -n llm svc/restaurant-app 3001:3001 &

# Test the API
curl http://localhost:3001/health

# Or use the NodePort (if using the minikube manifest)
MINIKUBE_IP=$(minikube ip)
curl http://${MINIKUBE_IP}:30001/health
```

#### Ollama API (Direct Access)

```bash
# Port-forward
kubectl port-forward -n llm svc/ollama 11434:11434 &

# Test
curl http://localhost:11434/api/tags
```

---

## Resource Monitoring

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n llm

# Detailed pod info
kubectl describe pod -n llm <pod-name>
```

### If Running Out of Memory

1. **Reduce Ollama memory limits:**
   Edit `kubernetes/ollama-deployment-minikube.yaml`:
   ```yaml
   resources:
     limits:
       memory: "2Gi"  # Reduce from 4Gi
   ```

2. **Use smaller models:**
   - Switch from `llama3.2` to `gemma:2b`

3. **Stop other services:**
   ```bash
   # Scale down Open WebUI if not using it
   kubectl scale deployment -n llm open-webui --replicas=0
   ```

4. **Allocate more RAM to Docker Desktop & minikube:**
   ```bash
   # First: Increase Docker Desktop memory to 10-12GB
   # Settings → Resources → Memory → Apply & Restart

   # Then recreate minikube with more memory
   minikube delete
   minikube start --cpus=4 --memory=9216  # 9GB (if Docker has 10GB+)
   ```

---

## Workflow: Experiment → Freeze → Push

### 1. Experiment with Parameters in Open WebUI

```bash
# Access Open WebUI
kubectl port-forward -n llm svc/open-webui 8080:8080
open http://localhost:8080

# Try different:
# - Models (llama3.2, phi3, etc.)
# - Temperature settings (0.2 = consistent, 0.8 = creative)
# - Top-p settings (0.9 = balanced, 0.95 = diverse)
# - System prompts
```

### 2. Freeze Your Configuration

Once you find the right parameters, create a Modelfile:

```bash
# Create kubernetes/modelfiles/my-model-v1.modelfile
cat > kubernetes/modelfiles/my-model-v1.modelfile <<'EOF'
FROM llama3.2

SYSTEM You are a restaurant operations assistant...

PARAMETER temperature 0.2
PARAMETER top_p 0.9
EOF
```

### 3. Build the Custom Model

```bash
# Copy Modelfile to Ollama pod
POD_NAME=$(kubectl get pod -n llm -l app=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl cp kubernetes/modelfiles/my-model-v1.modelfile llm/${POD_NAME}:/tmp/my-model.modelfile

# Build it
kubectl exec -n llm deployment/ollama -- ollama create my-model -f /tmp/my-model.modelfile

# Verify
kubectl exec -n llm deployment/ollama -- ollama list
```

### 4. Test the Custom Model

```bash
kubectl exec -n llm deployment/ollama -- ollama run my-model "Test prompt here"
```

### 5. (Optional) Push to Cloudsmith

If you want to share this model with other clusters:

```bash
./scripts/push-modelfile-to-cloudsmith.sh my-model v1.0.0
```

---

## Troubleshooting

### "Docker Desktop has only XXXXMB memory" Error

This means Docker Desktop doesn't have enough memory allocated.

**Fix:**
1. Open Docker Desktop
2. Settings → Resources → Memory
3. Increase to **8GB minimum** (10GB recommended)
4. Click "Apply & Restart"
5. Wait for Docker to fully restart
6. Try `./scripts/setup-minikube.sh` again

**Verify it worked:**
```bash
docker info | grep -i memory
# Should show >= 8GB total
```

### Minikube Won't Start

```bash
# Check Docker is running
docker ps

# Delete and recreate
minikube delete
minikube start --cpus=4 --memory=7168 --disk-size=20g
```

### Pods Stuck in Pending

```bash
# Check events
kubectl get events -n llm --sort-by='.lastTimestamp'

# Check node resources
kubectl describe nodes

# Common fix: Reduce resource requests in deployment manifests
```

### Ollama Pod OOMKilled (Out of Memory)

```bash
# Check logs
kubectl logs -n llm -l app=ollama --previous

# Reduce memory limits
kubectl edit deployment -n llm ollama

# Or redeploy with updated manifest
kubectl apply -f kubernetes/ollama-deployment-minikube.yaml
```

### Image Pull Errors

```bash
# Ensure you're using minikube's Docker
eval $(minikube docker-env)
docker images | grep restaurant-app

# Rebuild if missing
./scripts/build-for-minikube.sh

# Ensure imagePullPolicy is set correctly
kubectl get deployment -n llm restaurant-app -o yaml | grep imagePullPolicy
# Should be: imagePullPolicy: Never
```

### Can't Access Services

```bash
# Check pods are running
kubectl get pods -n llm

# Check service endpoints
kubectl get endpoints -n llm

# Kill existing port-forwards
pkill -f "kubectl port-forward"

# Create new port-forward
kubectl port-forward -n llm svc/open-webui 8080:8080
```

### Minikube Dashboard Not Opening

```bash
# Start dashboard
minikube dashboard

# If it doesn't open automatically
minikube dashboard --url
# Then visit the URL manually
```

---

## Daily Usage

### Starting Your Work Session

```bash
# Start minikube (if stopped)
minikube start

# Point Docker to minikube
eval $(minikube docker-env)

# Check status
kubectl get pods -n llm

# Port-forward services
kubectl port-forward -n llm svc/open-webui 8080:8080 &
kubectl port-forward -n llm svc/restaurant-app 3001:3001 &
```

### Pausing to Save Battery

```bash
# Pause (keeps state, saves CPU/battery)
minikube pause

# Resume later
minikube unpause
```

### Stopping for the Day

```bash
# Stop (preserves all data and config)
minikube stop

# Start again tomorrow
minikube start
```

### Clean Slate

```bash
# Delete everything
minikube delete

# Start fresh
./scripts/setup-minikube.sh
./scripts/deploy-minikube.sh
```

---

## Tips & Tricks

### 1. **Keep Models Between Restarts**

By default, models are lost when minikube is deleted. To persist them:

Edit `kubernetes/ollama-deployment-minikube.yaml`:
```yaml
volumes:
- name: ollama-data
  hostPath:
    path: /data/ollama  # Persists on minikube VM
    type: DirectoryOrCreate
```

### 2. **Use Kubernetes Dashboard**

```bash
minikube dashboard
```

Visual interface to see pods, logs, resource usage, etc.

### 3. **SSH into Minikube VM**

```bash
minikube ssh

# Check disk usage
df -h

# Check processes
top
```

### 4. **Use minikube service Command**

```bash
# Automatically opens service in browser
minikube service open-webui -n llm
```

### 5. **Check Minikube Logs**

```bash
minikube logs
minikube logs --file=minikube.log
```

### 6. **Set Resource Limits in Your Shell**

```bash
# In your .bashrc or .zshrc
export MINIKUBE_CPUS=4
export MINIKUBE_MEMORY=8192
export MINIKUBE_DISK=20g
```

---

## Comparison: Minikube vs Production Cluster

| Feature | Minikube | Production |
|---------|----------|------------|
| Resource Limits | Reduced (4Gi RAM) | Full (8Gi+ RAM) |
| Replicas | 1 per service | 2+ per service |
| Image Registry | Local Docker | External (e.g., Docker Hub) |
| Storage | emptyDir or hostPath | PersistentVolume |
| GPU | Not available | Optional |
| Load Balancer | NodePort | LoadBalancer |
| Monitoring | Basic (top) | Prometheus + Grafana |

---

## Next Steps

Once you've tested on minikube and are ready for production:

1. **Push images to a registry:**
   ```bash
   docker tag restaurant-app:latest your-registry.com/restaurant-app:v1.0.0
   docker push your-registry.com/restaurant-app:v1.0.0
   ```

2. **Update manifests** to use production images and resources

3. **Deploy to production cluster:**
   ```bash
   kubectl apply -f kubernetes/  # Uses production manifests
   ```

4. **Set up monitoring, backups, and CI/CD**

---

## Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Minikube Handbook](https://minikube.sigs.k8s.io/docs/handbook/)
- [Troubleshooting Guide](https://minikube.sigs.k8s.io/docs/handbook/troubleshooting/)
- [Main README](README.md)

---

**Ready to start?** Run: `./scripts/setup-minikube.sh`
