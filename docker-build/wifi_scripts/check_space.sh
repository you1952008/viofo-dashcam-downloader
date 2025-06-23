#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

used_pct=$(df --output=pcent / | tail -1 | tr -dc '0-9')
free_pct=$((100 - used_pct))
(( free_pct >= THRESHOLD ))
