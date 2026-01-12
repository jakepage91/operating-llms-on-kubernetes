# Development Workflow Guide

A detailed, step-by-step guide to working with this LLM-powered restaurant operations platform.

---

## Overview: The Four Phases

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Phase 1   │────>│   Phase 2   │────>│   Phase 3   │────>│   Phase 4   │
│   Deploy    │     │  Experiment │     │   Freeze    │     │   Store     │
│   Runtime   │     │   Locally   │     │  Behavior   │     │  & Version  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

1. **Deploy Runtime**: Get Ollama running in Kubernetes
2. **Experiment Locally**: Iterate on prompts and parameters using mirrord
3. **Freeze Behavior**: Lock in your final config as a Modelfile
4. **Store & Version**: Save and distribute your custom model

---

## Phase 1: Deploy the Runtime

### Goal
Get Ollama running in Kubernetes with a base model loaded.

### Steps

#### 1.1. Deploy Ollama to Kubernetes
```bash
./scripts/deploy-ollama.sh
```

This will:
- Create the `llm` namespace
- Deploy the Ollama pod
- Create a ClusterIP service on port 11434
- Wait for the pod to be ready

**Expected output**:
```
🚀 Deploying Ollama to Kubernetes...
📦 Creating namespace...
📦 Deploying Ollama...
📦 Creating service...
✅ Ollama deployed successfully!
```

#### 1.2. Verify the Deployment
```bash
kubectl get pods -n llm
```

**Expected output**:
```
NAME                      READY   STATUS    RESTARTS   AGE
ollama-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

#### 1.3. Check the Logs
```bash
kubectl logs -n llm -l app=ollama -f
```

You should see Ollama starting up and listening on port 11434.

#### 1.4. Pull a Base Model
```bash
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2
```

**Time**: 2-10 minutes depending on network speed and model size.

**Alternative models**:
- `mistral` - 7B params, strong reasoning
- `phi3` - 3B params, very fast
- `codellama` - Code-focused (not ideal for restaurant ops)

#### 1.5. List Available Models
```bash
kubectl exec -n llm deployment/ollama -- ollama list
```

**Expected output**:
```
NAME           SIZE    MODIFIED
llama3.2       2.0GB   2 minutes ago
```

---

## Phase 2: Experiment Locally

### Goal
Run the restaurant app locally while connecting to the in-cluster Ollama, iterating rapidly on prompts and parameters.

### Prerequisites
- Ollama deployed and model pulled (Phase 1 complete)
- Mirrord installed
- Node.js 18+ installed

### Steps

#### 2.1. Install Dependencies
```bash
./scripts/setup-local-dev.sh
```

This will:
- Check prerequisites (node, npm, kubectl, mirrord)
- Install backend dependencies (`restaurant-app/backend`)
- Install frontend dependencies (`restaurant-app/frontend`)
- Verify cluster access

#### 2.2. Start the Backend (with mirrord)

Open a terminal and run:
```bash
cd restaurant-app/backend
mirrord exec --config ../../mirrord/config.json -- npm run dev
```

**What's happening**:
- Mirrord intercepts network calls from the backend
- DNS resolution works (e.g., `ollama` → cluster IP)
- Outgoing HTTP requests to Ollama are routed through the cluster

**Expected output**:
```
🍽️  Restaurant LLM Backend running on port 3001
📡 Ollama host: http://ollama:11434
```

**Troubleshooting**:
- If mirrord fails, check cluster access: `kubectl auth can-i get pods -n llm`
- If DNS doesn't resolve, check the service: `kubectl get svc -n llm ollama`

#### 2.3. Start the Frontend

Open **another terminal** and run:
```bash
cd restaurant-app/frontend
npm run dev
```

**Expected output**:
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
```

#### 2.4. Test the Backend API
```bash
./scripts/test-restaurant-api.sh
```

This will:
1. Hit `/health` to verify connectivity
2. Fetch sample orders from `/api/sample-orders`
3. Generate recommendations via `/api/recommendations`

**Expected output**:
```
✅ Ollama connection healthy
✅ Received 5 sample orders
✅ Recommendations generated successfully!
```

#### 2.5. Open the Frontend in a Browser
Navigate to: **http://localhost:5173**

You should see:
- A "Connected to Ollama" badge (green)
- Sliders for temperature and top_p
- A "Generate Recommendations" button

#### 2.6. Generate Your First Recommendations
1. Click "Generate Recommendations"
2. Wait ~5-10 seconds (LLM inference time)
3. See the summary, recommendations, and staff notifications appear

**Example output**:
```
📊 Summary
• 5 orders tonight with a focus on salads and grilled items
• Caesar Salad is the most popular appetizer (2 orders)

💡 Recommendations
• Prep extra Caesar dressing for the evening rush
• Pre-grill chicken and salmon to reduce wait times
• Check steak inventory - medium-rare requests coming in

🔔 Staff Notifications
• Table 5 has a no-croutons special request - update POS
```

#### 2.7. Iterate on Parameters
Now the fun part: **see how parameters affect outputs**.

**Experiment 1: Temperature**
- Set temperature to **0.0** (deterministic)
- Generate recommendations
- Set temperature to **1.5** (creative)
- Generate again
- **Notice**: Lower temps = consistent, predictable advice. Higher temps = more varied, creative.

**Experiment 2: Top-p**
- Set top_p to **0.5** (focused)
- Generate recommendations
- Set top_p to **1.0** (diverse)
- Generate again
- **Notice**: Lower top_p = more conservative word choices. Higher top_p = more varied vocabulary.

**Experiment 3: Model**
If you pulled multiple models:
- Change "Model" field to `mistral`
- Generate recommendations
- **Notice**: Different models have different "personalities" and reasoning styles.

#### 2.8. Iterate on the System Prompt

The real power is in the prompt. Let's customize it.

**Edit** `restaurant-app/backend/src/index.ts`:
```typescript
const SYSTEM_PROMPT = `You are a restaurant operations assistant specializing in fine dining.

Response format:
**SUMMARY:**
[Elegant 2-3 bullet points about tonight's service]

**RECOMMENDATIONS:**
[3-4 refined suggestions for kitchen and front-of-house]

**STAFF NOTIFICATIONS:**
[1-2 priority items for immediate attention]

Maintain a sophisticated, professional tone. Use culinary terminology.`;
```

**Save the file** (tsx watch will auto-reload the backend).

**Generate recommendations again** and notice the tone change:
- Before: "Kitchen language", direct, no-nonsense
- After: "Sophisticated", culinary terminology, elegant phrasing

**Try other variations**:
- **Casual**: "Dude, you're the kitchen manager. Here's what's up..."
- **Urgent**: "ALERT: Critical kitchen updates for tonight's service..."
- **Metrics-focused**: "KPIs for tonight: Order volume: 5..."

**Key insight**: The system prompt is your most powerful tool for shaping behavior.

#### 2.9. Iterate on Sample Orders

**Edit** `restaurant-app/backend/src/index.ts`:
```typescript
const SAMPLE_ORDERS: Order[] = [
  {
    id: 'ord-001',
    table: 5,
    items: ['Lobster Bisque', 'Wagyu Steak', 'Truffle Risotto'],
    specialRequests: 'Allergic to shellfish (skip lobster)',
    timestamp: new Date().toISOString(),
  },
  // ... add more orders
];
```

**Save** and test again. Notice how the LLM adapts to:
- Different menu items
- Special requests (allergies, dietary restrictions)
- Order volume (1 order vs 50 orders)

---

## Phase 3: Freeze the Behavior

### Goal
Once you're satisfied with the prompt + parameters, lock them into a Modelfile for reproducible deployment.

### Steps

#### 3.1. Record Your Final Configuration
After iterating, you've settled on:
- **System prompt**: Your final version (in `backend/src/index.ts`)
- **Temperature**: e.g., 0.2
- **Top_p**: e.g., 0.9
- **Base model**: e.g., `llama3.2`

#### 3.2. Create a Modelfile

Create a new file: `kubernetes/modelfiles/restaurant-chef-v1.modelfile`

```dockerfile
FROM llama3.2

SYSTEM You are a restaurant operations assistant. Provide direct, actionable recommendations in kitchen language. No pleasantries. Focus on efficiency and food safety. Use bullet points for clarity.

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 2048
PARAMETER repeat_penalty 1.1
```

**Explanation**:
- `FROM llama3.2` - Base model (must be pulled already)
- `SYSTEM <prompt>` - Your final system prompt
- `PARAMETER ...` - Your tuned parameters

#### 3.3. Build the Custom Model in the Cluster

**Copy the Modelfile into the pod**:
```bash
POD_NAME=$(kubectl get pod -n llm -l app=ollama -o jsonpath='{.items[0].metadata.name}')
kubectl cp kubernetes/modelfiles/restaurant-chef-v1.modelfile llm/${POD_NAME}:/tmp/restaurant-chef.modelfile
```

**Build the model**:
```bash
kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /tmp/restaurant-chef.modelfile
```

**Expected output**:
```
success
```

**Verify it's created**:
```bash
kubectl exec -n llm deployment/ollama -- ollama list
```

You should see:
```
NAME               SIZE    MODIFIED
restaurant-chef    2.0GB   10 seconds ago
llama3.2           2.0GB   1 hour ago
```

#### 3.4. Update Your App to Use the Custom Model

**Edit** `restaurant-app/backend/src/index.ts`:
```typescript
// Change this line:
model = 'llama3.2',

// To:
model = 'restaurant-chef',
```

Or just update the frontend UI to use `restaurant-chef` as the model name.

#### 3.5. Test the Custom Model
```bash
./scripts/test-restaurant-api.sh
```

Or use the frontend - change the "Model" field to `restaurant-chef` and generate.

**Result**: You should get the same behavior as your iterated config, but now it's **frozen and reproducible**.

---

## Phase 4: Store and Version

### Goal
Save your custom model for reuse, distribution, and version control.

### Steps

#### 4.1. Export the Model
```bash
kubectl exec -n llm deployment/ollama -- ollama save restaurant-chef > restaurant-chef-v1.tar
```

**Size**: ~2GB (same as base model, since it's just a wrapped config).

#### 4.2. Push to a Registry

**Option 1: Cloudsmith** (for private models):
```bash
cloudsmith push ollama your-org/llm-models restaurant-chef-v1.tar
```

**Option 2: S3** (simple, works for any cloud):
```bash
aws s3 cp restaurant-chef-v1.tar s3://your-bucket/models/restaurant-chef-v1.tar
```

**Option 3: Docker Hub** (public):
```bash
# Not directly supported, but you can wrap it in a container image
```

#### 4.3. Version the Modelfile in Git
```bash
git add kubernetes/modelfiles/restaurant-chef-v1.modelfile
git commit -m "Add restaurant-chef-v1 Modelfile"
git tag v1.0.0-restaurant-chef
git push --tags
```

**Why**:
- Auditability: See what changed over time
- Rollback: Revert to previous versions
- Collaboration: Share with your team

#### 4.4. Document the Model

Create `kubernetes/modelfiles/restaurant-chef-v1.README.md`:
```markdown
# Restaurant Chef v1.0.0

## Description
Custom Ollama model for restaurant operations recommendations.

## Base Model
llama3.2 (3B parameters)

## Parameters
- Temperature: 0.2 (deterministic)
- Top-p: 0.9 (balanced sampling)
- Context: 2048 tokens

## System Prompt
Focuses on:
- Kitchen efficiency
- Food safety
- Direct, actionable language

## Performance
- Inference time: ~5-10s per request
- Quality: Consistent, practical advice

## Changelog
- v1.0.0 (2024-01-15): Initial release
```

#### 4.5. Deploy to Another Cluster

On a different cluster:
1. **Deploy Ollama** (Phase 1)
2. **Pull the model** from registry:
   ```bash
   aws s3 cp s3://your-bucket/models/restaurant-chef-v1.tar .
   kubectl cp restaurant-chef-v1.tar llm/${POD_NAME}:/tmp/
   kubectl exec -n llm deployment/ollama -- ollama import restaurant-chef /tmp/restaurant-chef-v1.tar
   ```
3. **Update your app** to use `restaurant-chef`

**Result**: Instant deployment of your exact configuration, no re-tuning needed.

---

## Advanced Workflows

### A/B Testing Different Prompts
1. Create two Modelfiles: `restaurant-chef-v1` and `restaurant-chef-v2`
2. Build both models in the cluster
3. Update your app to randomly select between them
4. Collect metrics (response time, user feedback)
5. Pick the winner

### Continuous Improvement
1. Collect feedback from users ("Was this helpful?")
2. Store problematic orders + responses
3. Periodically review and refine the prompt
4. Create a new version (v1.1, v1.2, etc.)
5. A/B test against the previous version

### RAG (Retrieval-Augmented Generation)
Add a knowledge base for more context:
1. Store past orders + recommendations in a vector database (e.g., ChromaDB)
2. On each request, search for similar past scenarios
3. Include them in the prompt: "Similar past orders: ..."
4. The LLM uses this context to make better recommendations

**Example**:
```
Tonight's orders: [current orders]

Similar past orders:
- 2024-01-10: Heavy seafood orders → Recommendation: Prep extra cocktail sauce
- 2024-01-08: Multiple steak orders → Recommendation: Check A1 sauce inventory

Analyze tonight's orders and provide recommendations.
```

### Fine-Tuning (Advanced)
For even more customization, train a LoRA adapter:
1. Collect 50-100 examples of ideal input/output pairs
2. Fine-tune on top of the base model using Ollama's training API
3. Freeze into a Modelfile with `ADAPTER`

**Note**: This is overkill for most use cases. Prompt engineering (Phase 2-3) is usually sufficient.

---

## Troubleshooting Common Issues

### Issue: LLM responses are inconsistent
**Solution**: Lower temperature (try 0.1-0.3).

### Issue: LLM responses are repetitive/boring
**Solution**: Raise temperature (try 0.5-0.8) and top_p (try 0.95).

### Issue: LLM ignores the system prompt
**Solution**:
- Make the prompt more explicit: "You MUST use this format: ..."
- Add examples in the prompt (few-shot learning)
- Try a different base model (some follow instructions better)

### Issue: LLM is too slow
**Solutions**:
- Use a smaller model (llama3.2 3B instead of 70B)
- Add GPU to the Ollama pod (uncomment GPU limits in `ollama-deployment.yaml`)
- Reduce context window (`num_ctx: 1024` instead of 4096)

### Issue: Model fails to load (OOM)
**Solution**: Increase memory limits in `kubernetes/ollama-deployment.yaml`:
```yaml
resources:
  limits:
    memory: "16Gi"  # Increase from 8Gi
```

---

## Best Practices Summary

1. **Start simple**: Use a small model (llama3.2) and minimal prompt.
2. **Iterate rapidly**: Use mirrord for instant feedback.
3. **Be specific**: The more explicit your prompt, the better.
4. **Use examples**: Show the LLM what you want (few-shot learning).
5. **Tune temperature**: Lower for consistency, higher for creativity.
6. **Freeze early**: Once it works, lock it into a Modelfile.
7. **Version everything**: Modelfiles in git, models in a registry.
8. **Monitor in production**: Track response time, quality, and errors.

---

## What's Next?

- **Add more apps**: Create other LLM-powered tools (inventory management, menu generation, etc.)
- **Integrate with databases**: Store orders, responses, and feedback
- **Add auth**: Secure the API with JWT or OAuth
- **Deploy to production**: Containerize the backend/frontend and run in K8s
- **Scale Ollama**: Add more replicas or use a model serving platform (vLLM, TGI)

---

**Ready to deploy?** Return to the [main README](../README.md) for the quick start guide.
