# Deploy Full Stack (Backend + Frontend)

Complete guide for deploying both the backend and frontend of the restaurant application.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Kubernetes (namespace: llm)                    │
│                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ Frontend │───>│ Backend  │───>│  Ollama  │  │
│  │ (nginx)  │    │(Express) │    │(Runtime) │  │
│  │  :80     │    │  :3001   │    │  :11434  │  │
│  └──────────┘    └──────────┘    └──────────┘  │
└─────────────────────────────────────────────────┘
      ↓                ↓                 ↓
   NodePort        ClusterIP        ClusterIP
   :30080           :3001            :11434
```

## Quick Start

```bash
# 1. Setup minikube (if not done)
./scripts/setup-minikube.sh

# 2. Point Docker to minikube
eval $(minikube docker-env)

# 3. Build BOTH backend and frontend images
./scripts/build-for-minikube.sh

# 4. Deploy everything
./scripts/deploy-minikube.sh

# 5. Access the frontend
MINIKUBE_IP=$(minikube ip)
open http://${MINIKUBE_IP}:30080

# Or use port-forward
kubectl port-forward -n llm svc/restaurant-app-frontend 8080:80
open http://localhost:8080
```

---

## Step-by-Step Guide

### 1. Build Backend Image

```bash
eval $(minikube docker-env)
cd restaurant-app/backend
docker build -t restaurant-app-backend:latest .
cd ../..
```

**What it does:**
- Installs Node.js dependencies
- Compiles TypeScript to JavaScript
- Creates production image with only runtime dependencies

### 2. Build Frontend Image

```bash
eval $(minikube docker-env)
cd restaurant-app/frontend
docker build -t restaurant-app-frontend:latest .
cd ../..
```

**What it does:**
- Installs Node.js dependencies
- Builds React app (Vite production build)
- Creates nginx image serving static files
- Configures nginx to proxy `/api/*` to backend

### 3. Verify Images

```bash
docker images | grep restaurant-app
```

You should see:
```
restaurant-app-backend    latest    ...    ...    ...
restaurant-app-frontend   latest    ...    ...    ...
```

### 4. Deploy Backend

```bash
kubectl apply -f kubernetes/restaurant-app-backend-minikube.yaml
```

This creates:
- **Deployment**: `restaurant-app-backend` (1 replica)
- **Service**: `restaurant-app-backend` (ClusterIP on port 3001)

### 5. Deploy Frontend

```bash
kubectl apply -f kubernetes/restaurant-app-frontend-minikube.yaml
```

This creates:
- **Deployment**: `restaurant-app-frontend` (1 replica)
- **Service**: `restaurant-app-frontend` (NodePort on port 30080)

### 6. Verify Deployment

```bash
kubectl get pods -n llm
```

Expected output:
```
NAME                                       READY   STATUS    RESTARTS   AGE
ollama-xxx                                 1/1     Running   0          5m
open-webui-xxx                             1/1     Running   0          5m
restaurant-app-backend-xxx                 1/1     Running   0          1m
restaurant-app-frontend-xxx                1/1     Running   0          1m
```

### 7. Access the Application

**Option 1: NodePort (easiest)**
```bash
MINIKUBE_IP=$(minikube ip)
echo "Frontend: http://${MINIKUBE_IP}:30080"
open http://${MINIKUBE_IP}:30080
```

**Option 2: Port-forward (alternative)**
```bash
kubectl port-forward -n llm svc/restaurant-app-frontend 8080:80
open http://localhost:8080
```

---

## How the Frontend Works

### Development Mode (npm run dev)
- Vite dev server runs on port 5173
- Vite proxies `/api/*` requests to backend at `localhost:3001`
- Hot module replacement (HMR) for instant updates

### Production Mode (Docker + nginx)
- React app built into static files (HTML, CSS, JS)
- nginx serves static files on port 80
- nginx proxies `/api/*` requests to `restaurant-app-backend:3001`
- No JavaScript server needed (just static files)

### nginx Configuration

The `nginx.conf` file:
- Serves static files from `/usr/share/nginx/html`
- Proxies `/api/*` → `http://restaurant-app-backend:3001/api/*`
- Proxies `/health` → `http://restaurant-app-backend:3001/health`
- Handles SPA routing (serves `index.html` for all routes)
- Caches static assets for 1 year

---

## Testing the Application

### Test Backend API Directly

```bash
kubectl port-forward -n llm svc/restaurant-app-backend 3001:3001

# Health check
curl http://localhost:3001/health

# Get sample orders
curl http://localhost:3001/api/sample-orders

# Generate recommendations
curl -X POST http://localhost:3001/api/recommendations \
  -H "Content-Type: application/json" \
  -d '{"temperature": 0.2, "top_p": 0.9, "model": "llama3.2"}'
```

### Test Frontend

1. **Access the UI:**
   ```bash
   MINIKUBE_IP=$(minikube ip)
   open http://${MINIKUBE_IP}:30080
   ```

2. **You should see:**
   - Parameter knobs (temperature, top-p, model)
   - "Generate Recommendations" button
   - Health status badge

3. **Test the workflow:**
   - Adjust temperature slider
   - Click "Generate Recommendations"
   - See the summary, recommendations, and notifications

### Test Frontend → Backend → Ollama Chain

```bash
# Get all pod names
kubectl get pods -n llm

# Check frontend logs
kubectl logs -n llm -l app=restaurant-app-frontend

# Check backend logs
kubectl logs -n llm -l app=restaurant-app-backend

# Check Ollama logs
kubectl logs -n llm -l app=ollama
```

---

## Troubleshooting

### Backend pod not starting

```bash
# Check events
kubectl describe pod -n llm -l app=restaurant-app-backend

# Check logs
kubectl logs -n llm -l app=restaurant-app-backend

# Common issue: Image not found
# Fix: Ensure you ran `eval $(minikube docker-env)` before building
```

### Frontend pod not starting

```bash
# Check events
kubectl describe pod -n llm -l app=restaurant-app-frontend

# Check logs
kubectl logs -n llm -l app=restaurant-app-frontend

# Common issue: Image not found
# Fix: Rebuild with minikube's Docker
eval $(minikube docker-env)
./scripts/build-for-minikube.sh
```

### Frontend shows "Failed to fetch"

```bash
# Check backend is running
kubectl get pods -n llm -l app=restaurant-app-backend

# Check backend service
kubectl get svc -n llm restaurant-app-backend

# Test backend directly
kubectl port-forward -n llm svc/restaurant-app-backend 3001:3001
curl http://localhost:3001/health
```

### nginx 502 Bad Gateway

This means nginx can't reach the backend.

```bash
# Check backend service exists
kubectl get svc -n llm restaurant-app-backend

# Check backend pods are ready
kubectl get pods -n llm -l app=restaurant-app-backend

# Exec into frontend pod and test
kubectl exec -n llm -it $(kubectl get pod -n llm -l app=restaurant-app-frontend -o jsonpath='{.items[0].metadata.name}') -- sh
wget -O- http://restaurant-app-backend:3001/health
```

---

## Rebuild and Redeploy

If you make changes to the code:

```bash
# 1. Rebuild images
eval $(minikube docker-env)
./scripts/build-for-minikube.sh

# 2. Restart pods (forces pull of new images)
kubectl rollout restart deployment -n llm restaurant-app-backend
kubectl rollout restart deployment -n llm restaurant-app-frontend

# 3. Watch rollout
kubectl rollout status deployment -n llm restaurant-app-backend
kubectl rollout status deployment -n llm restaurant-app-frontend
```

---

## Resource Usage

```bash
# Check pod resource usage
kubectl top pods -n llm

# Expected usage (approximate):
# - Backend: 100-200MB RAM, 0.1-0.3 CPU
# - Frontend: 20-50MB RAM, 0.01-0.05 CPU
```

---

## Production Deployment

For production (not minikube), you need to:

1. **Push images to a registry:**
   ```bash
   docker tag restaurant-app-backend:latest your-registry.com/restaurant-app-backend:v1.0.0
   docker tag restaurant-app-frontend:latest your-registry.com/restaurant-app-frontend:v1.0.0
   docker push your-registry.com/restaurant-app-backend:v1.0.0
   docker push your-registry.com/restaurant-app-frontend:v1.0.0
   ```

2. **Update manifests** to use production images and remove `imagePullPolicy: Never`

3. **Create production manifests** without `-minikube` suffix

4. **Deploy:**
   ```bash
   kubectl apply -f kubernetes/restaurant-app-backend-deployment.yaml
   kubectl apply -f kubernetes/restaurant-app-frontend-deployment.yaml
   ```

---

## Next Steps

- Add authentication (JWT)
- Add database for storing orders
- Add logging and monitoring
- Set up CI/CD pipeline
- Add ingress controller
- Configure custom domain

---

**Need help?** Check the main [README.md](README.md) or [MINIKUBE.md](MINIKUBE.md)
