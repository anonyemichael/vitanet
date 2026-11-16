# app/services/ai_client.py
"""The one place the backend talks to a language model: the VitaNet model, served with an OpenAI-compatible API
(e.g. vLLM on the VitaNet model server). No third-party model (Gemini / OpenRouter) is used any more.

Settings: AI_BASE_URL (e.g. http://<model-server>:8000/v1), AI_MODEL (e.g. vitanet-27b), AI_API_KEY, AI_TIMEOUT_S.
When AI_BASE_URL is empty or the server does not answer, callers get None and must use their own safe fallback
(the chat says the assistant is offline and still shows danger-sign warnings; alerts use a template).
"""
import logging
from typing import Optional

import openai

from app.core.config import settings

logger = logging.getLogger(__name__)
_client: Optional[openai.OpenAI] = None


def enabled() -> bool:
    return bool(settings.AI_BASE_URL)


def get_client() -> Optional[openai.OpenAI]:
    global _client
    if not enabled():
        return None
    if _client is None:
        _client = openai.OpenAI(base_url=settings.AI_BASE_URL, api_key=settings.AI_API_KEY or "not-needed",
                                timeout=settings.AI_TIMEOUT_S, max_retries=1)
    return _client


def complete_text(prompt: str, max_tokens: int = 200, temperature: float = 0.2, system: Optional[str] = None) -> Optional[str]:
    """One short text answer from the VitaNet model, or None if it is not available."""
    client = get_client()
    if client is None:
        return None
    messages = ([{"role": "system", "content": system}] if system else []) + [{"role": "user", "content": prompt}]
    try:
        r = client.chat.completions.create(model=settings.AI_MODEL, messages=messages,
                                           max_tokens=max_tokens, temperature=temperature)
        return (r.choices[0].message.content or "").strip() or None
    except Exception as e:
        logger.warning("VitaNet model unavailable: %s", e)
        return None
