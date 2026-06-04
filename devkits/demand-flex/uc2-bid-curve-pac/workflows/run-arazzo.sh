#!/usr/bin/env bash
# Run the uc2-bid-curve-pac Arazzo workflows via Redocly Respect.
#
# Default mode (no PUBLIC_URL): payload bapUri/bppUri are rewritten to
# http://beckn-router:9000 — Caddy bridges BAP↔BPP traffic locally inside
# docker, no ngrok needed.
#
# Over-internet mode (forces public-internet traversal): set PUBLIC_URL
# to the ngrok tunnel URL fronting beckn-router:9000.
#
# Usage (from uc2-bid-curve-pac/workflows/):
#   ./run-arazzo.sh                                                    # local-bridge mode
#   ./run-arazzo.sh -w select-through-settlement -v
#   PUBLIC_URL=https://your-domain.ngrok-free.dev ./run-arazzo.sh      # over-internet mode

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_ARAZZO_ARGS=("$@")

# Point sandbox-bpp at this use case's response fixtures and recreate the
# container so the new bind-mount takes effect. Compose evaluates
# RESPONSES_DIR against install/docker-compose.yml at config time, so a
# changed value triggers a recreate without touching other services.
DEVKIT_ROOT="$(cd "$HERE/../.." && pwd)"
export RESPONSES_DIR="../uc2-bid-curve-pac/responses"
(cd "$DEVKIT_ROOT/install" && docker compose up -d sandbox-bpp >/dev/null)

# shellcheck disable=SC1091
source "$(cd "$HERE/../../.." && pwd)/scripts/run-arazzo-lib.sh"
run_arazzo "$HERE" "demand-flex-uc2" "bid-curve-pac.arazzo.yaml"
