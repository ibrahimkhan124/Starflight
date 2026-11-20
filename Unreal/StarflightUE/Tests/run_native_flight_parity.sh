#!/bin/bash
set -euo pipefail
tests="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$tests/.." && pwd)"
native="$(cd "$project/../../AlpineFlight" && pwd)/AlpineFlight/Flight"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
{
    printf 'import Foundation\nimport simd\n'
    sed -n '/^func clamp</,/^}/p; /^struct FlightInput /,/^}/p; /^struct FlightState /,$p' "$native/FlightPhysics.swift"
    cat "$tests/NativeFlightParity.swift"
} > "$scratch/SwiftFlight.swift"
swiftc -O "$native/AircraftType.swift" "$scratch/SwiftFlight.swift" -o "$scratch/source"
clang++ -std=c++20 -Wall -Wextra -Werror -I "$project/Source/StarflightUE/Public" "$tests/NativeFlightParity.cpp" -o "$scratch/parity"
"$scratch/source" > "$scratch/reference.csv"
"$scratch/parity" < "$scratch/reference.csv"
