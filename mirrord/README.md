# Mirrord Configuration

This directory contains the mirrord configuration for local development that connects to in-cluster services.

## What is Mirrord?

Mirrord lets you run your local process as if it were inside your Kubernetes cluster. Your code can:
- Access cluster-internal services (like `ollama.llm.svc.cluster.local`)
- Use cluster DNS resolution
- Connect to databases, caches, and other internal services

**Without changing a single line of code.**

## Configuration Explained

The `config.json` file configures mirrord to:

1. **Target the Ollama deployment** in the `llm` namespace
2. **Enable outgoing network traffic** so your local app can call `http://ollama:11434`
3. **Enable DNS** so `ollama` resolves to the cluster IP
4. **Keep filesystem local** so you can edit files and see changes immediately
5. **Import environment variables** starting with `OLLAMA_*`

## Installation

### macOS/Linux
```bash
curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash
```

### Verify Installation
```bash
mirrord --version
```

## Usage

### Basic Usage
```bash
mirrord exec --config ./mirrord/config.json -- <your-command>
```

### Examples

**Run Node.js backend:**
```bash
cd restaurant-app/backend
mirrord exec --config ../../mirrord/config.json -- npm run dev
```

**Run Python backend (Open WebUI):**
```bash
cd open-webui/backend
mirrord exec --config ../../mirrord/config.json -- python main.py
```

**Run with environment override:**
```bash
mirrord exec --config ./mirrord/config.json -e OLLAMA_HOST=ollama:11434 -- node server.js
```

## How It Works

```
┌─────────────────────────────────────┐
│  Your Local Machine                 │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Your App Process            │   │
│  │ (npm run dev)               │   │
│  └──────────┬──────────────────┘   │
│             │                       │
│             │ mirrord intercepts    │
│             │ network calls         │
│             ↓                       │
└─────────────────────────────────────┘
              │
              │ (tunneled)
              ↓
┌─────────────────────────────────────┐
│  Kubernetes Cluster                 │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Ollama Deployment           │   │
│  │ (DNS: ollama:11434)         │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

When you make an HTTP request to `http://ollama:11434`, mirrord:
1. Resolves `ollama` using cluster DNS → `10.96.x.x`
2. Routes the request through the cluster network
3. Returns the response to your local process

## Advanced Configuration

### Target a Specific Pod
```json
{
  "target": {
    "namespace": "llm",
    "path": {
      "pod": "ollama-abc123"
    }
  }
}
```

### Steal Traffic (Mirror Incoming Requests)
```json
{
  "feature": {
    "network": {
      "incoming": "steal",
      "outgoing": true
    }
  }
}
```

### File Operations from Cluster
```json
{
  "feature": {
    "fs": "read"
  }
}
```

See [mirrord documentation](https://mirrord.dev/docs) for more options.

## Troubleshooting

### "Failed to connect to cluster"
Ensure you have cluster access:
```bash
kubectl auth can-i get pods -n llm
```

### "Target pod not found"
Check the deployment exists:
```bash
kubectl get deployment -n llm ollama
```

### "DNS resolution failed"
Verify the service is running:
```bash
kubectl get svc -n llm ollama
```

### Local ports conflict
If mirrord reports port conflicts, ensure nothing else is using those ports:
```bash
lsof -i :11434
```

## Best Practices

1. **Use local filesystem** (`"fs": "local"`) for fast iteration
2. **Filter local traffic** to keep `localhost` calls local
3. **Target deployments** instead of specific pods (pods can restart)
4. **Include only necessary env vars** to avoid conflicts

## Without Mirrord (Alternative)

If you prefer not to use mirrord, you can port-forward instead:
```bash
kubectl port-forward -n llm svc/ollama 11434:11434
```

Then set the environment variable:
```bash
export OLLAMA_HOST=http://localhost:11434
npm run dev
```

**Downside**: You lose cluster DNS, service mesh features, and environment parity.

## Resources

- [Mirrord Documentation](https://mirrord.dev/docs)
- [Mirrord GitHub](https://github.com/metalbear-co/mirrord)
- [Mirrord Blog: Local K8s Development](https://mirrord.dev/blog)
