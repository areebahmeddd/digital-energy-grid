#!/usr/bin/env python3
"""
Thin wrapper around DEG/scripts/generate_postman_collection.py.

Roles (use the business-role names):
  BUYER                 — buyer-side trading platform (was BAP)
  SELLER                — seller-side trading platform (was BPP)
  BUYERDISCOMLEDGER     — buyer's discom ledger TSP (outbound on_status only)
  SELLERDISCOMLEDGER    — seller's discom ledger TSP (outbound on_status only)

Legacy aliases BAP / BPP still work.

Usage:
  python3 scripts/generate_postman_collection.py --role BUYER
  python3 scripts/generate_postman_collection.py --role SELLER
  python3 scripts/generate_postman_collection.py --role BUYERDISCOMLEDGER
  python3 scripts/generate_postman_collection.py --role SELLERDISCOMLEDGER

  # Override ledger host roots (default: http://beckn-router:9000 for both)
  python3 scripts/generate_postman_collection.py --role BUYER \\
    --ledger-host-buyer http://my-buyer-ledger:9000 \\
    --ledger-host-seller http://my-seller-ledger:9000

  # Pass --all to regenerate all four collections in one shot
  python3 scripts/generate_postman_collection.py --all
"""

import subprocess
import sys
from pathlib import Path

DEVKIT_ROOT = Path(__file__).parent.parent
REPO_ROOT = DEVKIT_ROOT.parent.parent
TOP_LEVEL_SCRIPT = REPO_ROOT / "scripts" / "generate_postman_collection.py"

ROLE = None
LEDGER_HOST_BUYER = None
LEDGER_HOST_SELLER = None
ALL = False

i = 1
while i < len(sys.argv):
    if sys.argv[i] == "--role" and i + 1 < len(sys.argv):
        ROLE = sys.argv[i + 1]
        i += 2
    elif sys.argv[i] == "--ledger-host-buyer" and i + 1 < len(sys.argv):
        LEDGER_HOST_BUYER = sys.argv[i + 1]
        i += 2
    elif sys.argv[i] == "--ledger-host-seller" and i + 1 < len(sys.argv):
        LEDGER_HOST_SELLER = sys.argv[i + 1]
        i += 2
    elif sys.argv[i] == "--all":
        ALL = True
        i += 1
    else:
        i += 1

if ROLE is None and not ALL:
    print("Usage: python3 scripts/generate_postman_collection.py --role BUYER|SELLER|BUYERDISCOMLEDGER|SELLERDISCOMLEDGER")
    print("       python3 scripts/generate_postman_collection.py --all")
    print("       [--ledger-host-buyer <url>] [--ledger-host-seller <url>]")
    sys.exit(1)

ROLES_TO_RUN = ["BUYER", "SELLER", "BUYERDISCOMLEDGER", "SELLERDISCOMLEDGER", "SELLERDISCOM"] if ALL else [ROLE]

usecase = "uc1"
output_dir = str(DEVKIT_ROOT / usecase / "postman")

last_ret = 0
for r in ROLES_TO_RUN:
    cmd = [
        sys.executable, str(TOP_LEVEL_SCRIPT),
        "--devkit", "p2p-trading-ies-wave2",
        "--role", r,
        "--usecase", usecase,
        "--output-dir", output_dir,
        "--no-validate",
    ]
    if LEDGER_HOST_BUYER:
        cmd += ["--ledger-host-buyer", LEDGER_HOST_BUYER]
    if LEDGER_HOST_SELLER:
        cmd += ["--ledger-host-seller", LEDGER_HOST_SELLER]
    ret = subprocess.call(cmd)
    if ret != 0:
        last_ret = ret

sys.exit(last_ret)
