from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path


@dataclass(frozen=True)
class Config:
    discord_webhook_url: str

    rcon_host: str
    rcon_port: int
    rcon_password: str

    script_output_dir: Path
    events_filename: str

    poll_interval_seconds: int
    file_poll_interval_seconds: float

    state_file: Path

    @property
    def events_file(self) -> Path:
        return self.script_output_dir / self.events_filename


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return default
    return int(value)


def _env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return default
    return float(value)


def load_config() -> Config:
    discord_webhook_url = os.getenv("DISCORD_WEBHOOK_URL", "").strip()
    if not discord_webhook_url:
        raise ValueError("DISCORD_WEBHOOK_URL is required")

    rcon_host = os.getenv("FACTORIO_RCON_HOST", "127.0.0.1").strip()
    rcon_port = _env_int("FACTORIO_RCON_PORT", 27015)
    rcon_password = os.getenv("FACTORIO_RCON_PASSWORD", "").strip()
    if not rcon_password:
        raise ValueError("FACTORIO_RCON_PASSWORD is required")

    script_output_dir = Path(os.getenv("FACTORIO_SCRIPT_OUTPUT_DIR", "./script-output")).expanduser()
    events_filename = os.getenv("FACTORIO_EVENTS_FILENAME", "mod_events.jsonl").strip() or "mod_events.jsonl"

    poll_interval_seconds = _env_int("POLL_INTERVAL_SECONDS", 60)
    file_poll_interval_seconds = _env_float("FILE_POLL_INTERVAL_SECONDS", 1.0)

    state_file = Path(os.getenv("STATE_FILE", "./daemon_state.json")).expanduser()

    return Config(
        discord_webhook_url=discord_webhook_url,
        rcon_host=rcon_host,
        rcon_port=rcon_port,
        rcon_password=rcon_password,
        script_output_dir=script_output_dir,
        events_filename=events_filename,
        poll_interval_seconds=poll_interval_seconds,
        file_poll_interval_seconds=file_poll_interval_seconds,
        state_file=state_file,
    )

