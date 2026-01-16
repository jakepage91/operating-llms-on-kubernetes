"""Ollama backend client and request forwarding."""
import httpx
import asyncio
import logging
import time
from datetime import datetime
from typing import Any, AsyncIterator, Optional, Dict
from app.config import settings

logger = logging.getLogger(__name__)


class OllamaClient:
    """Client for interacting with Ollama backend."""

    def __init__(
        self,
        base_url: Optional[str] = None,
        timeout: Optional[int] = None,
        max_retries: Optional[int] = None,
    ):
        """
        Initialize Ollama client.

        Args:
            base_url: Ollama base URL
            timeout: Request timeout in seconds
            max_retries: Maximum retry attempts
        """
        self.base_url = (base_url or settings.ollama_base_url).rstrip("/")
        self.timeout = timeout or settings.request_timeout_seconds
        self.max_retries = max_retries or settings.max_retries

    def _map_openai_to_ollama(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """
        Map OpenAI-style request to Ollama format.

        Args:
            request: OpenAI-compatible request

        Returns:
            Ollama-formatted request
        """
        ollama_request = {
            "model": request.get("model", settings.default_model),
            "messages": request.get("messages", []),
            "stream": request.get("stream", False),
        }

        # Map optional parameters
        if "temperature" in request:
            ollama_request.setdefault("options", {})["temperature"] = request["temperature"]

        if "max_tokens" in request:
            ollama_request.setdefault("options", {})["num_predict"] = request["max_tokens"]

        if "top_p" in request:
            ollama_request.setdefault("options", {})["top_p"] = request["top_p"]

        # Note: Ollama has different tool/function calling format than OpenAI
        # For now, we'll pass through but log if tools are requested
        if "tools" in request and request["tools"]:
            logger.info("Tools requested but Ollama tool format may differ from OpenAI")

        return ollama_request

    def _map_ollama_to_openai(
        self,
        ollama_response: Dict[str, Any],
        model: str,
    ) -> Dict[str, Any]:
        """
        Map Ollama response to OpenAI format.

        Args:
            ollama_response: Response from Ollama
            model: Model name

        Returns:
            OpenAI-compatible response
        """
        # Extract the assistant message from Ollama response
        message_content = ""
        if "message" in ollama_response:
            message_content = ollama_response["message"].get("content", "")

        # Convert Ollama timestamp to Unix timestamp
        created_timestamp = int(time.time())
        if ollama_response.get("created_at"):
            try:
                # Parse ISO 8601 timestamp from Ollama
                dt = datetime.fromisoformat(ollama_response["created_at"].replace("Z", "+00:00"))
                created_timestamp = int(dt.timestamp())
            except (ValueError, AttributeError):
                pass

        openai_response = {
            "id": f"chatcmpl-{created_timestamp}",
            "object": "chat.completion",
            "created": created_timestamp,
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": message_content,
                    },
                    "finish_reason": "stop" if ollama_response.get("done", False) else None,
                }
            ],
            "usage": {
                "prompt_tokens": ollama_response.get("prompt_eval_count", 0),
                "completion_tokens": ollama_response.get("eval_count", 0),
                "total_tokens": (
                    ollama_response.get("prompt_eval_count", 0) +
                    ollama_response.get("eval_count", 0)
                ),
            },
        }

        return openai_response

    async def _retry_request(
        self,
        client: httpx.AsyncClient,
        url: str,
        json_data: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        """
        Make HTTP request with retry logic.

        Args:
            client: HTTPX client
            url: Request URL
            json_data: Request payload
            request_id: Request identifier

        Returns:
            Response JSON

        Raises:
            httpx.HTTPError: On request failure after retries
        """
        last_exception = None

        for attempt in range(self.max_retries + 1):
            try:
                response = await client.post(url, json=json_data)
                response.raise_for_status()
                return response.json()

            except (httpx.TimeoutException, httpx.NetworkError) as e:
                last_exception = e
                if attempt < self.max_retries:
                    backoff = 2 ** attempt
                    logger.warning(
                        "Request failed, retrying",
                        extra={
                            "request_id": request_id,
                            "attempt": attempt + 1,
                            "max_retries": self.max_retries,
                            "backoff_seconds": backoff,
                            "error": str(e),
                        }
                    )
                    await asyncio.sleep(backoff)
                else:
                    logger.error(
                        "Request failed after all retries",
                        extra={
                            "request_id": request_id,
                            "attempts": attempt + 1,
                            "error": str(e),
                        }
                    )
                    raise

            except httpx.HTTPStatusError as e:
                # Don't retry on HTTP errors (4xx, 5xx)
                logger.error(
                    "HTTP error from Ollama",
                    extra={
                        "request_id": request_id,
                        "status_code": e.response.status_code,
                        "error": str(e),
                    }
                )
                raise

        raise last_exception or httpx.HTTPError("Request failed")

    async def chat_completion(
        self,
        request: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        """
        Forward chat completion request to Ollama.

        Args:
            request: OpenAI-compatible request
            request_id: Request identifier

        Returns:
            OpenAI-compatible response
        """
        ollama_request = self._map_openai_to_ollama(request)
        model = ollama_request["model"]

        url = f"{self.base_url}/api/chat"

        logger.info(
            "Forwarding request to Ollama",
            extra={
                "request_id": request_id,
                "model": model,
                "url": url,
                "stream": ollama_request.get("stream", False),
            }
        )

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            ollama_response = await self._retry_request(
                client=client,
                url=url,
                json_data=ollama_request,
                request_id=request_id,
            )

        logger.info(
            "Received response from Ollama",
            extra={
                "request_id": request_id,
                "model": model,
                "done": ollama_response.get("done", False),
            }
        )

        return self._map_ollama_to_openai(ollama_response, model)

    async def chat_completion_stream(
        self,
        request: Dict[str, Any],
        request_id: str,
    ) -> AsyncIterator[str]:
        """
        Stream chat completion from Ollama.

        Args:
            request: OpenAI-compatible request
            request_id: Request identifier

        Yields:
            Server-sent event strings
        """
        ollama_request = self._map_openai_to_ollama(request)
        ollama_request["stream"] = True
        model = ollama_request["model"]

        url = f"{self.base_url}/api/chat"

        logger.info(
            "Streaming request to Ollama",
            extra={
                "request_id": request_id,
                "model": model,
                "url": url,
            }
        )

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            async with client.stream("POST", url, json=ollama_request) as response:
                response.raise_for_status()

                async for line in response.aiter_lines():
                    if line:
                        # Ollama returns JSONL format
                        # Convert to OpenAI SSE format
                        yield f"data: {line}\n\n"

        yield "data: [DONE]\n\n"
