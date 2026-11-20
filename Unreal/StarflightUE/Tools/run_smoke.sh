#!/bin/bash
set -euo pipefail
engine_root="${1:?Usage: run_smoke.sh /path/to/UE_5.8}"
planet="${2:-Hoth}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
editor="$engine_root/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor"
if [[ ! -x "$editor" ]]; then
  echo "Unreal editor not found: $editor" >&2
  exit 1
fi
log_file="$(mktemp /tmp/starflight-ue-smoke.XXXXXX)"
echo "Engine integration log: $log_file"
cd "$engine_root/Engine/Binaries/Mac"
"$editor" "$project_root/StarflightUE.uproject" -game -windowed \
  -ResX=1280 -ResY=720 -nosplash -stdout -FullStdOutLogOutput \
  -StarflightSmoke "-StarflightWorld=$planet" -benchmark -seconds=30 > "$log_file" 2>&1
rg 'STARFLIGHT_SMOKE' "$log_file"
if ! rg -q 'STARFLIGHT_SMOKE RESULT: PASS' "$log_file"; then
  echo "Engine integration run did not complete successfully. See $log_file" >&2
  exit 1
fi
