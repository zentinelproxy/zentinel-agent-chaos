# syntax=docker/dockerfile:1.4

# Zentinel Chaos Engineering Agent Container Image
#
# Targets:
#   - prebuilt: For CI with pre-built binaries

################################################################################
# Pre-built binary stage (for CI builds)
################################################################################
FROM gcr.io/distroless/cc-debian12:nonroot AS prebuilt

COPY zentinel-agent-chaos /zentinel-agent-chaos

LABEL org.opencontainers.image.title="Zentinel Chaos Engineering Agent" \
      org.opencontainers.image.description="Zentinel Chaos Engineering Agent for Zentinel reverse proxy" \
      org.opencontainers.image.vendor="Raskell" \
      org.opencontainers.image.source="https://github.com/zentinelproxy/zentinel-agent-chaos"

ENV RUST_LOG=info,zentinel_agent_chaos=debug \
    SOCKET_PATH=/var/run/zentinel/chaos.sock

USER nonroot:nonroot

ENTRYPOINT ["/zentinel-agent-chaos"]
