# LLM Gateway

A production-ready security gateway for Large Language Model requests that sits between clients (like Open WebUI) and backend LLM services (like Ollama). Implements OWASP LLM Top 10 security controls with configurable policy enforcement.

## Features

- **OpenAI-Compatible API**: `/v1/chat/completions` endpoint compatible with OpenAI API format
- **OWASP LLM Security Controls**:
  - **LLM01**: Prompt injection detection and blocking
  - **LLM02**: Sensitive information redaction (API keys, tokens, PII)
  - **LLM03**: Model allowlisting for supply chain security
  - **LLM06**: Tool/action gating with approval workflows
  - **LLM07**: System prompt leakage prevention
- **Configurable Enforcement**: Monitor, soft, or hard enforcement modes
- **Structured Logging**: JSON logs with request IDs for observability
- **Prometheus Metrics**: Built-in metrics endpoint for monitoring
- **Production Ready**: Health checks, graceful shutdown, Docker and Kubernetes support

## Architecture

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  Open WebUI  │ ──────> │ LLM Gateway  │ ──────> │    Ollama    │
│   (Client)   │         │  (Security)  │         │  (Backend)   │
└──────────────┘         └──────────────┘         └──────────────┘
                                │
                                │ Policy Enforcement
                                ├─ Prompt injection detection
                                ├─ Output redaction
                                ├─ Model allowlisting
                                └─ Tool/action gating
```

## Quick Start

### Local Development

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Run the service**:
   ```bash
   python -m uvicorn app.main:app --reload
   ```

4. **Test the endpoint**:
   ```bash
   curl -X POST http://localhost:8000/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "llama2",
       "messages": [
         {"role": "user", "content": "What is the capital of France?"}
       ]
     }'
   ```

### Running with Docker

1. **Build the image**:
   ```bash
   docker build -t llm-gateway:latest .
   ```

2. **Run the container**:
   ```bash
   docker run -p 8000:8000 \
     -e OLLAMA_BASE_URL=http://your-ollama-host:11434 \
     -e ENFORCEMENT_MODE=monitor \
     llm-gateway:latest
   ```

### Kubernetes Deployment

1. **Apply the manifests**:
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/secret.yaml
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   ```

2. **Verify deployment**:
   ```bash
   kubectl get pods -n llm-gateway
   kubectl logs -n llm-gateway -l app=llm-gateway
   ```

3. **Access the service**:
   ```bash
   # Port-forward for testing
   kubectl port-forward -n llm-gateway svc/llm-gateway 8000:80
   ```

### Development with mirrord

For local development against in-cluster services:

1. **Install mirrord**:
   ```bash
   # Follow instructions at https://mirrord.dev
   ```

2. **Run with mirrord**:
   ```bash
   mirrord exec -t deployment/ollama python -m uvicorn app.main:app --reload
   ```

   This allows your local gateway to connect to the in-cluster Ollama service.

## Configuration

All configuration is done via environment variables. See `.env.example` for a complete list.

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_BASE_URL` | `http://ollama.svc.cluster.local:11434` | Ollama backend URL |
| `REQUEST_TIMEOUT_SECONDS` | `30` | Request timeout |
| `MAX_RETRIES` | `2` | Max retry attempts for transient failures |

### Model Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOWED_MODELS` | `""` | Comma-separated list of allowed models |
| `DEFAULT_MODEL` | `llama2` | Default model if allowlist is empty |

### Policy Enforcement

| Variable | Default | Description |
|----------|---------|-------------|
| `ENFORCEMENT_MODE` | `monitor` | Enforcement level: `monitor`, `soft`, or `hard` |
| `ALLOWED_TOOLS` | `""` | Comma-separated list of allowed tool names |
| `HIGH_RISK_TOOLS` | `""` | Tools requiring approval in hard mode |

#### Enforcement Modes

- **monitor**: Log policy violations but allow all requests through
- **soft**: Apply mitigations (strip tools, add warnings) but allow requests
- **hard**: Block requests that violate policies

### Security

| Variable | Default | Description |
|----------|---------|-------------|
| `REQUIRE_API_KEY` | `false` | Enable API key authentication |
| `API_KEY` | `""` | Required API key if authentication enabled |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `LOG_RAW_PROMPTS` | `false` | Log full prompt content (not recommended in production) |

## API Reference

### POST /v1/chat/completions

OpenAI-compatible chat completions endpoint.

**Request**:
```json
{
  "model": "llama2",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "temperature": 0.7,
  "max_tokens": 100,
  "stream": false,
  "tools": [
    {
      "function": {
        "name": "web_search",
        "description": "Search the web"
      }
    }
  ]
}
```

**Response**:
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "llama2",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I help you?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 8,
    "total_tokens": 18
  },
  "metadata": {
    "warning": "input_flagged_for_injection",
    "redactions": ["EMAIL", "API_KEY"]
  }
}
```

**Headers**:
- `X-Request-ID`: Optional request ID (generated if not provided)
- `Authorization`: Bearer token (required if `REQUIRE_API_KEY=true`)

### GET /healthz

Health check endpoint.

**Response**:
```json
{
  "status": "healthy"
}
```

### GET /metrics

Prometheus metrics endpoint.

**Metrics**:
- `llm_gateway_requests_total`: Total requests by method, endpoint, status
- `llm_gateway_policy_decisions_total`: Policy decisions by type, decision, mode
- `llm_gateway_forward_latency_seconds`: Latency histogram for Ollama requests

## Security Policies

### LLM01: Prompt Injection Detection

Detects suspicious patterns in user input:
- "ignore previous instructions"
- "bypass filter"
- "reveal system prompt"
- "jailbreak" attempts
- And more...

**Behavior by mode**:
- **monitor**: Log warning, allow through
- **soft**: Disable tools, add warning metadata, allow through
- **hard**: Block request with 400 error

### LLM02: Sensitive Information Redaction

Redacts sensitive patterns from outputs:
- API keys (OpenAI, HuggingFace, AWS, GitHub)
- JWT tokens
- Email addresses
- SSNs
- Credit card numbers

Redacted content is replaced with `[REDACTED_TYPE]` placeholders.

### LLM03: Supply Chain - Model Allowlisting

Only models in `ALLOWED_MODELS` are permitted. Prevents:
- Dynamic model name injection
- Unauthorized model usage
- Supply chain attacks via model selection

### LLM06: Tool/Action Gating

Control which tools can be used:
- `ALLOWED_TOOLS`: Permitted tool names
- `HIGH_RISK_TOOLS`: Tools requiring approval in hard mode

**Behavior by mode**:
- **monitor**: Log tool usage
- **soft**: Strip disallowed tools
- **hard**: Block request or require approval

### LLM07: System Prompt Leakage Prevention

Detects and filters system prompt leakage:
- Checks for "You are an AI assistant" patterns
- Blocks `<|system|>` tags and similar
- Redacts entire response if leakage detected

## Testing

### Run Unit Tests

```bash
pytest tests/test_policy.py -v
```

### Run Integration Tests

```bash
pytest tests/test_integration.py -v
```

### Run All Tests with Coverage

```bash
pytest --cov=app --cov-report=html
```

## Use with Open WebUI

Configure Open WebUI to use the gateway:

1. **Set the API endpoint**:
   - Go to Open WebUI Settings > Connections
   - Set OpenAI API URL to: `http://llm-gateway.llm-gateway.svc.cluster.local/v1`
   - Or for local: `http://localhost:8000/v1`

2. **Configure API key** (if enabled):
   - Set the API key in Open WebUI to match `API_KEY` environment variable

3. **Select models**:
   - Only models in `ALLOWED_MODELS` will work
   - Open WebUI will show these as available models

## Observability

### Structured Logs

All logs are JSON-formatted with:
- `timestamp`: ISO 8601 timestamp
- `level`: Log level (INFO, WARNING, ERROR)
- `message`: Human-readable message
- `request_id`: Unique request identifier
- Policy-specific fields (model, enforcement_mode, etc.)

**Example log**:
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "WARNING",
  "name": "app.policy",
  "message": "Prompt injection detected",
  "request_id": "abc-123",
  "patterns": ["ignore previous instructions"],
  "enforcement_mode": "hard",
  "content_length": 42
}
```

### Request Tracing

Each request has a unique ID:
- Accepts `X-Request-ID` header
- Auto-generates UUID if not provided
- Returned in response headers
- Included in all logs for that request

### Prometheus Metrics

Access at `/metrics`:

```bash
curl http://localhost:8000/metrics
```

**Key metrics**:
- Request rates and errors
- Policy decision counts
- Latency percentiles

## Development

### Project Structure

```
llm-gateway/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI application
│   ├── config.py        # Configuration management
│   ├── policy.py        # Policy enforcement
│   └── ollama.py        # Ollama client
├── tests/
│   ├── test_policy.py   # Policy unit tests
│   └── test_integration.py  # Integration tests
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── Dockerfile
├── requirements.txt
├── pytest.ini
└── README.md
```

### Adding New Policies

1. Add detection logic to `app/policy.py`
2. Add tests to `tests/test_policy.py`
3. Integrate into `evaluate_input_policy()` or `evaluate_output_policy()`
4. Document in README

### Code Style

- Use type hints
- Follow PEP 8
- Write docstrings for public functions
- Keep functions focused and testable

## Limitations and Future Work

### Current Limitations

1. **Streaming**: Basic streaming support; output policies are applied post-stream
2. **Tool Format**: OpenAI tool format may not perfectly map to Ollama
3. **Approval Workflows**: High-risk tool approval is stubbed (returns error)
4. **Rate Limiting**: Not implemented (add nginx ingress or middleware)

### Future Enhancements

- [ ] Advanced prompt injection ML models
- [ ] PII detection with NER models
- [ ] Rate limiting per user/API key
- [ ] Human-in-the-loop approval UI
- [ ] Audit log export to SIEM
- [ ] Multi-backend support (OpenAI, Anthropic, etc.)
- [ ] Response caching
- [ ] Cost tracking and limits

## Troubleshooting

### Connection refused to Ollama

**Problem**: `Connection refused` when connecting to Ollama.

**Solution**:
- Verify `OLLAMA_BASE_URL` is correct
- Check Ollama service is running: `kubectl get svc -n ollama`
- Test connectivity: `kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://ollama.svc.cluster.local:11434/api/tags`

### Model not allowed error

**Problem**: `Model 'xyz' is not allowed` error.

**Solution**:
- Add model to `ALLOWED_MODELS` in ConfigMap
- Or update `.env` locally
- Restart gateway after config change

### All requests blocked in hard mode

**Problem**: All requests return 400 errors in hard mode.

**Solution**:
- Check logs for specific policy violations
- Consider using `soft` mode during testing
- Adjust policies (`ALLOWED_TOOLS`, etc.) as needed

### High latency

**Problem**: Slow response times.

**Solution**:
- Increase `REQUEST_TIMEOUT_SECONDS`
- Check Ollama backend performance
- Review `forward_latency_seconds` metric
- Consider increasing gateway replicas

## License

[Your License Here]

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## Support

For issues and questions:
- GitHub Issues: [your-repo-url]
- Documentation: This README
- Logs: Check structured logs for detailed error information
