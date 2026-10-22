#!/usr/bin/env bash
# Smoke test: run the agent binary behind a real Zentinel (fail-closed) with
# the shared harness from zentinelproxy/.github (agent-smoke/smoke.py).
#
#   AGENT_SMOKE=<path to smoke.py> scripts/smoke-test.sh [<agent-binary> <zentinel-binary>]
#
# The binaries default to $AGENT_BIN and $ZENTINEL_BIN, which the shared
# release workflow sets. Run by that workflow on every platform before any
# asset is published, and by CI on every push and pull request.
#
# 1. With no configuration at all the agent starts and injects nothing.
# 2. With scripts/smoke/chaos.yaml, over the Unix socket and over gRPC:
#    * the v2 handshake works and a path outside every experiment is
#      forwarded (200);
#    * an error experiment answers 503 and the request never reaches the
#      upstream, also with a query string;
#    * a timeout experiment answers 504;
#    * a latency experiment delays but forwards (200);
#    * an excluded path is forwarded although an experiment targets it, also
#      with a query string;
#    * with the agent stopped the clean request is refused (agent on the path).

set -euo pipefail

AGENT_BIN=${1:-${AGENT_BIN:?usage: smoke-test.sh <agent-binary> <zentinel-binary>}}
ZENTINEL_BIN=${2:-${ZENTINEL_BIN:?usage: smoke-test.sh <agent-binary> <zentinel-binary>}}
AGENT_SMOKE=${AGENT_SMOKE:?set AGENT_SMOKE to agent-smoke/smoke.py from zentinelproxy/.github}

CONFIG="$(cd "$(dirname "$0")" && pwd)/smoke/chaos.yaml"

echo "=== chaos agent with no configuration (uds)"
python3 "$AGENT_SMOKE" --agent "$AGENT_BIN" --zentinel "$ZENTINEL_BIN" --name chaos \
    --case '{"name": "nothing injected without experiments", "path": "/chaos/error", "expect": 200}'

cases=(
    --clean '{"name": "outside every experiment", "path": "/smoke"}'
    --case '{"name": "error fault", "path": "/chaos/error", "expect": 503}'
    --case '{"name": "error fault with a query string", "path": "/chaos/error?x=1", "expect": 503}'
    --case '{"name": "timeout fault", "path": "/chaos/timeout", "expect": 504}'
    --case '{"name": "latency fault forwards", "path": "/chaos/slow", "expect": 200}'
    --case '{"name": "excluded path", "path": "/chaos/excluded", "expect": 200}'
    --case '{"name": "excluded path with a query string", "path": "/chaos/excluded?x=1", "expect": 200}'
)

for transport in uds grpc; do
    echo "=== chaos agent over $transport"
    python3 "$AGENT_SMOKE" --agent "$AGENT_BIN" --zentinel "$ZENTINEL_BIN" \
        --name chaos --transport "$transport" \
        --agent-arg=--config --agent-arg "$CONFIG" \
        "${cases[@]}"
done
