# app/services/ai_agent.py
import json
from uuid import UUID

from google import genai
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.chat import MessageRole
from app.services import chat_service, ai_tools, ai_blocks, user_settings_service
from app.services.ai_system_prompt import build_system_prompt
from app.schemas.chat_blocks import TextBlock

client = genai.Client(api_key=settings.GEMINI_API_KEY)
MODEL = "gemini-3.6-flash"
MAX_TOOL_ITERATIONS = 5


def build_tool_declarations():
    return [{"type": "function", **tool} for tool in ai_tools.TOOL_DEFINITIONS]


def build_history_input(db: Session, user_id: UUID) -> list[dict]:
    """Translate our own capped chat history into Interactions API step format."""
    messages = chat_service.get_recent_history(db, user_id)  # already limited, oldest-first
    steps = []

    for msg in messages:
        if msg.role == MessageRole.USER:
            steps.append({"type": "user_input", "content": [{"type": "text", "text": msg.content}]})

        elif msg.role == MessageRole.ASSISTANT:
            if msg.tool_calls:
                for call in msg.tool_calls:
                    steps.append({
                        "type": "function_call",
                        "id": call["id"],
                        "name": call["name"],
                        "arguments": call["arguments"],
                    })
            elif msg.content:
                steps.append({
                    "type": "model_output",
                    "content": [{"type": "text", "text": msg.content}],
                })
        elif msg.role == MessageRole.TOOL:
            call_id = None
            if msg.tool_calls:
                call_id = msg.tool_calls.get("call_id") if isinstance(msg.tool_calls, dict) else None
            steps.append({
                "type": "function_result",
                "name": msg.tool_name,
                "call_id": call_id,
                "result": [{"type": "text", "text": json.dumps(msg.tool_result)}],
            })

    return steps


def run_agent(db: Session, user_id: UUID, user_message: str) -> dict:
    # 1. Save the incoming user message
    chat_service.save_message(db, user_id, MessageRole.USER, content=user_message)

    # 2. Build system prompt (with profile/allergies/care circle injected) + capped history
    settings_obj = user_settings_service.get_or_create_settings(db, user_id)
    system_prompt = build_system_prompt(db, user_id, settings_obj)
    history = build_history_input(db, user_id)
    tools = build_tool_declarations()

    blocks = []
    tools_used = set()
    hospital_result_cache = None
    final_text = None
    iterations = 0

    while final_text is None and iterations < MAX_TOOL_ITERATIONS:
        iterations += 1

        interaction = client.interactions.create(
    model=MODEL,
    store=False,
    input=history,
    system_instruction=system_prompt,   # was: instructions=system_prompt
    tools=tools,
)

        function_calls = [s for s in interaction.steps if s.type == "function_call"]

        if not function_calls:
            final_text = interaction.output_text
            chat_service.save_message(db, user_id, MessageRole.ASSISTANT, content=final_text)
            blocks.append(TextBlock(content=final_text))
            break

        # Replay the model's own steps back into history (required by stateless mode)
        for step in interaction.steps:
            history.append(step.model_dump())

        # Execute each requested tool call, save + append result
        for call in function_calls:
            tools_used.add(call.name)

            chat_service.save_message(
                db, user_id, MessageRole.ASSISTANT,
                tool_calls=[{"id": call.id, "name": call.name, "arguments": call.arguments}],
            )

            result = ai_tools.execute_tool(call.name, call.arguments, db, user_id)

            chat_service.save_message(
                db, user_id, MessageRole.TOOL,
                tool_name=call.name, tool_result=result,
            )

            history.append({
                "type": "function_result",
                "name": call.name,
                "call_id": call.id,
                "result": [{"type": "text", "text": json.dumps(result)}],
            })

            if call.name == "get_health_metrics":
                blocks.extend(ai_blocks.blocks_for_health_metrics(result))
            elif call.name == "get_nearby_hospitals":
                hospital_result_cache = result
                blocks.extend(ai_blocks.blocks_for_hospitals(result))

    action_block = ai_blocks.build_action_buttons(tools_used, hospital_result_cache)
    if action_block:
        blocks.append(action_block)

    return {
        "reply": final_text or "Sorry, I couldn't complete that request right now.",
        "blocks": [b.model_dump() for b in blocks],
    }