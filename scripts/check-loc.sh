#!/usr/bin/env bash
set -euo pipefail

physical="$(find src -type f -name '*.sol' -print0 | xargs -0 cat | wc -l | tr -d ' ')"
non_empty="$(find src -type f -name '*.sol' -print0 | xargs -0 awk 'NF { count++ } END { print count+0 }')"

echo "src physical LOC: ${physical}"
echo "src non-empty LOC: ${non_empty}"
