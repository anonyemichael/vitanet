"""The system prompt for the VitaNet chat.

It is the exact text the VitaNet model was trained with (vitanet-model: configs/system_prompt.txt, copied here as
vitanet_system_prompt.txt). The model learned to fetch the person's profile, readings, care circle and nearby
hospitals with its tools, so none of that is pasted into the prompt: a prompt that differs from training makes a
fine-tuned model behave less like it did in testing. Keep the two files identical.
"""
from pathlib import Path

VITANET_SYSTEM_PROMPT = Path(__file__).with_name("vitanet_system_prompt.txt").read_text(encoding="utf-8").strip()


def build_system_prompt(db=None, user_id=None, settings=None) -> str:
    return VITANET_SYSTEM_PROMPT
