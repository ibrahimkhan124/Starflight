#!/bin/bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(cd "$project/../.." && pwd)"
native="$repo/AlpineFlight"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
{
  printf 'import Foundation\nimport simd\n'
  sed -n '/^func clamp</,/^}/p' "$native/AlpineFlight/Flight/FlightPhysics.swift"
  sed -n '/^enum SpacePlanet:/,/^}/p' "$native/AlpineFlight/Flight/FlightPhysics.swift"
  sed -n '/^enum CityPlot:/,/^enum InteriorItem:/p' "$native/New Folder/CityResidences.swift" | sed '$d'
  sed '/^    func clearance(at point:/,$d' "$native/AlpineFlight/Flight/PlanetExploration.swift" | sed '/^    var landmarks:/,/^    \/\/ Endor enters/{ /^    \/\/ Endor enters/!d; }'
  printf '}\n'
  cat "$native/AlpineFlight/Flight/CanyonRoutes.swift"
  cat "$project/Tools/export_home_worlds.swift"
} > "$scratch/Export.swift"
swiftc -O -parse-as-library "$scratch/Export.swift" -o "$scratch/export"
"$scratch/export" "$project/Content/Starflight/Worlds"
