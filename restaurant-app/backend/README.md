# Restaurant App Backend

Express + TypeScript backend that uses Ollama for restaurant operations insights.

## Features

- **POST /api/recommendations** - Generate operational recommendations from orders
- **GET /api/sample-orders** - Get hardcoded sample orders for testing
- **GET /api/models** - List available Ollama models
- **GET /health** - Health check endpoint

## Quick Start

### Install Dependencies
```bash
npm install
```

### Run Locally (with mirrord to connect to cluster Ollama)
```bash
mirrord exec --config ../../mirrord/config.json -- npm run dev
```

### Run Without Mirrord (port-forward required)
```bash
# In another terminal:
kubectl port-forward -n llm svc/ollama 11434:11434

# Then:
export OLLAMA_HOST=http://localhost:11434
npm run dev
```

## Environment Variables

- `PORT` - Server port (default: 3001)
- `OLLAMA_HOST` - Ollama API endpoint (default: http://ollama:11434)

## API Reference

### POST /api/recommendations

Generate recommendations based on orders.

**Request:**
```json
{
  "orders": [
    {
      "id": "ord-001",
      "table": 5,
      "items": ["Caesar Salad", "Grilled Salmon"],
      "specialRequests": "No croutons",
      "timestamp": "2024-01-15T18:30:00Z"
    }
  ],
  "temperature": 0.2,
  "top_p": 0.9,
  "model": "llama3.2"
}
```

**Response:**
```json
{
  "summary": "• 5 orders tonight...",
  "recommendations": "• Prep extra Caesar dressing...",
  "staff_notifications": "• Table 8 has steak allergy",
  "metadata": {
    "model": "llama3.2",
    "temperature": 0.2,
    "top_p": 0.9,
    "timestamp": "2024-01-15T18:35:00Z"
  }
}
```

### GET /api/sample-orders

Returns hardcoded sample orders for testing.

**Response:**
```json
{
  "orders": [...]
}
```

### GET /api/models

List available Ollama models.

**Response:**
```json
{
  "models": [
    { "name": "llama3.2", "size": 4700000000 },
    { "name": "mistral", "size": 4100000000 }
  ]
}
```

### GET /health

Health check.

**Response:**
```json
{
  "status": "ok",
  "ollama": {
    "connected": true,
    "host": "http://ollama:11434"
  },
  "timestamp": "2024-01-15T18:35:00Z"
}
```

## Development

### Build
```bash
npm run build
```

### Lint
```bash
npm run lint
```

### Format
```bash
npm run format
```

## System Prompt

The backend uses this system prompt:
```
You are a restaurant operations assistant. Your role is to analyze tonight's orders and provide actionable recommendations.

Response format (use this exact structure):
**SUMMARY:**
[2-3 bullet points about order volume, trends, popular items]

**RECOMMENDATIONS:**
[3-4 specific actions for kitchen prep, inventory, or service]

**STAFF NOTIFICATIONS:**
[1-2 urgent items to communicate to staff]

Keep responses concise. Use bullet points. No pleasantries. Kitchen language only.
```

**To iterate on the prompt:**
1. Edit the `SYSTEM_PROMPT` constant in `src/index.ts`
2. Save the file (tsx watch will auto-reload)
3. Test with the frontend or curl
4. Once satisfied, freeze into a Modelfile (see main README)

## Testing

Test the API with curl:
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
