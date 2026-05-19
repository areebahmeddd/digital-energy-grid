#!/usr/bin/env python3
"""
Thin wrapper around DEG/scripts/generate_postman_collection.py.

Roles (business-role names):
  BUYER   — data consumer (was BAP)
  SELLER  — data provider (was BPP)

Legacy aliases BAP / BPP still work.

Usage:
  python3 scripts/generate_postman_collection.py --role BUYER
  python3 scripts/generate_postman_collection.py --role SELLER
  python3 scripts/generate_postman_collection.py --role BUYER --usecase uc2-regulatory-data
  python3 scripts/generate_postman_collection.py --all
"""

import subprocess
import sys
from pathlib import Path

DEVKIT_ROOT = Path(__file__).parent.parent
REPO_ROOT = DEVKIT_ROOT.parent.parent
TOP_LEVEL_SCRIPT = REPO_ROOT / "scripts" / "generate_postman_collection.py"

ROLE = None
USECASE = None
ALL = False
for i, arg in enumerate(sys.argv):
    if arg == "--role" and i + 1 < len(sys.argv):
        ROLE = sys.argv[i + 1]
    if arg == "--usecase" and i + 1 < len(sys.argv):
        USECASE = sys.argv[i + 1]
    if arg == "--all":
        ALL = True

if ROLE is None and not ALL:
    print("Usage: python3 scripts/generate_postman_collection.py --role BUYER|SELLER [--usecase uc1-meter-data|uc2-regulatory-data|uc3-tariff-policy]")
    print("       python3 scripts/generate_postman_collection.py --all")
    sys.exit(1)

ROLES_TO_RUN = ["BUYER", "SELLER"] if ALL else [ROLE]
usecases = [USECASE] if USECASE else ["uc1-meter-data", "uc2-regulatory-data", "uc3-tariff-policy"]

last_ret = 0
for uc in usecases:
    devkit = f"data-exchange-{uc}"
    output_dir = str(DEVKIT_ROOT / uc / "postman")
    for r in ROLES_TO_RUN:
        cmd = [
            sys.executable, str(TOP_LEVEL_SCRIPT),
            "--devkit", devkit,
            "--role", r,
            "--output-dir", output_dir,
            "--name", f"data-exchange-{uc}.{r}-DEG",
            "--no-validate",
        ]
        ret = subprocess.call(cmd)
        if ret != 0:
            last_ret = ret
sys.exit(last_ret)
