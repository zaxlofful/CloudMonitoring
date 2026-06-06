# CloudMonitoring Server (Node.js)

This is the out-of-game sidecar that watches Factorio's `script-output/` for `cloudmonitoring-data-*.json` files and sends alerts when an item's production hits `0`.

## Quick start (no dependencies)

```bash
cd server
cp cloudmonitoring-config.example.json cloudmonitoring-config.json
npm start
```

## Configuration

- Config file (default): `cloudmonitoring-config.json` (override with `CLOUDMONITORING_CONFIG=/path/to/config.(json|yaml|yml)`)
- Env var substitution: supports `${VAR_NAME}` in config values

### YAML support (optional)

If you want to use `cloudmonitoring-config.yaml` / `.yml`, install the YAML parser:

```bash
cd server
npm install yaml
```

### Email support (optional)

```bash
cd server
npm install nodemailer
```

### SMS support (optional, Twilio)

```bash
cd server
npm install twilio
```

### Paths

- Game folder: `CLOUDMONITORING_GAME_FOLDER` (default: `/app/gamedata`)
- Script output: `CLOUDMONITORING_OUTPUT_DIR` (default: `${game_folder}/script-output`)
- Alert log: `CLOUDMONITORING_ALERT_LOG` (default: `${game_folder}/cloudmonitoring-alerts.log`)

### Notifications

Enabled notifiers are loaded from `notifications:` in YAML. Supported types:

- `email` (SMTP via `nodemailer`)
- `webhook` (HTTP POST via Node's built-in `fetch`)
- `sms` (Twilio via optional dependency `twilio`)
