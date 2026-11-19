#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  printf 'Usage: %s "/path/to/UE_5.x"\n' "$0" >&2
  exit 2
fi
task_engine="$1"
task_builder="$task_engine/Engine/Build/BatchFiles/Mac/Build.sh"
if [[ ! -f "$task_builder" ]]; then
  printf 'Unreal Engine not found at that folder. Supply the folder containing Engine/.\n' >&2
  exit 2
fi
# DEVELOPER_DIR may select a separately installed compatible Xcode; do not change xcode-select.
xcodebuild -version
exec "$task_builder" StarflightUEEditor Mac Development "-Project=$task_root/StarflightUE.uproject" -WaitMutex -MaxParallelActions=2
