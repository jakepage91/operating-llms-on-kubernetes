"""LLM Gateway FastAPI application."""
import logging
import json
import uuid
import hashlib
import time
from contextlib import asynccontextmanager
from typing import Any, Optional, List, Dict, Union

from fastapi import FastAPI, Request, HTTPException, Depends, status
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

from app.config import settings
from app.policy import (
    evaluate_input_policy,
    evaluate_output_policy,
    validate_model_allowlist,
)
from app.ollama import OllamaClient

# Configure structured logging
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format='{"timestamp": "%(asctime)s", "level": "%(levelname)s", "name": "%(name)s", "message": "%(message)s", "extra": %(extra)s}',
)

# Add a custom JSON formatter
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "__dict__"):
            # Add extra fields from record
            for key, value in record.__dict__.items():
                if key not in ["name", "msg", "args", "created", "filename", "funcName",
                              "levelname", "levelno", "lineno", "module", "msecs",
                              "message", "pathname", "process", "processName", "relativeCreated",
                              "thread", "threadName", "exc_info", "exc_text", "stack_info"]:
                    log_data[key] = value
        return json.dumps(log_data)


# Apply JSON formatter to root logger
for handler in logging.root.handlers:
    handler.setFormatter(JsonFormatter())

logger = logging.getLogger(__name__)

# Prometheus metrics
request_counter = Counter(
    "llm_gateway_requests_total",
    "Total number of requests",
    ["method", "endpoint", "status"]
)
policy_decision_counter = Counter(
    "llm_gateway_policy_decisions_total",
    "Policy decisions",
    ["policy_type", "decision", "enforcement_mode"]
)
forward_latency = Histogram(
    "llm_gateway_forward_latency_seconds",
    "Latency of forwarding to Ollama"
)

# Security
security = HTTPBearer(auto_error=False)

# Ollama client
ollama_client = OllamaClient()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    logger.info(
        "Starting LLM Gateway",
        extra={
            "ollama_base_url": settings.ollama_base_url,
            "enforcement_mode": settings.enforcement_mode,
            "require_api_key": settings.require_api_key,
        }
    )
    yield
    logger.info("Shutting down LLM Gateway")


app = FastAPI(
    title="LLM Gateway",
    description="Security gateway for LLM requests with OWASP LLM policy enforcement",
    version="1.0.0",
    lifespan=lifespan,
)


# Request/Response models
class Message(BaseModel):
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None
    top_p: Optional[float] = None
    stream: bool = False
    tools: Optional[List[Dict[str, Any]]] = None
    tool_choice: Optional[Union[str, Dict]] = None

    class Config:
        extra = "allow"  # Allow additional fields


class ChatCompletionResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[Dict[str, Any]]
    usage: Optional[Dict[str, int]] = None


async def verify_api_key(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> None:
    """Verify API key if required."""
    if not settings.require_api_key:
        return

    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key required",
        )

    if credentials.credentials != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )


def get_or_generate_request_id(request: Request) -> str:
    """Get request ID from header or generate new one."""
    request_id = request.headers.get("X-Request-ID")
    if not request_id:
        request_id = str(uuid.uuid4())
    return request_id


def hash_content(content: str) -> str:
    """Hash content for logging without exposing sensitive data."""
    return hashlib.sha256(content.encode()).hexdigest()[:16]


@app.get("/healthz")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/v1/chat/completions")
async def chat_completions(
    request_body: ChatCompletionRequest,
    request: Request,
    _: None = Depends(verify_api_key),
):
    """
    OpenAI-compatible chat completions endpoint.

    Enforces OWASP LLM security policies before forwarding to Ollama.
    """
    request_id = get_or_generate_request_id(request)
    start_time = time.time()

    try:
        # LLM03: Validate model against allowlist
        if not validate_model_allowlist(
            request_body.model,
            settings.allowed_models_list
        ):
            policy_decision_counter.labels(
                policy_type="model_allowlist",
                decision="blocked",
                enforcement_mode=settings.enforcement_mode
            ).inc()

            logger.warning(
                "Model not in allowlist",
                extra={
                    "request_id": request_id,
                    "requested_model": request_body.model,
                    "allowed_models": settings.allowed_models_list,
                }
            )

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Model '{request_body.model}' is not allowed. Allowed models: {', '.join(settings.allowed_models_list)}"
            )

        # Log request (without raw prompts for security)
        user_content = " ".join(
            msg.content for msg in request_body.messages
            if msg.role == "user"
        )

        log_extra = {
            "request_id": request_id,
            "model": request_body.model,
            "message_count": len(request_body.messages),
            "stream": request_body.stream,
        }

        if settings.log_raw_prompts:
            log_extra["user_content"] = user_content
        else:
            log_extra["content_hash"] = hash_content(user_content)
            log_extra["content_length"] = len(user_content)

        logger.info("Processing chat completion request", extra=log_extra)

        # Evaluate input policies
        policy_decision = evaluate_input_policy(
            messages=[msg.model_dump() for msg in request_body.messages],
            tools=request_body.tools,
            enforcement_mode=settings.enforcement_mode,
            allowed_tools=settings.allowed_tools_list,
            high_risk_tools=settings.high_risk_tools_list,
            request_id=request_id,
        )

        policy_decision_counter.labels(
            policy_type="input",
            decision="allowed" if policy_decision.allowed else "blocked",
            enforcement_mode=settings.enforcement_mode
        ).inc()

        if not policy_decision.allowed:
            logger.warning(
                "Request blocked by policy",
                extra={
                    "request_id": request_id,
                    "reason": policy_decision.reason,
                    "metadata": policy_decision.metadata,
                }
            )

            # Check if approval is required
            if policy_decision.metadata and policy_decision.metadata.get("approval_required"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={
                        "error": policy_decision.reason,
                        "approval_required": True,
                        "high_risk_tools": policy_decision.metadata.get("high_risk_tools"),
                    }
                )

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=policy_decision.reason
            )

        # Apply policy modifications to request
        request_dict = request_body.model_dump()
        if policy_decision.modified_request:
            request_dict.update(policy_decision.modified_request)

        # Forward to Ollama
        with forward_latency.time():
            if request_body.stream:
                # Streaming response
                async def stream_with_policy():
                    """Stream response while applying output policies."""
                    try:
                        accumulated_content = ""
                        async for chunk in ollama_client.chat_completion_stream(
                            request_dict,
                            request_id
                        ):
                            # Parse chunk to accumulate content for policy check
                            if chunk.startswith("data: ") and not chunk.startswith("data: [DONE]"):
                                try:
                                    chunk_data = json.loads(chunk[6:])
                                    if "message" in chunk_data:
                                        accumulated_content += chunk_data["message"].get("content", "")
                                except json.JSONDecodeError:
                                    pass

                            yield chunk

                        # Apply output policy to accumulated content
                        if accumulated_content:
                            filtered_output, output_metadata = evaluate_output_policy(
                                accumulated_content,
                                request_id
                            )
                            if output_metadata:
                                logger.warning(
                                    "Output policy applied",
                                    extra={
                                        "request_id": request_id,
                                        "metadata": output_metadata,
                                    }
                                )

                    except Exception as e:
                        logger.error(
                            "Error during streaming",
                            extra={
                                "request_id": request_id,
                                "error": str(e),
                            }
                        )
                        raise

                request_counter.labels(
                    method="POST",
                    endpoint="/v1/chat/completions",
                    status="200"
                ).inc()

                return StreamingResponse(
                    stream_with_policy(),
                    media_type="text/event-stream",
                    headers={"X-Request-ID": request_id}
                )

            else:
                # Non-streaming response
                response = await ollama_client.chat_completion(
                    request_dict,
                    request_id
                )

                # Apply output policy
                if response.get("choices") and len(response["choices"]) > 0:
                    original_content = response["choices"][0]["message"]["content"]
                    filtered_content, output_metadata = evaluate_output_policy(
                        original_content,
                        request_id
                    )

                    if output_metadata:
                        logger.warning(
                            "Output policy applied",
                            extra={
                                "request_id": request_id,
                                "metadata": output_metadata,
                            }
                        )
                        # Add metadata to response
                        response.setdefault("metadata", {}).update(output_metadata)

                    response["choices"][0]["message"]["content"] = filtered_content

                # Add policy metadata if present
                if policy_decision.metadata:
                    response.setdefault("metadata", {}).update(policy_decision.metadata)

                latency_ms = (time.time() - start_time) * 1000
                logger.info(
                    "Request completed",
                    extra={
                        "request_id": request_id,
                        "latency_ms": latency_ms,
                        "model": request_body.model,
                        "outcome": "success",
                    }
                )

                request_counter.labels(
                    method="POST",
                    endpoint="/v1/chat/completions",
                    status="200"
                ).inc()

                return JSONResponse(
                    content=response,
                    headers={"X-Request-ID": request_id}
                )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            "Unexpected error",
            extra={
                "request_id": request_id,
                "error": str(e),
                "error_type": type(e).__name__,
            }
        )

        request_counter.labels(
            method="POST",
            endpoint="/v1/chat/completions",
            status="500"
        ).inc()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


# Import Response for metrics endpoint
from fastapi import Response

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level.lower(),
    )
