# Building and Distributing via Cloudsmith

This guide shows how to build the LLM Gateway image and distribute it via Cloudsmith for production deployments.

## Why Cloudsmith?

Cloudsmith provides universal package management for container images, models, and artifacts. Benefits:

- **Private registries** - Keep your gateway images secure
- **Multi-format support** - Store container images alongside model files
- **Global CDN** - Fast distribution worldwide
- **Access control** - Fine-grained permissions for teams
- **Versioning** - Track all releases

## Prerequisites

1. **Cloudsmith account** - Sign up at https://cloudsmith.io/
2. **Docker installed** - For building images
3. **Cloudsmith CLI** (optional) - For pushing non-Docker artifacts

## Step 1: Create a Cloudsmith Repository

1. Log in to https://cloudsmith.io/
2. Create a new repository:
   - Click "Create Repository"
   - Name: `llm-ops` (or your preferred name)
   - Type: **Docker**
   - Visibility: **Private** (or Public for open source)
3. Note your repository details:
   - Organization: `your-org`
   - Repository: `llm-ops`
   - Registry URL: `docker.cloudsmith.io/your-org/llm-ops`

## Step 2: Authenticate with Cloudsmith

Generate an API key:

1. Go to User Settings → API Keys
2. Click "Create API Key"
3. Name: `llm-gateway-push`
4. Copy the key

Log in to the Cloudsmith Docker registry:

```bash
docker login docker.cloudsmith.io
```

When prompted:
- Username: Your Cloudsmith username
- Password: The API key you just created

## Step 3: Build the Gateway Image

Build the image with a version tag:

```bash
cd llm-gateway

# Build with version tag
docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.0 .

# Also tag as latest
docker tag docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.0 \
  docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest

cd ..
```

Replace `your-org` with your actual Cloudsmith organization name.

Verify the images were built:

```bash
docker images | grep llm-gateway
```

## Step 4: Push to Cloudsmith

Push both tags:

```bash
docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.0
docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest
```

Verify in Cloudsmith:
1. Go to your repository in the web UI
2. You should see the `llm-gateway` package with both tags

## Step 5: Deploy from Cloudsmith

Update your deployment to pull from Cloudsmith.

**Option A: Update the existing deployment manifest**

Edit `llm-gateway/k8s/deployment.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: llm-gateway
        image: docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.0
        imagePullPolicy: Always
```

**Option B: Deploy directly with kubectl**

```bash
kubectl set image deployment/llm-gateway \
  llm-gateway=docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.0 \
  -n llm-gateway
```

## Step 6: Configure Image Pull Secrets

If your repository is private, create an image pull secret:

```bash
kubectl create secret docker-registry cloudsmith-pull-secret \
  --docker-server=docker.cloudsmith.io \
  --docker-username=your-username \
  --docker-password=your-api-key \
  --docker-email=your-email \
  -n llm-gateway
```

Update the deployment to use the secret:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: cloudsmith-pull-secret
      containers:
      - name: llm-gateway
        image: docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.0
```

Apply the updated deployment:

```bash
kubectl apply -f llm-gateway/k8s/deployment.yaml
```

## Step 7: Verify Deployment

Check that the pod pulled the image successfully:

```bash
kubectl get pods -n llm-gateway
kubectl describe pod <pod-name> -n llm-gateway
```

Look for `Successfully pulled image` in the events.

## Versioning Strategy

**Semantic versioning:**

```bash
# Bug fix
docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.0.1 .

# New feature
docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.1.0 .

# Breaking change
docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v2.0.0 .
```

**Git-based versioning:**

```bash
# Use git commit SHA
GIT_SHA=$(git rev-parse --short HEAD)
docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:${GIT_SHA} .
docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:${GIT_SHA}
```

**Always tag stable releases as latest:**

```bash
docker tag docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.2.0 \
  docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest
docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest
```

## Complete Build and Push Workflow

Here's the complete workflow for releasing a new version:

```bash
# 1. Make your changes to the code
cd llm-gateway
# ... edit files ...

# 2. Test locally first (see minikube docs)

# 3. Commit your changes
git add .
git commit -m "Add new policy feature"

# 4. Tag the release
git tag v1.2.0
git push origin v1.2.0

# 5. Build the image
docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.2.0 .

# 6. Tag as latest
docker tag docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.2.0 \
  docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest

# 7. Push both tags
docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.2.0
docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest

# 8. Update deployment
kubectl set image deployment/llm-gateway \
  llm-gateway=docker.cloudsmith.io/your-org/llm-ops/llm-gateway:v1.2.0 \
  -n llm-gateway

# 9. Verify rollout
kubectl rollout status deployment/llm-gateway -n llm-gateway
```

## Storing Models in Cloudsmith

You can also store Ollama model files in Cloudsmith for versioned model distribution.

**Export a model:**

```bash
kubectl exec -n llm deployment/ollama -- ollama save llama3.2:1b > llama3.2-1b.tar
```

**Push to Cloudsmith (using Cloudsmith CLI):**

```bash
# Install Cloudsmith CLI
pip install cloudsmith-cli

# Upload the model
cloudsmith push raw your-org/llm-ops llama3.2-1b.tar \
  --name "llama3.2-1b" \
  --version "2024.01" \
  --description "LLaMA 3.2 1B model"
```

**Download and load in another cluster:**

```bash
# Download from Cloudsmith
cloudsmith dl raw your-org/llm-ops llama3.2-1b.tar

# Load into Ollama
kubectl cp llama3.2-1b.tar llm/ollama-pod:/tmp/
kubectl exec -n llm deployment/ollama -- ollama load /tmp/llama3.2-1b.tar
```

## CI/CD Integration

**Example GitHub Actions workflow:**

```yaml
name: Build and Push Gateway

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Log in to Cloudsmith
        run: |
          echo "${{ secrets.CLOUDSMITH_API_KEY }}" | docker login docker.cloudsmith.io -u ${{ secrets.CLOUDSMITH_USERNAME }} --password-stdin

      - name: Build and push
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          docker build -t docker.cloudsmith.io/your-org/llm-ops/llm-gateway:${VERSION} llm-gateway/
          docker tag docker.cloudsmith.io/your-org/llm-ops/llm-gateway:${VERSION} docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest
          docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:${VERSION}
          docker push docker.cloudsmith.io/your-org/llm-ops/llm-gateway:latest
```

Add secrets to your GitHub repository:
- `CLOUDSMITH_USERNAME`
- `CLOUDSMITH_API_KEY`

## Troubleshooting

### Authentication failed

Verify your credentials:

```bash
docker logout docker.cloudsmith.io
docker login docker.cloudsmith.io
```

### Image pull failed in cluster

Check the secret exists:

```bash
kubectl get secret cloudsmith-pull-secret -n llm-gateway
```

Verify the secret is referenced in the deployment:

```bash
kubectl get deployment llm-gateway -n llm-gateway -o yaml | grep imagePullSecrets
```

### Push takes too long

Cloudsmith uses a global CDN but initial pushes can be slow. Use:

```bash
docker push --all-tags docker.cloudsmith.io/your-org/llm-ops/llm-gateway
```

## Cost Considerations

Cloudsmith pricing is based on:
- **Storage** - How much data you store
- **Bandwidth** - How much data is downloaded

For this project:
- Gateway image: ~300MB per version
- Model files: 1-10GB per model
- Estimated cost for small team: Free tier or ~$50/month

See https://cloudsmith.io/pricing/ for current pricing.

## Next Steps

- Set up automated builds with GitHub Actions
- Create separate repositories for dev/staging/prod
- Store custom Ollama models alongside images
- Implement image scanning and vulnerability checks
- Use Cloudsmith's retention policies to clean up old versions
