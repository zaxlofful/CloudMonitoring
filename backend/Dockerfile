# Multi-stage build for minimal final image
FROM golang:1.20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-w -s" -o cloudmonitoring-backend ./main.go

# Final stage - minimal image
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 cloudmon && \
    adduser -D -u 1000 -G cloudmon cloudmon

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/cloudmonitoring-backend /app/cloudmonitoring-backend

# Set ownership
RUN chown -R cloudmon:cloudmon /app

# Switch to non-root user
USER cloudmon

# Expose any ports if needed (none for this app)
# EXPOSE 8080

# Set default command
ENTRYPOINT ["/app/cloudmonitoring-backend"]
CMD ["-config=/app/config/cloudmonitoring-config.yaml", "-gamedata=/app/gamedata"]
