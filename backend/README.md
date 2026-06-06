# CloudMonitoring Backend

Go server/notification system for monitoring Factorio production and sending alerts.

## Overview

This is the out-of-game component of CloudMonitoring. It monitors production data files exported by the Factorio mod and sends notifications when item production drops to zero.

## Features

- **File Watching**: Monitors `script-output/` directory for new JSON data files
- **Alert State Machine**: Tracks production states (producing → alerted → recovering)
- **Configurable Notifications**: Email, Webhook, and SMS support
- **Alert Logging**: JSON lines format for easy parsing
- **Docker Support**: Runs as a sidecar container alongside Factorio
- **Minimal Dependencies**: Uses Go standard library where possible

## Architecture

```
backend/
├── config/          # YAML configuration parsing
├── notifiers/       # Notification plugins (email, webhook, SMS)
├── state/           # Alert state management
├── file/            # File watching and JSON parsing
├── log/             # Alert logging
├── main.go          # Entry point
├── Dockerfile       # Container definition
└── go.mod           # Go module definition
```

## Configuration

Create a `cloudmonitoring-config.yaml` file:

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
        - player1@example.com

  - type: webhook
    enabled: true
    settings:
      url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
      method: POST
```

Use environment variables for secrets:
```bash
export ALERT_EMAIL_PASSWORD="your-password"
export TWILIO_AUTH_TOKEN="your-token"
```

## Building

```bash
cd backend
go mod download
go build -o cloudmonitoring-backend ./main.go
```

## Running

```bash
./cloudmonitoring-backend -config=cloudmonitoring-config.yaml -gamedata=/path/to/factorio/save
```

Or with Docker:

```bash
docker build -t cloudmonitoring-backend .
docker run -v /path/to/factorio/save:/app/gamedata \
           -v $(pwd)/cloudmonitoring-config.yaml:/app/config/cloudmonitoring-config.yaml \
           -e ALERT_EMAIL_PASSWORD=yourpassword \
           cloudmonitoring-backend
```

## How It Works

1. **Lua Mod**: Exports production data to `script-output/cloudmonitoring-data-{timestamp}.json` every 15 seconds
2. **File Watcher**: Detects new files and parses JSON
3. **State Manager**: Tracks production rates and state transitions
4. **Notifiers**: Send alerts when production stops or recovers
5. **Alert Logger**: Records all alerts to `cloudmonitoring-alerts.log`

## Alert State Machine

- `producing` → `alerted`: Production drops to 0 (sends alert)
- `alerted` → `recovering`: Production resumes
- `recovering` → `alerted`: Production drops to 0 again (sends new alert)
- `recovering` → `producing`: Normal operation

## Data Retention

- Keeps 100-hour rolling window of production data in memory
- Automatically prunes old data every minute
- No database required

## Extensibility

Add new notifiers by implementing the `Notifier` interface:

```go
type Notifier interface {
    Notify(ctx context.Context, itemName string, event string, productionRate float64) error
    Validate() error
    Type() string
}
```

## Supply Chain Security

- Minimal dependencies (only `gopkg.in/yaml.v3`)
- All other functionality uses Go standard library
- Multi-stage Docker build with minimal final image
- Runs as non-root user in container
- Uses `go.sum` for dependency verification

## License

See LICENSE file in repository root.
