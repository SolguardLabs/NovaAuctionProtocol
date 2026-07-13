#!/usr/bin/env bash
set -euo pipefail

if [[ -d lib/forge-std/src ]]; then
  exit 0
fi

forge install foundry-rs/forge-std --no-commit
