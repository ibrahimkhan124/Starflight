#!/bin/bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
native="$(cd "$project/../../AlpineFlight" && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
swiftc -O "$native/AlpineFlight/Flight/AircraftType.swift" "$project/Tools/export_flight_profiles.swift" -o "$scratch/export"
ships=()
for file in "$native"/Art/BlenderLibrary/Ships/Ship_*.blend; do
    key="${file##*/Ship_}"
    key="${key%.blend}"
    [[ "$key" =~ ^[a-zA-Z0-9]+$ ]] && ships+=("$key")
done
"$scratch/export" "${ships[@]}" > "$scratch/FleetProfiles.inl"
test "$(wc -l < "$scratch/FleetProfiles.inl")" -eq "$(("${#ships[@]}" + 1))"
cp "$scratch/FleetProfiles.inl" "$project/Source/StarflightUE/Private/GraphicsEngine/FleetProfiles.inl"
