# Restaurant LLM Operations Platform

A cohesive development environment combining **Ollama runtime on Kubernetes**, **Open WebUI**, and a custom **restaurant operations app** demonstrating practical LLM integration patterns.

## Overview

This repository provides a complete stack for running and iterating on LLM-powered applications with a focus on:
- **Runtime-first architecture**: Deploy Ollama in Kubernetes as the inference engine
- **Local development velocity**: Use mirrord to develop locally while connecting to in-cluster services
- **Production path**: Clear workflow from experimentation to frozen, versioned models

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Kubernetes Cluster (namespace: llm)                │
│  ┌──────────────┐                                   │
│  │   Ollama     │  ← Service: ollama:11434          │
│  │   Runtime    │     (GPU-enabled deployment)      │
│  └──────────────┘                                   │
└─────────────────────────────────────────────────────┘
         ↑                    ↑                    ↑
         │                    │                    │
    (mirrord)            (mirrord)            (mirrord)
         │                    │                    │
┌────────┴────────┐  ┌────────┴────────┐  ┌────────┴────────┐
│  Open WebUI     │  │  Restaurant App  │  │  Your Next App  │
│  (local dev)    │  │  Backend+Frontend│  │  (local dev)    │
└─────────────────┘  └──────────────────┘  └─────────────────┘
```

## Repository Structure

```
restaurant-llm-ops/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── .gitignore
│
├── kubernetes/                  # K8s manifests for Ollama runtime
│   ├── namespace.yaml          # llm namespace
│   ├── ollama-deployment.yaml  # Ollama server deployment
│   ├── ollama-service.yaml     # Service exposing port 11434
│   ├── example-modelfile.yaml  # ConfigMap with sample Modelfile
│   └── README.md               # K8s deployment guide
│
├── mirrord/                     # Local dev configuration
│   ├── config.json             # Mirrord settings for local→cluster
│   └── README.md               # How to use mirrord
│
├── open-webui/                  # Vendored Open WebUI (git subtree)
│   ├── backend/                # Python FastAPI backend
│   ├── src/                    # Svelte frontend
│   ├── package.json            # Frontend dependencies
│   ├── requirements.txt        # Python dependencies
│   └── ... (full source)
│
├── restaurant-app/              # Custom demo application
│   ├── README.md               # App-specific documentation
│   ├── backend/                # Node/Express API server
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts        # Main server (Express)
│   │       ├── ollama-client.ts # Ollama API wrapper
│   │       └── types.ts        # TypeScript definitions
│   └── frontend/               # Vite + React UI
│       ├── package.json
│       ├── vite.config.ts
│       ├── index.html
│       └── src/
│           ├── main.tsx        # Entry point
│           ├── App.tsx         # Main component
│           └── types.ts        # Shared types
│
├── scripts/                     # Automation scripts
│   ├── deploy-ollama.sh        # Deploy all K8s resources
│   ├── test-restaurant-api.sh  # Smoke test the restaurant backend
│   └── setup-local-dev.sh      # Install all dependencies
│
└── docs/                        # Additional documentation
    ├── glossary.md             # Key terms explained
    └── workflow.md             # Development workflow guide
```

---

## Glossary

| Term | Definition |
|------|------------|
| **Ollama** | An LLM runtime that runs models locally or in containers. Think "Docker for LLMs". |
| **Runtime** | The inference engine (Ollama) that loads models and generates responses. |
| **Model** | The weights/parameters (e.g., llama3.2, mistral) that define the AI's behavior. |
| **Modelfile** | A declarative config file (like a Dockerfile) specifying the base model, system prompt, parameters, and adapters. |
| **Open WebUI** | A web interface for interacting with Ollama, similar to ChatGPT's UI. |
| **Mirrord** | A tool that runs local processes as if they were inside a Kubernetes cluster (network tunneling). |
| **System Prompt** | Instructions that define the AI's personality, role, and response style. |
| **Temperature** | Randomness control (0.0 = deterministic, 1.0 = creative). |
| **Top-p** | Nucleus sampling threshold (0.9 = consider top 90% of probability mass). |

---

## Runtime vs Model: A Key Distinction

**The runtime (Ollama) and the model (e.g., llama3.2) are separate concepts:**

- **Runtime**: The service that loads models, handles API requests, and generates text. It runs continuously.
- **Model**: The specific AI weights you pull and run (e.g., `ollama pull llama3.2`).

**Analogy**: Ollama is like a **web server** (runtime), and models are like **websites** (content) it serves.

**Why this matters:**
1. One Ollama instance can serve multiple models.
2. You iterate on prompts/parameters locally, then "freeze" the final config into a Modelfile.
3. The Modelfile + model weights can be version-controlled and deployed consistently.

---

## Development Workflow

### Phase 1: Deploy the Runtime

1. **Deploy Ollama to Kubernetes:**
   ```bash
   cd kubernetes
   ./scripts/deploy-ollama.sh
   ```

2. **Verify it's running:**
   ```bash
   kubectl get pods -n llm
   kubectl logs -n llm -l app=ollama
   ```

3. **Pull a model into the runtime:**
   ```bash
   kubectl exec -n llm deployment/ollama -- ollama pull llama3.2
   ```

### Phase 2: Experiment Locally

1. **Install mirrord:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash
   ```

2. **Run Open WebUI locally (connected to cluster Ollama):**
   ```bash
   cd open-webui

   # Backend
   cd backend
   pip install -r requirements.txt
   mirrord exec --config ../mirrord/config.json -- python main.py

   # Frontend (in another terminal)
   cd ../
   npm install
   npm run dev
   ```

3. **Run the restaurant app locally:**
   ```bash
   # Backend
   cd restaurant-app/backend
   npm install
   mirrord exec --config ../../mirrord/config.json -- npm run dev

   # Frontend (in another terminal)
   cd restaurant-app/frontend
   npm install
   npm run dev
   ```

4. **Test the restaurant API:**
   ```bash
   ./scripts/test-restaurant-api.sh
   ```

5. **Iterate on prompts and parameters:**
   - Adjust temperature/top-p in the UI knobs
   - Modify the system prompt in `restaurant-app/backend/src/index.ts`
   - See changes immediately without redeploying

### Phase 3: Freeze the Behavior

Once you're happy with the results:

1. **Create a Modelfile** (e.g., `kubernetes/restaurant-chef-modelfile.yaml`):
   ```dockerfile
   FROM llama3.2

   SYSTEM You are a concise restaurant operations assistant. Provide direct, actionable recommendations in kitchen language. No pleasantries. Focus on efficiency.

   PARAMETER temperature 0.2
   PARAMETER top_p 0.9
   PARAMETER num_ctx 2048
   ```

2. **Build the custom model in-cluster:**
   ```bash
   kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /path/to/modelfile
   ```

3. **Update your app to use the frozen model:**
   ```typescript
   // Change from:
   model: "llama3.2"
   // To:
   model: "restaurant-chef"
   ```

### Phase 4: Store and Version

1. **Export the model:**
   ```bash
   kubectl exec -n llm deployment/ollama -- ollama save restaurant-chef > restaurant-chef.tar
   ```

2. **Push to a registry** (e.g., Cloudsmith, Docker Hub, S3):
   ```bash
   # Example: Push to Cloudsmith
   cloudsmith push ollama your-org/your-repo restaurant-chef.tar
   ```

3. **Version in Git:**
   - Commit the Modelfile to `kubernetes/modelfiles/restaurant-chef-v1.0.modelfile`
   - Tag the release: `git tag v1.0.0-restaurant-chef`

---

## Quick Start (TL;DR)

```bash
# 1. Deploy Ollama runtime
./scripts/deploy-ollama.sh

# 2. Pull a model
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2

# 3. Install dependencies
./scripts/setup-local-dev.sh

# 4. Run restaurant app (backend)
cd restaurant-app/backend
mirrord exec --config ../../mirrord/config.json -- npm run dev

# 5. Run restaurant app (frontend) - in another terminal
cd restaurant-app/frontend
npm run dev

# 6. Test it
./scripts/test-restaurant-api.sh

# 7. Open browser: http://localhost:5173
```

---

## Vendoring Strategy

### Open WebUI: Git Subtree
We use `git subtree` to vendor Open WebUI because:
- ✅ Full source code is present (can iterate locally)
- ✅ Preserves upstream commit history
- ✅ Easy to pull upstream updates: `git subtree pull --prefix open-webui https://github.com/open-webui/open-webui.git main --squash`
- ✅ License (MIT) is preserved in the vendored directory

### Kubernetes Manifests: Manual Copy
We cherry-pick only what we need from `huggingface-kubernetes`:
- ✅ Avoids unnecessary files (Python scripts, extra deployments)
- ✅ Simplified for the restaurant use case
- ✅ Easier to maintain and understand

---

## Prerequisites

- **kubectl** - Kubernetes CLI
- **docker** - Container runtime (optional, for testing)
- **node** (v18+) and **npm** - JavaScript runtime
- **python** (v3.11+) and **pip** - For Open WebUI backend
- **mirrord** - Local-to-cluster tunneling

### Installing Mirrord
```bash
curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash
```

---

## Troubleshooting

### Ollama pod won't start
- Check GPU availability: `kubectl describe node | grep nvidia.com/gpu`
- View logs: `kubectl logs -n llm -l app=ollama`

### Mirrord connection fails
- Ensure you have cluster access: `kubectl auth can-i get pods -n llm`
- Check the config: `cat mirrord/config.json`

### Restaurant API returns errors
- Verify Ollama is accessible: `kubectl port-forward -n llm svc/ollama 11434:11434`
- Test directly: `curl http://localhost:11434/api/generate -d '{"model":"llama3.2","prompt":"Hi"}'`

---

## License

- **Repository code**: MIT License (see LICENSE)
- **Open WebUI**: MIT License (see open-webui/LICENSE)
- **Ollama**: MIT License

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make changes and test locally
4. Submit a pull request

---

## Acknowledgments

- [Ollama](https://ollama.ai/) - The LLM runtime
- [Open WebUI](https://github.com/open-webui/open-webui) - Web interface for Ollama
- [Mirrord](https://mirrord.dev/) - Local Kubernetes development tool
- [ndouglas-cloudsmith/huggingface-kubernetes](https://github.com/ndouglas-cloudsmith/huggingface-kubernetes) - Original K8s manifests inspiration

---

**Ready to get started?** Jump to [Quick Start](#quick-start-tldr) or read the [detailed workflow guide](docs/workflow.md).
