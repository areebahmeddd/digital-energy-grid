#!/usr/bin/env python3
"""Subscribe the discover service to the catalog service for the P2P trading
network. Equivalent to subscribe-catalog.sh but signs the request with an
Authorization header as required by fabric.nfh.global.

Reads BPP_ID, PUBLIC_KEY, PRIVATE_KEY, RECORD_ID from .env in the same
directory as this script.
"""

import json
import os
import sys
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Load signing kit from wave1
# ---------------------------------------------------------------------------
_SIGNING_KIT = Path(__file__).resolve().parents[2] / "p2p-trading-ies-wave1" / "beckn-signing-kit" / "python"
sys.path.insert(0, str(_SIGNING_KIT.parent))

from python import PayloadSigner  # noqa: E402  (after sys.path manipulation)

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------
def _load_env(env_path: Path) -> None:
    if not env_path.exists():
        raise FileNotFoundError(f".env not found at {env_path}")
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


_load_env(Path(__file__).parent / ".env")

BPP_ID = os.environ["BPP_ID"]
PUBLIC_KEY = os.environ["PUBLIC_KEY"]
PRIVATE_KEY = os.environ["PRIVATE_KEY"]
RECORD_ID = os.environ["RECORD_ID"]

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CATALOG_URL = "https://fabric.nfh.global/beckn/catalog/subscription"
DISCOVER_URL = "https://34.14.221.66.sslip.io/catalog/push"
NETWORK_ID = "nfh.global/testnet-deg"

# ---------------------------------------------------------------------------
# Build payload
# ---------------------------------------------------------------------------
payload = json.dumps({
    "context": {
        "version": "2.0.0",
        "action": "catalog/subscription",
        "messageId": RECORD_ID,
        "transactionId": str(uuid.uuid4()),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "bapId": BPP_ID,
        "bapUri": DISCOVER_URL,
    },
    "message": {
        "subscription": {
            "networkIds": [NETWORK_ID],
        }
    },
}, separators=(",", ":"))

# ---------------------------------------------------------------------------
# Sign and send
# ---------------------------------------------------------------------------
signer = PayloadSigner(
    subscriber_id=BPP_ID,
    unique_key_id=PUBLIC_KEY,
    signing_private_key=PRIVATE_KEY,
)
auth_header = signer.sign_payload(payload)

req = urllib.request.Request(
    CATALOG_URL,
    data=payload.encode(),
    headers={
        "Content-Type": "application/json",
        "Authorization": auth_header,
    },
    method="POST",
)

try:
    with urllib.request.urlopen(req) as resp:
        body = resp.read().decode()
    print(body)
except urllib.error.HTTPError as exc:
    print(f"HTTP {exc.code} {exc.reason}", file=sys.stderr)
    print(exc.read().decode(), file=sys.stderr)
    sys.exit(1)
