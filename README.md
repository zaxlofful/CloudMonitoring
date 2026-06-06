# CloudMonitoring

A Factorio mod and companion Go server for monitoring production and sending real-world alerts.

## Overview

CloudMonitoring consists of two components:

1. **Factorio Mod** (Lua) - Exports production data every 15 seconds
2. **Backend Server** (Go) - Monitors data files and sends notifications

## Features

- 📊 Real-time production monitoring
- 🔔 Multi-channel alerts (Email, Webhook, SMS)
- 📈 Tracks item/fluid production across all forces
- 🔄 State machine prevents alert spam
- 🐳 Docker support for easy deployment
- 🔒 Minimal dependencies and secure design

## Components

### Factorio Mod

The in-game mod exports production statistics to JSON files in `script-output/`:

```lua
-- Exports every 15 seconds (900 ticks)
-- File format: cloudmonitoring-data-{timestamp}.json
{
  "timestamp": 1718000000,
  "tick": 12345678,
  "items": [
    {
      "name": "iron-plate",
      "production_count": 1500,
      "consumption_count": 1200
    }
  ]
}
```

### Backend Server (Go)

See [backend/README.md](backend/README.md) for detailed documentation.

The Go server:
- Monitors `script-output/` for new data files
- Tracks production state changes
- Sends alerts when production stops or recovers
- Logs all alerts to JSON lines format
- Runs as a Docker sidecar container

## Quick Start

### Install the Mod

1. Copy mod files to Factorio's mod directory
2. Enable the mod in-game
3. Production data will be written to `script-output/`

### Run the Backend

```bash
cd backend
go build -o cloudmonitoring-backend ./main.go
./cloudmonitoring-backend -config=cloudmonitoring-config.yaml -gamedata=/path/to/factorio
```

Or with Docker:

```bash
docker build -t cloudmonitoring-backend backend/
docker run -v /path/to/factorio:/app/gamedata \
           -v $(pwd)/backend/cloudmonitoring-config.yaml:/app/config/cloudmonitoring-config.yaml \
           cloudmonitoring-backend
```

## Configuration

Create `cloudmonitoring-config.yaml`:

```yaml
notifications:
  - type: email
    enabled: true
    settings:
      smtp_host: smtp.gmail.com
      smtp_port: 587
      sender_email: alerts@example.com
      sender_password: ${ALERT_EMAIL_PASSWORD}
      recipients:
        - player@example.com

  - type: webhook
    enabled: true
    settings:
      url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

Use environment variables for secrets.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐
│  Factorio Mod   │         │   Go Backend     │
│   (control.lua) │         │   (main.go)      │
└────────┬────────┘         └────────┬─────────┘
         │                           │
         │ Writes JSON               │ Reads JSON
         │ every 15s                 │ every 5s
         ▼                           ▼
    ┌─────────────────────────────────────┐
    │  script-output/                     │
    │  cloudmonitoring-data-*.json        │
    └─────────────────────────────────────┘
                    │
                    │ Detects state changes
                    ▼
         ┌──────────────────────┐
         │  Alert Notifiers     │
         │  • Email             │
         │  • Webhook (Slack)   │
         │  • SMS (Twilio)      │
         └──────────────────────┘
```

## License

See [LICENSE](LICENSE) file.
