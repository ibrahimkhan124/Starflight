#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="$(mktemp -d "${TMPDIR:-/tmp}/starflight-ue-core.XXXXXX")"
trap 'rm -rf "$task_build"' EXIT
"${CXX:-clang++}" -std=c++20 -O1 -g -Wall -Wextra -Werror -fsanitize=address,undefined \
  -I "$task_root/Source/StarflightUE/Public" "$task_root/Tests/CoreTests.cpp" -o "$task_build/core-tests"
"$task_build/core-tests" "$task_root/Tests/SwiftReference.csv"
