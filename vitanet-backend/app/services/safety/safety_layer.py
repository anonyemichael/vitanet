"""VitaNet safety layer: fixed danger-sign rules that run outside the model.

Copied from the vitanet-model repo (scripts/safety_layer.py, scripts/referral.py, configs/safety_rules.yaml);
change it there first, run its tests (scripts/eval_safety_layer.py), then copy it here.

If the user's message clearly describes a danger sign (configs/safety_rules.yaml), one short warning line is put in
front of the model's reply. The reply itself is never blocked, shortened or rewritten. Designed not to over-restrict:
a rule is ignored when the matched words are negated ("no fits"), past history ("a seizure 3 years ago"), a general
question ("what are the signs of stroke?"), covered by an exclusion ("threw a fit"), or when the model's reply already
opens by sending the person to hospital.

  from safety_layer import SafetyLayer
  layer = SafetyLayer()
  reply = layer.apply(user_message, model_reply)        # reply with the warning in front, when needed
  finding = layer.check(user_message)                    # what fired and why (for logs and evaluation)

  python scripts/safety_layer.py "My son had a fit this morning, should I give paracetamol?"
"""
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from app.services.safety.referral import refers_first  # same "referred first" rule as the model eval

FLAGS = re.I

NEGATION = re.compile(r"\b(no|not|never|without|denies|denied|nor|neither|isn'?t|wasn'?t|hasn'?t|hadn'?t|doesn'?t|"
                      r"didn'?t|don'?t)\b(\s+\w+){0,2}\s*$", FLAGS)
HISTORY = re.compile(r"\b(\d+|one|two|three|four|five|six|many|several|some)\s+(years?|months?)\s+ago\b|\blast\s+(year|"
                     r"month)\b|\bwhen\s+(he|she|i)\s+was\s+(a\s+baby|small|young|younger|little)\b|\bin\s+the\s+past\b|"
                     r"\bhistory\s+of\b|\bused\s+to\s+(have|get)\b|\bas\s+a\s+child\b", FLAGS)
GENERAL_Q = re.compile(r"\b(if|in\s+case|signs?\s+of|symptoms?\s+of|what\s+causes|how\s+(do\s+i|to|can\s+i)\s+(know|"
                       r"recogni[sz]e|prevent|treat|tell)|what\s+to\s+do\s+(when|if)|first\s+aid\s+for)\b", FLAGS)
SENTENCE_END = re.compile(r"[.!?\n]")
CLAUSE_END = re.compile(r"[,;:.!?\n]|\b(but|and then|however)\b", FLAGS)


@dataclass
class Finding:
    fired: list = field(default_factory=list)       # rule ids that fired
    ignored: list = field(default_factory=list)     # (rule id, reason) for matches that were deliberately ignored
    kind: str = ""                                  # "emergency" | "crisis" | ""

    @property
    def triggered(self):
        return bool(self.fired)


class SafetyLayer:
    def __init__(self, rules_path=Path(__file__).with_name("safety_rules.yaml")):
        cfg = yaml.safe_load(Path(rules_path).read_text(encoding="utf-8"))
        self.banners = {k: " ".join(v.split()) for k, v in cfg["banners"].items()}
        self.context = {k: re.compile(v, FLAGS) for k, v in cfg["context"].items()}
        self.rules = []
        for r in cfg["rules"]:
            self.rules.append({
                "id": r["id"], "label": r["label"], "kind": r["kind"], "context": r.get("context", "any"),
                "any": [re.compile(p, FLAGS) for p in r["any"]],
                "requires": [re.compile(p, FLAGS) for p in r.get("requires", [])],
                "except": [re.compile(p, FLAGS) for p in r.get("except", [])],
            })

    @staticmethod
    def _span(text, start, end, boundary):
        """Text of the sentence/clause around a match, split into the part before it and the whole unit."""
        left = 0
        for m in boundary.finditer(text, 0, start):
            left = m.end()
        m = boundary.search(text, end)
        right = m.start() if m else len(text)
        return text[left:start], text[left:right]

    def _match_ok(self, text, m):
        """None if the match counts, else the reason it is ignored."""
        before_clause, _ = self._span(text, m.start(), m.end(), CLAUSE_END)
        if NEGATION.search(before_clause):
            return "negated"
        before_sentence, sentence = self._span(text, m.start(), m.end(), SENTENCE_END)
        if HISTORY.search(sentence):
            return "past history"
        if GENERAL_Q.search(before_sentence):
            return "general question"
        return None

    def check(self, message):
        text = message or ""
        f = Finding()
        for r in self.rules:
            if r["context"] != "any" and not self.context[r["context"]].search(text):
                continue
            if any(p.search(text) for p in r["except"]):
                if any(p.search(text) for p in r["any"]):
                    f.ignored.append((r["id"], "exclusion"))
                continue
            if not all(p.search(text) for p in r["requires"]):
                continue
            reasons = []
            for p in r["any"]:
                for m in p.finditer(text):
                    why = self._match_ok(text, m)
                    if why is None:
                        reasons = None
                        break
                    reasons.append(why)
                if reasons is None:
                    break
            if reasons is None:
                f.fired.append(r["id"])
            elif reasons:
                f.ignored.append((r["id"], reasons[0]))
        if f.fired:
            kinds = {r["kind"] for r in self.rules if r["id"] in f.fired}
            f.kind = "crisis" if "crisis" in kinds else "emergency"
        return f

    def apply(self, message, reply):
        """The reply with a warning line in front when a danger sign is described and the reply does not already
        open with a referral. Never blocks or alters the model's own text."""
        f = self.check(message)
        if not f.triggered:
            return reply
        if f.kind == "emergency":
            # the opening (first four sentences) already sends them to hospital, unconditionally and before any
            # question: no duplicate warning. "If any of these signs, call 112" still gets the warning.
            text = (reply or "").strip()
            opening = "".join(re.split(r"(?<=[.!?])(?=\s)", text)[:4])
            if refers_first(opening):
                return reply
        return f"{self.banners[f.kind]}\n\n{reply}"


if __name__ == "__main__":
    layer = SafetyLayer()
    msg = " ".join(sys.argv[1:]) or "My son had a fit this morning, should I give paracetamol?"
    res = layer.check(msg)
    print("fired:", res.fired or "-", "| ignored:", res.ignored or "-")
    print(layer.apply(msg, "(model reply here)"))
