"""Policy enforcement for OWASP LLM security controls."""
import re
import logging
from typing import Any, Literal, Optional, Dict, List, Tuple
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class PolicyDecision:
    """Result of a policy evaluation."""
    allowed: bool
    reason: str
    modified_request: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None


# LLM01: Prompt Injection Detection Patterns
PROMPT_INJECTION_PATTERNS = [
    r"ignore\s+.*(previous|all|above|prior).*\s+instructions",
    r"disregard\s+.*(previous|all|above|prior)",
    r"forget\s+.*(previous|all|above|prior)",
    r"bypass\s+.*(filter|security|check|policy)",
    r"reveal\s+.*(system\s+prompt|instructions|config)",
    r"show\s+.*(system\s+prompt|instructions|config)",
    r"what\s+(is|are)\s+your\s+.*(system\s+prompt|instructions)",
    r"repeat\s+.*(system\s+prompt|instructions|config)",
    r"output\s+.*(system\s+prompt|instructions|config)",
    r"you\s+are\s+now\s+in\s+(admin|developer|debug)\s+mode",
    r"enable\s+(admin|developer|debug)\s+mode",
    r"jailbreak",
    r"DAN\s+mode",
]

# LLM02: Sensitive Information Patterns
SENSITIVE_PATTERNS = [
    (r"hf_[a-zA-Z0-9]{30,50}", "HUGGINGFACE_TOKEN"),
    (r"sk-[a-zA-Z0-9]{40,60}", "OPENAI_KEY"),
    (r"AKIA[0-9A-Z]{16}", "AWS_ACCESS_KEY"),
    (r"ghp_[a-zA-Z0-9]{36,50}", "GITHUB_TOKEN"),
    (r"gho_[a-zA-Z0-9]{36,50}", "GITHUB_OAUTH"),
    (r"eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+", "JWT_TOKEN"),
    (r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", "EMAIL"),
    (r"\b\d{3}-\d{2}-\d{4}\b", "SSN"),
    (r"\b(?:\d{4}[-\s]?){3}\d{4}\b", "CREDIT_CARD"),
]

# LLM07: System Prompt Leakage Patterns
SYSTEM_PROMPT_LEAKAGE_PATTERNS = [
    r"You are an? (AI|assistant|helpful|language model)",
    r"System:\s*You",
    r"Your instructions are",
    r"Your role is to",
    r"<\|system\|>",
    r"<system>",
]


def check_prompt_injection(text: str) -> Tuple[bool, List[str]]:
    """
    Check for prompt injection attempts (LLM01).

    Args:
        text: Text to analyze

    Returns:
        Tuple of (is_suspicious, list of matched patterns)
    """
    matches = []
    text_lower = text.lower()

    for pattern in PROMPT_INJECTION_PATTERNS:
        if re.search(pattern, text_lower, re.IGNORECASE):
            matches.append(pattern)

    return len(matches) > 0, matches


def redact_sensitive_info(text: str) -> Tuple[str, List[str]]:
    """
    Redact sensitive information from text (LLM02).

    Args:
        text: Text to redact

    Returns:
        Tuple of (redacted_text, list of redaction types)
    """
    redacted = text
    redaction_types = []

    for pattern, redaction_type in SENSITIVE_PATTERNS:
        matches = re.finditer(pattern, redacted)
        for match in matches:
            redacted = redacted.replace(match.group(), f"[REDACTED_{redaction_type}]")
            if redaction_type not in redaction_types:
                redaction_types.append(redaction_type)

    return redacted, redaction_types


def check_system_prompt_leakage(text: str) -> bool:
    """
    Check if text contains system prompt leakage (LLM07).

    Args:
        text: Text to analyze

    Returns:
        True if leakage detected
    """
    for pattern in SYSTEM_PROMPT_LEAKAGE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False


def evaluate_input_policy(
    messages: List[Dict[str, Any]],
    tools: Optional[List[Dict[str, Any]]],
    enforcement_mode: Literal["monitor", "soft", "hard"],
    allowed_tools: List[str],
    high_risk_tools: List[str],
    request_id: str,
) -> PolicyDecision:
    """
    Evaluate input against all policies.

    Args:
        messages: Chat messages
        tools: Requested tools
        enforcement_mode: Enforcement level
        allowed_tools: List of allowed tool names
        high_risk_tools: List of high-risk tool names
        request_id: Request identifier

    Returns:
        PolicyDecision with enforcement result
    """
    # Extract user messages
    user_content = " ".join(
        msg.get("content", "")
        for msg in messages
        if msg.get("role") == "user"
    )

    # LLM01: Check for prompt injection
    is_injection, injection_patterns = check_prompt_injection(user_content)

    if is_injection:
        logger.warning(
            "Prompt injection detected",
            extra={
                "request_id": request_id,
                "patterns": injection_patterns,
                "enforcement_mode": enforcement_mode,
                "content_length": len(user_content),
            }
        )

        if enforcement_mode == "hard":
            return PolicyDecision(
                allowed=False,
                reason="Request blocked: potentially unsafe input detected",
            )
        elif enforcement_mode == "soft":
            # Strip tools and add warning metadata
            return PolicyDecision(
                allowed=True,
                reason="Input flagged but allowed in soft mode",
                modified_request={"tools": None},
                metadata={"warning": "input_flagged_for_injection"},
            )
        # Monitor mode: just log and allow

    # LLM06: Tool/Action gating
    if tools:
        requested_tool_names = [tool.get("function", {}).get("name") for tool in tools]

        # Check if tools are allowed
        disallowed_tools = [
            name for name in requested_tool_names
            if allowed_tools and name not in allowed_tools
        ]

        if disallowed_tools:
            logger.warning(
                "Disallowed tools requested",
                extra={
                    "request_id": request_id,
                    "disallowed_tools": disallowed_tools,
                    "enforcement_mode": enforcement_mode,
                }
            )

            if enforcement_mode == "hard":
                return PolicyDecision(
                    allowed=False,
                    reason=f"Tools not allowed: {', '.join(disallowed_tools)}",
                )
            elif enforcement_mode == "soft":
                # Strip disallowed tools
                filtered_tools = [
                    tool for tool in tools
                    if tool.get("function", {}).get("name") not in disallowed_tools
                ]
                return PolicyDecision(
                    allowed=True,
                    reason="Disallowed tools stripped",
                    modified_request={"tools": filtered_tools or None},
                )

        # Check for high-risk tools requiring approval
        high_risk_requested = [
            name for name in requested_tool_names
            if name in high_risk_tools
        ]

        if high_risk_requested and enforcement_mode == "hard":
            logger.warning(
                "High-risk tools require approval",
                extra={
                    "request_id": request_id,
                    "high_risk_tools": high_risk_requested,
                }
            )
            return PolicyDecision(
                allowed=False,
                reason=f"High-risk tools require approval: {', '.join(high_risk_requested)}",
                metadata={"approval_required": True, "high_risk_tools": high_risk_requested},
            )

    return PolicyDecision(allowed=True, reason="All policies passed")


def evaluate_output_policy(
    output_text: str,
    request_id: str,
) -> Tuple[str, Dict[str, Any]]:
    """
    Evaluate and filter output.

    Args:
        output_text: Model output text
        request_id: Request identifier

    Returns:
        Tuple of (filtered_output, metadata)
    """
    metadata = {}

    # LLM02: Redact sensitive information
    filtered_output, redaction_types = redact_sensitive_info(output_text)
    if redaction_types:
        logger.warning(
            "Sensitive information redacted from output",
            extra={
                "request_id": request_id,
                "redaction_types": redaction_types,
            }
        )
        metadata["redactions"] = redaction_types

    # LLM07: Check for system prompt leakage
    if check_system_prompt_leakage(filtered_output):
        logger.warning(
            "System prompt leakage detected in output",
            extra={"request_id": request_id}
        )
        # Redact the entire response if it looks like system prompt leakage
        filtered_output = "[Content filtered: potential system information leakage]"
        metadata["system_prompt_leakage"] = True

    return filtered_output, metadata


def validate_model_allowlist(
    requested_model: str,
    allowed_models: List[str],
) -> bool:
    """
    Validate model against allowlist (LLM03: Supply Chain).

    Args:
        requested_model: Requested model name
        allowed_models: List of allowed models

    Returns:
        True if model is allowed
    """
    return requested_model in allowed_models
