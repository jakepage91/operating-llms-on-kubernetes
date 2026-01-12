# Kubernetes Manifests for Ollama Runtime

This directory contains the Kubernetes resources needed to deploy Ollama in your cluster.

## Resources

- **namespace.yaml** - Creates the `llm` namespace for isolation
- **ollama-deployment.yaml** - Deploys the Ollama runtime server
- **ollama-service.yaml** - Exposes Ollama via Service DNS (`ollama.llm.svc.cluster.local:11434`)
- **example-modelfile.yaml** - ConfigMap with sample Modelfiles for reference

## Deployment

### Quick Deploy
```bash
kubectl apply -f namespace.yaml
kubectl apply -f ollama-deployment.yaml
kubectl apply -f ollama-service.yaml
kubectl apply -f example-modelfile.yaml
```

Or use the script:
```bash
cd ..
./scripts/deploy-ollama.sh
```

### Verify Deployment
```bash
# Check pod status
kubectl get pods -n llm

# View logs
kubectl logs -n llm -l app=ollama -f

# Check service
kubectl get svc -n llm
```

## Pull a Model

Once the pod is running, pull a model:
```bash
kubectl exec -n llm deployment/ollama -- ollama pull llama3.2
```

Available models: `llama3.2`, `mistral`, `codellama`, `phi3`, etc. See [Ollama library](https://ollama.ai/library).

## Test the API

Port-forward to test locally:
```bash
kubectl port-forward -n llm svc/ollama 11434:11434
```

Then test:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

## GPU Support

If you have GPU nodes, uncomment the GPU resource limit in `ollama-deployment.yaml`:
```yaml
resources:
  limits:
    nvidia.com/gpu: "1"
```

Ensure you have the [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin) installed.

## Persistent Storage

The default deployment uses `emptyDir` (ephemeral). For persistent model storage, create a PVC and update the volume mount:

```yaml
volumes:
- name: ollama-data
  persistentVolumeClaim:
    claimName: ollama-pvc
```

## Creating Custom Models

1. **Copy a Modelfile into the pod:**
   ```bash
   kubectl cp example-modelfile.yaml llm/ollama-<pod-id>:/tmp/restaurant-chef.modelfile
   ```

2. **Create the model:**
   ```bash
   kubectl exec -n llm deployment/ollama -- ollama create restaurant-chef -f /tmp/restaurant-chef.modelfile
   ```

3. **List models:**
   ```bash
   kubectl exec -n llm deployment/ollama -- ollama list
   ```

## Resource Tuning

Adjust CPU/memory based on your cluster capacity:
- **Small cluster**: 1 CPU, 2Gi memory
- **Medium cluster**: 2 CPUs, 4Gi memory
- **Large cluster**: 4+ CPUs, 8Gi+ memory

## Troubleshooting

### Pod stuck in Pending
Check node resources:
```bash
kubectl describe node | grep -A 5 "Allocated resources"
```

### Out of memory errors
Increase memory limits in `ollama-deployment.yaml`.

### Model pulls fail
Check internet connectivity from the pod:
```bash
kubectl exec -n llm deployment/ollama -- curl -I https://ollama.ai
```
