# Glossary

A comprehensive guide to key terms and concepts used in this project.

## Core Technologies

### Ollama
**Definition**: A runtime environment for running large language models locally or in containers.

**Think of it as**: "Docker for LLMs" - it packages and runs AI models with a simple API.

**Key features**:
- Pull models from a registry (like Docker images)
- Serve models via REST API
- Create custom models with Modelfiles
- Manage multiple models simultaneously

**Example usage**:
```bash
ollama pull llama3.2
ollama run llama3.2 "Tell me a joke"
ollama list  # Show all downloaded models
```

---

### LLM (Large Language Model)
**Definition**: A neural network trained on massive amounts of text to understand and generate human-like language.

**Examples**: GPT-4, Claude, LLaMA, Mistral

**In this project**: We use LLaMA models via Ollama for restaurant operations insights.

---

### Runtime
**Definition**: The service that loads models into memory and handles inference requests.

**In this project**: Ollama is the runtime, running in Kubernetes.

**Key distinction**: The runtime (Ollama) is separate from the models it serves (llama3.2, mistral, etc.).

**Analogy**:
- **Runtime** = Web server (nginx, Apache)
- **Model** = Website content (HTML, JS, CSS)

---

### Model
**Definition**: The actual AI weights/parameters that define behavior.

**Where they come from**: Trained by research labs (Meta, Mistral, etc.) and distributed via registries.

**Size**: Ranges from 1GB (small) to 100GB+ (large).

**In Ollama**: Downloaded with `ollama pull <model-name>`.

---

### Modelfile
**Definition**: A declarative configuration file that defines a custom model's behavior.

**Similar to**: Dockerfile (for Docker images)

**Structure**:
```dockerfile
FROM llama3.2                    # Base model
SYSTEM <prompt>                  # System instructions
PARAMETER temperature 0.2        # Inference parameters
PARAMETER top_p 0.9
```

**Purpose**: Freeze your iterated prompt + parameters into a versioned, deployable artifact.

**Creation**:
```bash
ollama create my-custom-model -f Modelfile
```

---

### Open WebUI
**Definition**: An open-source web interface for interacting with Ollama.

**Think of it as**: "ChatGPT UI for Ollama"

**Features**:
- Chat interface
- Prompt templates
- Model management
- RAG (Retrieval-Augmented Generation)

**In this project**: Vendored via git subtree for local iteration.

---

## Kubernetes Concepts

### Namespace
**Definition**: A logical isolation boundary in Kubernetes.

**In this project**: We use the `llm` namespace to separate Ollama resources from other workloads.

**Why**: Keeps things organized and prevents name collisions.

---

### Deployment
**Definition**: A Kubernetes resource that manages a set of replica pods.

**In this project**: The `ollama` deployment manages the Ollama runtime pod(s).

**Features**:
- Self-healing (restarts failed pods)
- Rolling updates
- Scaling (increase/decrease replicas)

---

### Service
**Definition**: A stable network endpoint for accessing pods.

**In this project**: The `ollama` service exposes port 11434 for API access.

**DNS name**: `ollama.llm.svc.cluster.local` (or just `ollama` from within the same namespace)

**Type**: ClusterIP (internal only, not exposed outside the cluster)

---

### ConfigMap
**Definition**: A Kubernetes object for storing non-sensitive configuration data.

**In this project**: We use ConfigMaps to store example Modelfiles.

**Why not Secrets?**: Modelfiles aren't sensitive (they're prompts and parameters, not credentials).

---

## Development Tools

### Mirrord
**Definition**: A tool that runs local processes as if they were inside a Kubernetes cluster.

**Purpose**: Enables local development with access to cluster-internal services.

**How it works**:
1. Intercepts network calls from your local process
2. Tunnels them through the Kubernetes API server
3. Routes them to the target service in-cluster

**Benefits**:
- No port-forwarding needed
- Full DNS resolution (e.g., `ollama` resolves correctly)
- Environment parity (same network as production)

**Alternative**: `kubectl port-forward` (simpler but more limited)

---

### Vite
**Definition**: A fast, modern build tool for frontend development.

**Features**:
- Instant hot module replacement (HMR)
- Fast dev server startup
- Optimized production builds

**In this project**: Used for the restaurant app frontend.

---

### TypeScript
**Definition**: JavaScript with static type checking.

**Benefits**:
- Catch bugs at compile time
- Better IDE autocomplete
- Self-documenting code (types as documentation)

**In this project**: Used in both backend and frontend.

---

## LLM Concepts

### Inference
**Definition**: The process of running a model to generate predictions/responses.

**In this project**: When you call `/api/recommendations`, the backend performs inference by sending a prompt to Ollama.

**Time**: Varies from 1-60 seconds depending on model size and hardware.

---

### Prompt
**Definition**: The input text sent to the LLM.

**In this project**: We construct prompts from order data (e.g., "Tonight's orders: Table 5: Caesar Salad...").

**Types**:
- **User prompt**: The actual question/task
- **System prompt**: Instructions that define behavior (see below)

---

### System Prompt
**Definition**: A special prompt that defines the LLM's role, personality, and response format.

**Purpose**: Guides the model to respond in a specific way.

**Example** (from this project):
```
You are a restaurant operations assistant. Provide direct, actionable recommendations in kitchen language. No pleasantries.
```

**Key principle**: Be specific about format, tone, and constraints.

---

### Temperature
**Definition**: A parameter that controls randomness in LLM outputs.

**Range**: 0.0 to 2.0 (typically)

**Effects**:
- **0.0**: Deterministic, always picks the most likely token → Consistent, predictable
- **0.5**: Balanced → Mix of consistency and variety
- **1.0**: Standard sampling → Creative but reasonable
- **2.0**: Very random → Chaotic, unpredictable

**For restaurant ops**: We recommend 0.2-0.4 for consistent, reliable advice.

**Technical detail**: Temperature scales the logits before softmax (higher temp = flatter distribution).

---

### Top-p (Nucleus Sampling)
**Definition**: A parameter that limits token selection to the top probability mass.

**Range**: 0.0 to 1.0

**How it works**:
1. Sort tokens by probability
2. Pick the smallest set whose cumulative probability >= top_p
3. Sample from that set

**Effects**:
- **0.5**: Very focused (only top 50% probability mass considered)
- **0.9**: Balanced (top 90%) → Recommended default
- **1.0**: All tokens considered (no filtering)

**Why use it?**: Prevents the model from picking extremely unlikely tokens, even at high temperatures.

---

### Context Window (num_ctx)
**Definition**: The maximum number of tokens the model can process at once.

**Tokens**: Roughly 1 token ≈ 0.75 words (varies by language).

**Common sizes**:
- 2048 tokens ≈ 1500 words (small)
- 4096 tokens ≈ 3000 words (medium)
- 8192 tokens ≈ 6000 words (large)

**Trade-off**: Larger context = more memory usage and slower inference.

**For restaurant ops**: 2048 is sufficient (orders are short).

---

## Workflow Concepts

### Iteration
**Definition**: The process of repeatedly testing and refining prompts/parameters.

**In this project**:
1. Run the app locally (mirrord connects to cluster Ollama)
2. Adjust system prompt, temperature, top_p
3. Generate recommendations and evaluate
4. Repeat until satisfied

**Goal**: Find the "sweet spot" for your use case.

---

### Freezing
**Definition**: The act of locking in your final prompt + parameters into a Modelfile.

**Why**: Makes the behavior reproducible, versionable, and deployable.

**Process**:
1. Iterate until you're happy
2. Create a Modelfile with your final config
3. Build it: `ollama create my-model -f Modelfile`
4. Update your app to use `my-model` instead of the base model

---

### Versioning
**Definition**: Storing and tracking different versions of your model/config.

**Best practices**:
1. Commit Modelfiles to git
2. Tag releases: `git tag v1.0.0-restaurant-chef`
3. Store built models in a registry (e.g., Cloudsmith, S3, Docker Hub)

**Benefits**:
- Rollback to previous versions if needed
- A/B test different prompts
- Audit trail of changes

---

## API Concepts

### REST API
**Definition**: A standard way to expose functionality over HTTP.

**In this project**:
- Backend exposes `/api/recommendations` (POST)
- Ollama exposes `/api/generate` (POST)

**Benefits**: Language-agnostic, easy to test, well-documented.

---

### JSON
**Definition**: JavaScript Object Notation - a text format for structured data.

**In this project**: All API requests/responses use JSON.

**Example**:
```json
{
  "temperature": 0.2,
  "top_p": 0.9,
  "model": "llama3.2"
}
```

---

## Deployment Concepts

### GitOps
**Definition**: Managing infrastructure and config via Git commits.

**In this project**: Kubernetes manifests are versioned in Git. To deploy, we apply them with `kubectl apply -f`.

**Benefits**: Auditability, rollback, collaboration.

---

### CI/CD
**Definition**: Continuous Integration / Continuous Deployment - automated testing and deployment.

**Future work**: Add GitHub Actions to lint, test, and deploy on every push.

---

### Vendoring
**Definition**: Including third-party code directly in your repository.

**In this project**: Open WebUI is vendored via `git subtree`.

**Why**:
- ✅ Can iterate on vendored code locally
- ✅ No external dependency at runtime
- ✅ Clear snapshot of what version you're using

**Alternative**: Git submodules (links to external repos, doesn't copy code).

---

## Acronyms

- **API**: Application Programming Interface
- **CLI**: Command Line Interface
- **CPU**: Central Processing Unit
- **DNS**: Domain Name System
- **GPU**: Graphics Processing Unit (used for LLM acceleration)
- **HTTP**: Hypertext Transfer Protocol
- **IDE**: Integrated Development Environment
- **K8s**: Kubernetes (8 letters between K and s)
- **LLM**: Large Language Model
- **MCP**: Model Context Protocol (optional, not used here)
- **NLP**: Natural Language Processing
- **PVC**: Persistent Volume Claim (Kubernetes storage)
- **RAG**: Retrieval-Augmented Generation (using a knowledge base)
- **REST**: Representational State Transfer
- **UI**: User Interface
- **URL**: Uniform Resource Locator

---

## Further Reading

- [Ollama Documentation](https://ollama.ai/docs)
- [Modelfile Specification](https://github.com/ollama/ollama/blob/main/docs/modelfile.md)
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [Mirrord Documentation](https://mirrord.dev/docs)
- [LLM Inference Parameters Explained](https://www.promptingguide.ai/introduction/settings)
