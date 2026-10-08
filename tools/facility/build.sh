#!/usr/bin/env bash
# Concatenate src/*.luau (in order) into tools/FacilityBuilder.luau
set -euo pipefail
cd "$(dirname "$0")"
out=../FacilityBuilder.luau
: > "$out"
for f in src/*.luau; do cat "$f" >> "$out"; echo >> "$out"; done
echo "wrote $out ($(wc -l < "$out") lines)"
