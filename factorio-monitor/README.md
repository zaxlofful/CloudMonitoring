# Factorio Monitor (prototype)

Two components work together:

- **Mod**: emits JSON lines to `script-output/mod_events.jsonl` and exposes a remote interface for RCON polling.
- **Daemon**: tails the JSONL file + polls RCON every 60s and forwards events/state to a Discord webhook.

## Mod install (dedicated server)

1. Create a folder named `factorio-monitor_0.1.0` inside your Factorio `mods/` directory.
2. Copy the contents of `factorio-monitor/mod/` into that folder.
3. Ensure `rcon-enabled=true` and `rcon-port`/`rcon-password` are set in `server-settings.json` or CLI args.

The mod writes to `script-output/mod_events.jsonl` (relative to the Factorio server working directory).

## Daemon setup

```bash
cd factorio-monitor/daemon
python -m venv .venv
./.venv/bin/pip install -r requirements.txt
```

Environment variables:

- `DISCORD_WEBHOOK_URL` (required)
- `FACTORIO_RCON_PASSWORD` (required)
- `FACTORIO_RCON_HOST` (default `127.0.0.1`)
- `FACTORIO_RCON_PORT` (default `27015`)
- `FACTORIO_SCRIPT_OUTPUT_DIR` (default `./script-output`)
- `POLL_INTERVAL_SECONDS` (default `60`)
- `FILE_POLL_INTERVAL_SECONDS` (default `1.0`)
- `STATE_FILE` (default `./daemon_state.json`)

Run:

```bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..." \
FACTORIO_RCON_PASSWORD="your-rcon-password" \
FACTORIO_SCRIPT_OUTPUT_DIR="/path/to/factorio/script-output" \
./.venv/bin/python main.py
```

## Prototype events/state

Push events (written to JSONL):

- `player_joined`
- `player_left`
- `player_died` (includes `cause` when available)
- `base_under_attack` (throttled to at most once per ~5s)
- `rocket_launched`

Polled state (every `POLL_INTERVAL_SECONDS`):

- `players_online`
- current research name + progress
- game time (`tick` and `hhmm`)

