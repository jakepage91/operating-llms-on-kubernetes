# Complete Workflow Guide

This document describes the complete workflow for developing and deploying the LLM Gateway with Cloudsmith and mirrord.

## Overview

```
┌─────────────────────────────────────────────────────────┐
│ Your Workflow                                            │
│                                                          │
│  1. Build → 2. Push to Cloudsmith → 3. Deploy to K8s   │
│                                                          │
│  4. Use mirrord for fast iteration ⚡                   │
│     Edit config → Restart → Test (seconds!)            │
│                                                          │
│  5. When satisfied → Build v1.1 → Push → Deploy        │
└─────────────────────────────────────────────────────────┘
```

## Initial Setup (One Time)

### 1. Cloudsmith Setup

```bash
# Login to Cloudsmith Docker registry
docker login docker.cloudsmith.io
# Username: your-cloudsmith-username
# Password: your-cloudsmith-api-key (from https://cloudsmith.io/user/settings/api/)

# Optional: Set environment variables
export CLOUDSMITH_ORG="metalbear"  # or your org
export CLOUDSMITH_REPO="llm-ops"
```

### 2. Build and Push v1.0.0

```bash
# Build and push initial version
./scripts/build-and-push-gateway.sh v1.0.0
```

This creates:
- `docker.cloudsmith.io/metalbear/llm-ops/llm-gateway:v1.0.0`
- `docker.cloudsmith.io/metalbear/llm-ops/llm-gateway:latest`

### 3. Update Deployment to Use Cloudsmith

```bash
# Update deployment.yaml to reference Cloudsmith image
./scripts/update-gateway-image.sh v1.0.0
```

This modifies `llm-gateway/k8s/deployment.yaml`:
```yaml
image: docker.cloudsmith.io/metalbear/llm-ops/llm-gateway:v1.0.0
imagePullPolicy: Always
```

### 4. Deploy Prerequisites

```bash
# Deploy Ollama
./scripts/deploy-step1-ollama.sh

# Deploy Open WebUI
./scripts/deploy-step2-open-webui.sh
```

### 5. Deploy Gateway from Cloudsmith

```bash
# This will pull from Cloudsmith (no local build!)
./scripts/deploy-step3-gateway.sh
```

Output should show:
```
📦 Using image from Cloudsmith: docker.cloudsmith.io/metalbear/llm-ops/llm-gateway:v1.0.0
```

### 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n llm-gateway

# Check logs
kubectl logs -f deployment/llm-gateway -n llm-gateway

# Test health
kubectl run -i --rm --restart=Never curl --image=curlimages/curl -n llm-gateway -- \
  curl -s http://llm-gateway/healthz
```

## Daily Development Workflow (Fast Iteration)

This is where mirrord shines - **iterate in seconds, not minutes!**

### 1. Start Local Gateway with mirrord

```bash
./scripts/run-gateway-locally.sh
```

This:
- Connects to the in-cluster gateway deployment
- Mirrors traffic to your local Python process
- Allows cluster DNS resolution
- Lets you edit code/config locally

You'll see output like:
```
✅ Prerequisites met

Starting local gateway with mirrord...
Traffic from Open WebUI will now be mirrored to your local process

To test policy changes:
  1. Edit llm-gateway/config.yaml
  2. Press Ctrl+C to stop the process
  3. Run this script again to restart with new config

Press Ctrl+C to stop
```

### 2. Test with Open WebUI

```bash
# In another terminal
kubectl port-forward svc/open-webui 3000:8080 -n llm
```

Open http://localhost:3000 and send prompts.

**You'll see logs in your local terminal!** 🎉

### 3. Edit Policies

```bash
# Edit the config
vim llm-gateway/config.yaml

# Change enforcement mode
enforcement_mode: hard  # was: monitor

# Add new patterns
input_validation:
  prompt_injection_patterns:
    - "your new pattern here"
```

### 4. Restart and Test (Seconds!)

```bash
# In the terminal running the gateway:
# Press Ctrl+C

# Restart (up-arrow, Enter)
./scripts/run-gateway-locally.sh

# Or one-liner
# Ctrl+C, then: ↑ Enter
```

**Iteration time: ~5 seconds** (vs 10-15 minutes for container rebuild!)

### 5. Repeat

Keep iterating:
- Edit `config.yaml`
- Ctrl+C
- ↑ Enter
- Test
- Repeat

## Publishing Changes (When Satisfied)

Once you've tested your changes and want to deploy them to the cluster:

### 1. Build New Version

```bash
./scripts/build-and-push-gateway.sh v1.1.0
```

### 2. Update Deployment

```bash
./scripts/update-gateway-image.sh v1.1.0
```

### 3. Roll Out New Version

```bash
# Apply the updated deployment
kubectl apply -f llm-gateway/k8s/deployment.yaml

# Or force a rollout
kubectl rollout restart deployment/llm-gateway -n llm-gateway

# Watch the rollout
kubectl rollout status deployment/llm-gateway -n llm-gateway
```

### 4. Verify New Version

```bash
kubectl get pods -n llm-gateway -o jsonpath='{.items[*].spec.containers[*].image}'
# Should show: docker.cloudsmith.io/metalbear/llm-ops/llm-gateway:v1.1.0
```

## Common Workflows

### Workflow A: Quick Policy Testing

**Goal:** Test if a new input validation pattern works

```bash
# 1. Run locally with mirrord
./scripts/run-gateway-locally.sh

# 2. Edit config.yaml (add pattern)
# 3. Restart (Ctrl+C, ↑ Enter)
# 4. Test in Open WebUI
# 5. Repeat steps 2-4 until satisfied
```

**Time per iteration:** ~5 seconds

### Workflow B: Add New Policy Feature

**Goal:** Implement a new policy check in code

```bash
# 1. Edit app/policy.py locally
vim llm-gateway/app/policy.py

# 2. Run locally with mirrord (code changes reflected immediately if using --reload)
./scripts/run-gateway-locally.sh

# 3. Test
# 4. When satisfied, build and push
./scripts/build-and-push-gateway.sh v1.2.0
./scripts/update-gateway-image.sh v1.2.0
kubectl rollout restart deployment/llm-gateway -n llm-gateway
```

### Workflow C: Test Against Different Enforcement Modes

**Goal:** See how the same prompt behaves in monitor vs hard mode

```bash
# Run locally with mirrord
./scripts/run-gateway-locally.sh

# Terminal 1: Edit config
# Set enforcement_mode: monitor
# Ctrl+C, restart
# Test prompt in Open WebUI
# Note: Request goes through, warning logged

# Set enforcement_mode: hard
# Ctrl+C, restart
# Test same prompt
# Note: Request blocked
```

### Workflow D: Debugging Production Issues

**Goal:** Investigate why a certain prompt is being blocked

```bash
# 1. Run locally with mirrord
./scripts/run-gateway-locally.sh

# 2. Reproduce the issue via Open WebUI
# 3. See detailed logs in your local terminal
# 4. Edit policy.py to add debug logging
# 5. Restart and test again
# 6. Fix the issue
```

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                        │
│                                                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │ Open WebUI  │───▶│ Gateway v1.0│───▶│   Ollama    │ │
│  │ namespace:  │    │ namespace:  │    │ namespace:  │ │
│  │    llm      │    │ llm-gateway │    │    llm      │ │
│  └─────────────┘    └──────┬──────┘    └─────────────┘ │
│                             │                            │
│                             │ Traffic mirrored           │
└─────────────────────────────┼────────────────────────────┘
                              │
                              ▼
                      ┌───────────────┐
                      │ Your Laptop   │
                      │               │
                      │ mirrord       │
                      │ ├─ Gateway.py │
                      │ ├─ config.yaml│
                      │ └─ Fast edit! │
                      └───────────────┘
```

## Comparison: With vs Without Cloudsmith/mirrord

### Without This Setup

```
Edit code
  ↓
Build image (2-3 min)
  ↓
Push to registry (1-2 min)
  ↓
Update K8s manifest
  ↓
Deploy to cluster (3-5 min)
  ↓
Wait for rollout (2-3 min)
  ↓
Test
  ↓
Find issue, go back to step 1

Total: 10-15 minutes per iteration ❌
```

### With This Setup

```
Edit config.yaml
  ↓
Restart local process (5 sec)
  ↓
Test immediately
  ↓
Find issue, go back to step 1

Total: 5-10 seconds per iteration ✅

When satisfied:
  Build → Push → Deploy (one-time)
```

## Best Practices

### Version Naming

Use semantic versioning:
- `v1.0.0` - Initial release
- `v1.1.0` - Add new policy feature
- `v1.1.1` - Fix bug in existing feature
- `v2.0.0` - Breaking change (e.g., API change)

### Testing Before Publishing

1. Test extensively with mirrord locally
2. Verify all test scenarios from TESTING.md
3. Check metrics and logs
4. Only then build and push new version

### Config Management

- `llm-gateway/config.yaml` - For local testing with mirrord
- `llm-gateway/k8s/configmap.yaml` - For cluster deployment
- Keep them in sync when deploying

### Rollback Strategy

If a new version has issues:

```bash
# Roll back to previous version
./scripts/update-gateway-image.sh v1.0.0
kubectl rollout restart deployment/llm-gateway -n llm-gateway

# Or use kubectl rollout undo
kubectl rollout undo deployment/llm-gateway -n llm-gateway
```

## Troubleshooting

### mirrord Can't Connect

**Issue:** `Failed to connect to cluster`

**Solution:**
```bash
# Verify deployment exists
kubectl get deployment llm-gateway -n llm-gateway

# Check your kubeconfig
kubectl config current-context

# Verify mirrord config
cat mirrord/config.json
```

### Image Pull Failed

**Issue:** `ErrImagePull` from Cloudsmith

**Solution:**
```bash
# Create image pull secret
kubectl create secret docker-registry cloudsmith-pull-secret \
  --docker-server=docker.cloudsmith.io \
  --docker-username=<your-username> \
  --docker-password=<your-api-key> \
  -n llm-gateway

# Update deployment to use secret (already done in deployment.yaml if you followed setup)
```

### Local Process Can't Reach Ollama

**Issue:** DNS resolution fails

**Solution:**
Check mirrord DNS settings in `mirrord/config.json`:
```json
{
  "feature": {
    "network": {
      "dns": true  // Must be true!
    }
  }
}
```

## Summary

**This workflow gives you:**

✅ **Versioned deployments** - v1.0.0, v1.1.0, etc. in Cloudsmith
✅ **Fast iteration** - 5-second policy testing with mirrord
✅ **Production stability** - Cluster runs stable version
✅ **Easy rollback** - Revert to previous version anytime
✅ **Shareable** - Anyone can pull from Cloudsmith
✅ **Blog-ready** - Perfect for demonstrations

**The key insight:**
- Cluster = Stable baseline (from Cloudsmith)
- Local = Fast experimentation (with mirrord)
- When ready = Promote to new version

This is the best of both worlds! 🎉
