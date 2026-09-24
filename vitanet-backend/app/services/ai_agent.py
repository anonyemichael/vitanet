"""Server-side AI orchestration for the VitaNet chat assistant."""

import base64
import binascii
import logging
import json
from uuid import UUID

import openai
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.chat import MessageRole
from app.schemas.chat_blocks import TextBlock
from app.services import ai_blocks, ai_tools, chat_service, user_settings_service
from app.services.ai_system_prompt import build_system_prompt

logger = logging.getLogger(__name__)

# Use OpenRouter fallback keys
or_keys = settings.OPENROUTER_API_KEYS.split(",") if settings.OPENROUTER_API_KEYS else []
api_key = or_keys[0].strip() if or_keys else settings.GEMINI_API_KEY
client = openai.OpenAI(base_url="https://openrouter.ai/api/v1", api_key=api_key)

MODEL = "google/gemini-2.5-flash"
MAX_TOOL_ITERATIONS = 4


def _build_tools() -> list[dict]:
    return [
        {
            "type": "function",
            "function": {
                "name": tool["name"],
                "description": tool["description"],
                "parameters": tool["parameters"],
            }
        }
        for tool in ai_tools.TOOL_DEFINITIONS
    ]


def _history_contents(db: Session, user_id: UUID) -> list[dict]:
    """Return conversational turns only; health data is always requested fresh."""
    contents = []
    for message in chat_service.get_recent_history(db, user_id):
        if message.content and message.role in (MessageRole.USER, MessageRole.ASSISTANT):
            role = "user" if message.role == MessageRole.USER else "assistant"
            contents.append({"role": role, "content": message.content})
    return contents


def run_agent(
    db: Session, user_id: UUID, user_message: str, image_base64: str | None = None
) -> dict:
    chat_service.save_message(db, user_id, MessageRole.USER, content=user_message)
    user_settings = user_settings_service.get_or_create_settings(db, user_id)
    contents = _history_contents(db, user_id)
    
    sys_prompt = build_system_prompt(db, user_id, user_settings)
    messages = [{"role": "system", "content": sys_prompt}] + contents

    if image_base64:
        try:
            # Validate base64
            base64.b64decode(image_base64, validate=True)
            messages.append({
                "role": "user",
                "content": [
                    {"type": "text", "text": user_message},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
                    }
                ]
            })
        except (ValueError, binascii.Error):
            logger.warning("Ignoring malformed image attached to chat by user %s", user_id)
            messages.append({"role": "user", "content": user_message})
    else:
        messages.append({"role": "user", "content": user_message})

    blocks: list = []
    tools_used: set[str] = set()
    hospital_result_cache = None

    try:
        for _ in range(MAX_TOOL_ITERATIONS):
            response = client.chat.completions.create(
                model=MODEL,
                messages=messages,
                tools=_build_tools(),
                temperature=0.2,
                max_tokens=700,
            )
            
            choice = response.choices[0]
            msg = choice.message

            if not msg.tool_calls:
                reply = msg.content or "I'm sorry, I couldn't generate a response just now. Please try again."
                chat_service.save_message(db, user_id, MessageRole.ASSISTANT, content=reply)
                blocks.append(TextBlock(content=reply))
                break

            # msg.model_dump() doesn't include content if None for some old pydantic versions, 
            # but usually it's fine. We'll build the assistant message dictionary manually to be safe.
            assistant_msg = {"role": "assistant"}
            if msg.content:
                assistant_msg["content"] = msg.content
            
            tool_calls = []
            for call in msg.tool_calls:
                tool_calls.append({
                    "id": call.id,
                    "type": call.type,
                    "function": {
                        "name": call.function.name,
                        "arguments": call.function.arguments
                    }
                })
            assistant_msg["tool_calls"] = tool_calls
            messages.append(assistant_msg)

            for call in msg.tool_calls:
                name = call.function.name
                try:
                    args = json.loads(call.function.arguments)
                except json.JSONDecodeError:
                    args = {}
                
                tools_used.add(name)
                chat_service.save_message(
                    db, user_id, MessageRole.ASSISTANT,
                    tool_calls=[{"id": call.id, "name": name, "arguments": args}],
                )
                try:
                    result = ai_tools.execute_tool(name, args, db, user_id)
                except Exception:
                    logger.exception("AI tool %s failed for user %s", name, user_id)
                    result = {"error": "The requested health data is unavailable right now."}
                
                chat_service.save_message(db, user_id, MessageRole.TOOL, tool_name=name, tool_result=result)
                
                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "name": name,
                    "content": json.dumps({"result": result})
                })

                if name == "get_health_metrics" and "error" not in result:
                    blocks.extend(ai_blocks.blocks_for_health_metrics(result))
                elif name == "get_nearby_hospitals":
                    hospital_result_cache = result
                    blocks.extend(ai_blocks.blocks_for_hospitals(result))
        else:
            reply = "I'm sorry, I couldn't complete that request right now. Please try again."
            chat_service.save_message(db, user_id, MessageRole.ASSISTANT, content=reply)
            blocks.append(TextBlock(content=reply))
    except Exception:
        logger.exception("AI chat request failed for user %s", user_id)
        reply = "I'm having trouble connecting right now. Please try again shortly."
        chat_service.save_message(db, user_id, MessageRole.ASSISTANT, content=reply)
        blocks.append(TextBlock(content=reply))

    action_block = ai_blocks.build_action_buttons(tools_used, hospital_result_cache)
    if action_block:
        blocks.append(action_block)
    return {"reply": reply, "blocks": [block.model_dump() for block in blocks]}
