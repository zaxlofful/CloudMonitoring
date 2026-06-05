# CloudMonitoring Server (Node.js)

This is the out-of-game sidecar that watches Factorio's `script-output/` for `cloudmonitoring-data-*.json` files and sends alerts when an item's production hits `0`.

## Quick start

```bash
cd server
cp cloudmonitoring-config.example.yaml cloudmonitoring-config.yaml
npm install
npm start
```

## Configuration

- Config file: `cloudmonitoring-config.yaml` (override with `CLOUDMONITORING_CONFIG=/path/to/config.yaml`)
- Env vars in YAML: supports `${VAR_NAME}` substitution

### Paths

- Game folder: `CLOUDMONITORING_GAME_FOLDER` (default: `/app/gamedata`)
- Script output: `CLOUDMONITORING_OUTPUT_DIR` (default: `${game_folder}/script-output`)
- Alert log: `CLOUDMONITORING_ALERT_LOG` (default: `${game_folder}/cloudmonitoring-alerts.log`)

### Notifications

Enabled notifiers are loaded from `notifications:` in YAML. Supported types:

- `email` (SMTP via `nodemailer`)
- `webhook` (HTTP POST via Node's built-in `fetch`)
- `sms` (Twilio via optional dependency `twilio`)
