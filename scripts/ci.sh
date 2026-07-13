#!/usr/bin/env bash
set -euo pipefail

FORGE="$(bash scripts/find-forge.sh)"

bash scripts/bootstrap.sh
"$FORGE" fmt --check
"$FORGE" build
"$FORGE" test
bash scripts/check-loc.sh
