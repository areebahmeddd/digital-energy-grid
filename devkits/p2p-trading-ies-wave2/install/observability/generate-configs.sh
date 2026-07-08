#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
devkit_dir="$(cd "$script_dir/../.." && pwd)"
base_dir="$devkit_dir/config"
observability_dir="$base_dir/observability"
fragments_dir="$observability_dir/fragments"

configs="
local-p2p-trading-buyerapp.yaml
local-p2p-trading-sellerapp.yaml
local-p2p-trading-buyerdiscom.yaml
local-p2p-trading-sellerdiscom.yaml
local-p2p-trading-ledger-buyerdiscom.yaml
local-p2p-trading-ledger-sellerdiscom.yaml
"

for config in $configs; do
  base_file="$base_dir/$config"
  fragment_file="$fragments_dir/$config"
  output_file="$observability_dir/$config"

  if [ ! -f "$base_file" ]; then
    echo "Missing base config: $base_file" >&2
    exit 1
  fi

  if [ ! -f "$fragment_file" ]; then
    echo "Missing observability fragment: $fragment_file" >&2
    exit 1
  fi

  cat "$base_file" > "$output_file"
  printf '\n' >> "$output_file"
  cat "$fragment_file" >> "$output_file"
  printf 'Generated %s\n' "$output_file"
done
