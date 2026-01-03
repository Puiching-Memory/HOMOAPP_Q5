# Builder stage compiles the Go binary for production use.
FROM golang:1.22-alpine AS builder

# Install build dependencies for CGO and SQLite
RUN apk add --no-cache git gcc musl-dev

WORKDIR /workspace
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o /workspace/bin/noise-backend ./cmd/server

# Production stage packages only the binary and seeded database.
FROM alpine:3.19
RUN apk add --no-cache ca-certificates
RUN adduser -D -H -u 1000 noise

WORKDIR /app
COPY --from=builder /workspace/bin/noise-backend ./noise-backend
COPY --from=builder /workspace/data ./data
RUN chown -R noise:noise ./data
USER noise

EXPOSE 8080
ENTRYPOINT ["/app/noise-backend"]
