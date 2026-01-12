# Quick Start for Minikube (Updated for Your Setup)

## 🚨 Important: Configure Docker Desktop First!

Your Docker Desktop only has **~7.8GB** allocated. You need to increase it:

1. **Open Docker Desktop**
2. **Click Settings (gear icon)**
3. **Go to Resources → Memory**
4. **Set Memory to 8GB or higher**
   - 8GB = minimum (tight but works)
   - 10GB = recommended (comfortable)
   - 12GB = ideal (plenty of headroom)
5. **Click "Apply & Restart"**
6. **Wait for Docker to restart** (this takes 1-2 minutes)

**Verify it worked:**
```bash
docker info | grep -i memory
# Should show at least 8GB total
```

---

## Then Run These Commands

```bash
# 1. Setup minikube (now it will work!)
./scripts/setup-minikube.sh

# 2. Point Docker to minikube
eval $(minikube docker-env)

# 3. Build restaurant app image
./scripts/build-for-minikube.sh

# 4. Deploy everything
./scripts/deploy-minikube.sh

# 5. Pull a small model (this will take 2-5 minutes)
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# 6. Access Open WebUI
kubectl port-forward -n llm svc/open-webui 8080:8080 &
open http://localhost:8080
```

---

## What Changed

- **Memory allocation**: Reduced from 8GB to **7GB** to leave headroom
- **Script now checks** Docker Desktop's available memory
- **Auto-adjusts** if Docker doesn't have enough
- **Better error messages** telling you how to fix it

---

## Resource Allocation After Docker Desktop is Set to 10GB

```
Your Mac: 16GB Total RAM
├── macOS + Running Apps: ~6GB
└── Docker Desktop: 10GB (you configure this)
    └── Minikube: 7GB (leaves 3GB buffer in Docker)
        ├── Ollama: 1-4GB (most of it)
        ├── Open WebUI: 512MB
        ├── Restaurant App: 256MB
        └── Kubernetes: 500MB
```

This leaves plenty of headroom for everything to run smoothly!

---

## Current Recommended Models for Your Setup

Once Ollama is running, use these models (in order of preference):

```bash
# Best balance: quality + speed
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# Faster, smaller (if resources are tight)
kubectl exec -n llm deployment/ollama -- ollama pull phi3

# Smallest (if really tight on resources)
kubectl exec -n llm deployment/ollama -- ollama pull gemma:2b
```

**Avoid these** (too large for local testing):
- ❌ `mistral` (4.1GB, slower)
- ❌ `llama3:70b` (way too big)
- ❌ `codellama` (specialized, not great for restaurant ops)

---

## Troubleshooting

### Still getting "Docker Desktop has only XXXXMB memory" error?

Docker Desktop might not have restarted properly:

1. Quit Docker Desktop completely (Cmd+Q)
2. Wait 10 seconds
3. Reopen Docker Desktop
4. Wait for the whale icon to stop animating
5. Run: `docker info | grep -i memory`
6. Should now show the new value

### Can't allocate 8GB+ to Docker?

Your machine might have other things using RAM:

1. Close unnecessary apps (Chrome, Slack, etc.)
2. Check Activity Monitor for memory hogs
3. Try setting Docker to 8GB (minimum)
4. Minikube script will auto-adjust to ~7GB

---

## Next Steps After Everything is Running

1. **Open WebUI at http://localhost:8080**
2. **Select model** (llama3.2)
3. **Test the restaurant operations prompt:**
   ```
   You are a restaurant operations assistant. Analyze tonight's orders and provide:
   - A brief summary of trends
   - 3-4 actionable recommendations for kitchen prep
   - Any urgent staff notifications

   Be concise, direct, and use kitchen language. No pleasantries.
   ```
4. **Try different temperature settings** (0.2 vs 0.8)
5. **Note what works best**
6. **Create a Modelfile** with your final config (see main README)

---

**Ready?** Increase Docker Desktop memory to 8GB+, then run `./scripts/setup-minikube.sh`
