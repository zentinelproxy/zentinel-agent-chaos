# syntax=docker/dockerfile:1.4

# Sentinel Chaos Engineering Agent Container Image
#
# Targets:
#   - prebuilt: For CI with pre-built binaries

################################################################################
# Pre-built binary stage (for CI builds)
################################################################################
FROM gcr.io/distroless/cc-debian12:nonroot AS prebuilt

COPY sentinel-agent-chaos /sentinel-agent-chaos

LABEL org.opencontainers.image.title="Sentinel Chaos Engineering Agent" \
      org.opencontainers.image.description="Sentinel Chaos Engineering Agent for Sentinel reverse proxy" \
      org.opencontainers.image.vendor="Raskell" \
      org.opencontainers.image.source="https://github.com/raskell-io/sentinel-agent-chaos"

ENV RUST_LOG=info,sentinel_agent_chaos=debug \
    SOCKET_PATH=/var/run/sentinel/chaos.sock

USER nonroot:nonroot

ENTRYPOINT ["/sentinel-agent-chaos"]
