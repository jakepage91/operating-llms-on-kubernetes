# Restaurant Operations App

A minimal demonstration app showing how to integrate Ollama LLM into a restaurant operations workflow.

## Overview

This app consists of:
- **Backend** (Node/Express): REST API that calls Ollama for recommendations
- **Frontend** (Vite/React): UI for tuning parameters and viewing results

## Architecture

```
┌─────────────────┐      HTTP       ┌─────────────────┐     HTTP      ┌──────────────┐
│  Frontend       │  ────────────>  │  Backend        │ ────────────> │  Ollama      │
│  (React)        │   /api/recs     │  (Express)      │  port 11434   │  (K8s)       │
│  localhost:5173 │                 │  localhost:3001 │               │  llm/ollama  │
└─────────────────┘                 └─────────────────┘               └──────────────┘
```

## Quick Start

### Prerequisites
- Node.js 18+
- kubectl with access to your cluster
- mirrord installed
- Ollama deployed in the `llm` namespace

### 1. Deploy Ollama (if not done already)
```bash
cd ../../kubernetes
kubectl apply -f namespace.yaml
kubectl apply -f ollama-deployment.yaml
kubectl apply -f ollama-service.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=ollama -n llm --timeout=120s

# Pull a model
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2
```

### 2. Run Backend
```bash
cd backend
npm install
mirrord exec --config ../../mirrord/config.json -- npm run dev
```

You should see:
```
🍽️  Restaurant LLM Backend running on port 3001
📡 Ollama host: http://ollama:11434
```

### 3. Run Frontend (in another terminal)
```bash
cd frontend
npm install
npm run dev
```

You should see:
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
```

### 4. Open Browser
Navigate to **http://localhost:5173**

You should see:
- Health indicator showing "Connected to Ollama"
- Parameter sliders for temperature and top_p
- "Generate Recommendations" button

### 5. Test It
1. Click "Generate Recommendations"
2. Wait ~5-10 seconds (LLM inference time)
3. See the summary, recommendations, and staff notifications appear
4. Adjust temperature slider and generate again - notice the difference!

## Features

### Backend (`/backend`)
- Exposes REST API for recommendations
- Connects to Ollama via cluster DNS (`ollama:11434`)
- Provides sample orders for testing
- Configurable system prompt (for iteration)

See [backend/README.md](./backend/README.md) for details.

### Frontend (`/frontend`)
- Interactive parameter tuning (temperature, top_p, model)
- Real-time health check display
- Formatted output display (summary, recommendations, notifications)
- Responsive design

See [frontend/README.md](./frontend/README.md) for details.

## Development Workflow

### Iterating on the System Prompt
1. Edit `backend/src/index.ts` → `SYSTEM_PROMPT` constant
2. Save (tsx will auto-reload)
3. Generate recommendations in the UI
4. Repeat until satisfied
5. Freeze into a Modelfile (see main README)

### Iterating on Parameters
1. Use the sliders in the frontend
2. Click "Generate Recommendations" after each change
3. Compare outputs side-by-side (open multiple tabs)
4. Once you find the sweet spot, record the values
5. Freeze into a Modelfile with those parameter defaults

### Iterating on Orders
1. Edit `backend/src/index.ts` → `SAMPLE_ORDERS` array
2. Add more orders, change items, add special requests
3. Test how the LLM adapts to different scenarios

## Example: Freezing Behavior into a Modelfile

Once you're happy with:
- System prompt
- Temperature (e.g., 0.2)
- Top-p (e.g., 0.9)

Create a Modelfile:
```dockerfile
FROM llama3.2

SYSTEM You are a concise restaurant operations assistant. Provide direct, actionable recommendations in kitchen language. No pleasantries. Focus on efficiency and food safety. Use bullet points for clarity.

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 2048
```

Build it in-cluster:
```bash
kubectl cp restaurant-chef.modelfile llm/ollama-<pod-id>:/tmp/restaurant-chef.modelfile
kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /tmp/restaurant-chef.modelfile
```

Update the backend to use it:
```typescript
// In src/index.ts, change the default model:
model = 'restaurant-chef'
```

Or change it in the frontend UI!

## Testing Without the Frontend

Use curl to test the backend directly:
```bash
curl -X POST http://localhost:3001/api/recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "temperature": 0.3,
    "top_p": 0.9,
    "model": "llama3.2"
  }'
```

Or use the test script:
```bash
cd ../..
./scripts/test-restaurant-api.sh
```

## Troubleshooting

### Backend can't connect to Ollama
- Ensure mirrord is running: `mirrord exec --config ... -- npm run dev`
- Check Ollama is healthy: `kubectl get pods -n llm`
- Test DNS resolution: `kubectl exec -n llm deployment/ollama -- nslookup ollama`

### Frontend can't reach backend
- Ensure backend is running on port 3001
- Check Vite proxy config in `frontend/vite.config.ts`
- Open browser dev console for errors

### LLM responses are too random
- Lower temperature (try 0.1-0.3)
- Lower top_p (try 0.7-0.85)

### LLM responses are too repetitive
- Raise temperature (try 0.5-0.8)
- Raise top_p (try 0.95-1.0)

## Next Steps

1. **Add more endpoints**: Orders CRUD, historical analysis, etc.
2. **Add a database**: Store orders, responses, and feedback
3. **Add auth**: Secure the API with JWT or OAuth
4. **Deploy to K8s**: Containerize the backend/frontend and deploy alongside Ollama
5. **Add RAG**: Use a vector DB to search past orders and recommendations
6. **Add fine-tuning**: Train a LoRA adapter on your restaurant's specific data

## License

MIT
