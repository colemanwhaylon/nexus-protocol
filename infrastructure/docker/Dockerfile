# Nexus Protocol API Server
# Multi-stage Docker build for Go backend with SQLite support
#
# Build: docker build -t nexus-api -f infrastructure/docker/Dockerfile .
# Run: docker run -p 8080:8080 nexus-api
#
# For development with hot reload:
# docker build --target development -t nexus-api-dev -f infrastructure/docker/Dockerfile .

# ============================================
# Stage 1: Builder
# ============================================
FROM golang:1.24-alpine AS builder

# Build arguments
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown

# Install build dependencies
# - git: for fetching Go modules
# - ca-certificates: for HTTPS
# - gcc/musl-dev: for CGO (required by SQLite)
# - make: for Makefile support
RUN apk add --no-cache \
    git \
    ca-certificates \
    gcc \
    musl-dev \
    make \
    sqlite-dev

# Set working directory
WORKDIR /build

# Copy go module files first for caching
COPY backend/go.mod backend/go.sum* ./

# Download dependencies (cached layer)
RUN go mod download

# Copy backend source code
COPY backend/ .

# Build the application
# CGO_ENABLED=1 is required for SQLite support
# -ldflags: embed version info and strip debug symbols
# -trimpath: remove file system paths from executable
RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s \
        -X 'main.Version=${VERSION}' \
        -X 'main.Commit=${COMMIT}' \
        -X 'main.BuildDate=${BUILD_DATE}'" \
    -trimpath \
    -o /build/nexus-api \
    ./cmd/server

# ============================================
# Stage 2: Development (optional, use --target development)
# ============================================
FROM golang:1.24-alpine AS development

# Install development dependencies
RUN apk add --no-cache \
    git \
    ca-certificates \
    gcc \
    musl-dev \
    make \
    sqlite-dev \
    curl \
    bash

# Install development tools
# Note: air@latest requires Go 1.25+, pin to v1.52.3 for Go 1.23 compatibility
RUN go install github.com/air-verse/air@v1.52.3 && \
    go install github.com/swaggo/swag/cmd/swag@latest

# Create non-root user
RUN addgroup -g 1000 nexus && \
    adduser -u 1000 -G nexus -s /bin/bash -D nexus

# Create directories and set permissions for Go cache
RUN mkdir -p /app/data /app/logs && \
    chown -R nexus:nexus /app && \
    chown -R nexus:nexus /go

WORKDIR /app

# Environment variables for development
ENV GIN_MODE=debug
ENV PORT=8080
ENV LOG_LEVEL=debug
ENV DB_DRIVER=sqlite
ENV DB_PATH=/app/data/nexus.db
ENV CACHE_DRIVER=memory

# Expose ports (8080 for API, 2345 for delve debugger)
EXPOSE 8080 2345

# Switch to non-root user
USER nexus

# Default command for development (using air for hot reload)
CMD ["air", "-c", ".air.toml"]

# ============================================
# Stage 3: Runtime (DEFAULT - used by Railway/production)
# ============================================
FROM alpine:3.19 AS runtime

# Labels
LABEL org.opencontainers.image.title="Nexus Protocol API"
LABEL org.opencontainers.image.description="DeFi + NFT + Enterprise Tokenization API Server"
LABEL org.opencontainers.image.vendor="Nexus Protocol"
LABEL org.opencontainers.image.source="https://github.com/colemanwhaylon/nexus-protocol"

# Install runtime dependencies
# - ca-certificates: for HTTPS
# - tzdata: for timezone support
# - sqlite-libs: for SQLite runtime
# - curl: for healthchecks
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    sqlite-libs \
    curl

# Create non-root user for security
RUN addgroup -g 1000 nexus && \
    adduser -u 1000 -G nexus -s /bin/sh -D nexus

# Create directories
RUN mkdir -p /app/data /app/logs /app/config && \
    chown -R nexus:nexus /app

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/nexus-api /app/nexus-api

# Copy any config files if they exist
# COPY --chown=nexus:nexus backend/config/* /app/config/

# Set ownership
RUN chown nexus:nexus /app/nexus-api

# Switch to non-root user
USER nexus

# Environment variables
ENV GIN_MODE=release
ENV PORT=8080
ENV LOG_LEVEL=info
ENV DB_DRIVER=sqlite
ENV DB_PATH=/app/data/nexus.db
ENV CACHE_DRIVER=memory

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["/app/nexus-api"]
