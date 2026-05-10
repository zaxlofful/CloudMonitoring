from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any

import requests


@dataclass(frozen=True)
class Notifier:
    webhook_url: str
    timeout_seconds: float = 10.0

    def send_text(self, text: str) -> None:
        response = requests.post(
            self.webhook_url,
            json={"content": text},
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()

    def send_event(self, event: dict[str, Any]) -> None:
        self.send_text(format_event_message(event))

    def send_state(self, state: dict[str, Any]) -> None:
        self.send_text(format_state_message(state))


def _safe_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=str)


def format_event_message(event: dict[str, Any]) -> str:
    name = event.get("event", "unknown")
    if name == "player_joined":
        return f"Player joined: `{event.get('player', '?')}`"
    if name == "player_left":
        return f"Player left: `{event.get('player', '?')}`"
    if name == "player_died":
        cause = event.get("cause")
        cause_text = ""
        if isinstance(cause, dict) and cause.get("name"):
            cause_text = f" (cause: `{cause.get('name')}`)"
        return f"Player died: `{event.get('player', '?')}`{cause_text}"
    if name == "base_under_attack":
        entity = event.get("entity") or {}
        pos = entity.get("position") or {}
        return (
            "Base under attack: "
            f"`{entity.get('name', '?')}` on `{entity.get('surface', '?')}` "
            f"at `({pos.get('x', '?')},{pos.get('y', '?')})`"
        )
    if name == "rocket_launched":
        return "Rocket launched"
    return f"Event: `{name}` {_safe_json(event)}"


def format_state_message(state: dict[str, Any]) -> str:
    players = state.get("players_online")
    research = (state.get("research") or {}) if isinstance(state.get("research"), dict) else {}
    time = (state.get("game_time") or {}) if isinstance(state.get("game_time"), dict) else {}
    r_name = research.get("name") or "none"
    r_prog = research.get("progress")
    r_prog_text = f"{round(float(r_prog) * 100)}%" if r_prog is not None else "n/a"
    hhmm = time.get("hhmm") or "?:??"
    return f"State: players `{players}`, research `{r_name}` `{r_prog_text}`, time `{hhmm}`"

