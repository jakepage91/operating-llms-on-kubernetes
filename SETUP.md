# Repository Setup Instructions

This document provides the exact commands needed to create this repository from scratch, including vendoring upstream dependencies.

## Prerequisites

- Git installed
- GitHub account (or other Git hosting)
- kubectl with cluster access
- Node.js 18+
- Python 3.11+ (for Open WebUI)

## Step-by-Step Setup

### 1. Initialize the Repository

```bash
# Create directory
mkdir restaurant-llm-ops
cd restaurant-llm-ops

# Initialize git
git init
git branch -M main

# Add remote (replace with your repo URL)
git remote add origin https://github.com/your-org/restaurant-llm-ops.git
```

### 2. Vendor Open WebUI Using Git Subtree

We use `git subtree` to vendor Open WebUI because it:
- Includes the full source code (not just a link)
- Preserves upstream history
- Allows easy updates with `git subtree pull`
- Keeps licenses intact

```bash
# Add Open WebUI as a subtree
git subtree add --prefix open-webui https://github.com/open-webui/open-webui.git main --squash

# This creates an open-webui/ directory with all source code
```

**To update Open WebUI later**:
```bash
git subtree pull --prefix open-webui https://github.com/open-webui/open-webui.git main --squash
```

### 3. Copy Kubernetes Manifests from Huggingface-Kubernetes

We manually copy (not vendor) the manifests because we only need a subset.

**Option A: Manual copy** (recommended for customization):
1. Visit https://github.com/ndouglas-cloudsmith/huggingface-kubernetes
2. Copy `deployment.yaml` as reference
3. Create our simplified versions in `kubernetes/`

**Option B: Git subtree** (if you want the full repo):
```bash
git subtree add --prefix upstream/huggingface-kubernetes https://github.com/ndouglas-cloudsmith/huggingface-kubernetes.git main --squash
```

Then cherry-pick what you need:
```bash
cp upstream/huggingface-kubernetes/deployment.yaml kubernetes/ollama-deployment.yaml
# Edit to simplify and adapt to Ollama
```

**For this project, we chose Option A** (manual) for simplicity.

### 4. Create the Directory Structure

```bash
mkdir -p kubernetes
mkdir -p mirrord
mkdir -p restaurant-app/backend/src
mkdir -p restaurant-app/frontend/src/components
mkdir -p scripts
mkdir -p docs
```

### 5. Add All Files

Follow the file creation in the main README or copy from this repository.

Key files to create:
- `.gitignore`
- `README.md`
- `LICENSE`
- `kubernetes/*.yaml`
- `mirrord/config.json`
- `restaurant-app/backend/*`
- `restaurant-app/frontend/*`
- `scripts/*.sh`
- `docs/*.md`

### 6. Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### 7. Initial Commit

```bash
git add .
git commit -m "Initial commit: Restaurant LLM Operations Platform

- Vendor Open WebUI via git subtree
- Add Kubernetes manifests for Ollama
- Add restaurant operations demo app (backend + frontend)
- Add mirrord config for local dev
- Add deployment scripts and documentation"

git push -u origin main
```

### 8. Tag the Release

```bash
git tag v1.0.0
git push --tags
```

## Vendoring Strategy: Why Git Subtree?

### Compared to Git Submodules

| Feature | Git Subtree | Git Submodules |
|---------|-------------|----------------|
| Code included in repo | ✅ Yes | ❌ No (just a pointer) |
| Easy for contributors | ✅ Yes | ❌ No (must init submodules) |
| Can modify vendored code | ✅ Yes | ⚠️ Possible but complex |
| Update complexity | ⚠️ Moderate | ✅ Simple |
| History preserved | ✅ Yes (optional) | ✅ Yes |

**Verdict**: Git subtree is better for vendoring code you might want to modify.

### Compared to Manual Copying

| Feature | Git Subtree | Manual Copy |
|---------|-------------|-------------|
| Update upstream changes | ✅ Easy (`git subtree pull`) | ❌ Manual diff |
| Preserve upstream history | ✅ Yes | ❌ No |
| License tracking | ✅ Automatic | ⚠️ Manual |
| Simplicity | ⚠️ Moderate | ✅ Very simple |

**Verdict**: Git subtree is better for large dependencies (like Open WebUI). Manual copying is fine for small files (like Kubernetes manifests).

## Updating Vendored Dependencies

### Update Open WebUI

```bash
# Pull latest changes from upstream
git subtree pull --prefix open-webui https://github.com/open-webui/open-webui.git main --squash

# Resolve any conflicts
# Commit the update
git commit -m "Update Open WebUI to latest main branch"
```

### Update Kubernetes Manifests

Since these are manually copied, you'll need to:
1. Check the upstream repo for changes
2. Manually apply relevant updates
3. Commit the changes

## Working with the Vendored Code

### Modifying Open WebUI

You can edit files in `open-webui/` directly:
```bash
vim open-webui/backend/main.py
git add open-webui/backend/main.py
git commit -m "Customize Open WebUI backend for restaurant use case"
```

### Splitting Changes (Advanced)

If you want to contribute changes back to Open WebUI:
```bash
# Push your changes to a branch in the upstream repo
git subtree push --prefix open-webui https://github.com/your-fork/open-webui.git feature-branch

# Then create a PR from your fork to the upstream repo
```

## Deployment Checklist

- [ ] Repository created and initialized
- [ ] Open WebUI vendored via git subtree
- [ ] Kubernetes manifests created
- [ ] Restaurant app code added (backend + frontend)
- [ ] Scripts created and made executable
- [ ] Documentation written (README, glossary, workflow)
- [ ] License file created
- [ ] Initial commit pushed
- [ ] Tagged v1.0.0

## Next Steps

1. Follow the [README.md](./README.md) for deployment instructions
2. Deploy Ollama to your cluster
3. Run the local dev environment
4. Start iterating on your use case!

## Troubleshooting Setup

### "fatal: refusing to merge unrelated histories"
This happens if you try to add a subtree to a repo that already has commits.

**Fix**:
```bash
git subtree add --prefix open-webui https://github.com/open-webui/open-webui.git main --squash --allow-unrelated-histories
```

### "scripts/*.sh: Permission denied"
Make scripts executable:
```bash
chmod +x scripts/*.sh
```

### "npm install fails in open-webui"
Open WebUI has its own dependencies. Install them:
```bash
cd open-webui
npm install
cd ..
```

You don't need to do this for the main repo to work (only if you want to run Open WebUI locally).

## Alternative: Using This Repo as a Template

Instead of creating from scratch, you can:
1. Fork or clone this repository
2. Update the remote: `git remote set-url origin https://github.com/your-org/your-repo.git`
3. Customize the code for your use case
4. Push to your remote

This is faster but you won't learn the vendoring process.
