#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
LUAU=${LUAU:-/tmp/luau-bin}
../build.sh >/dev/null
tmp=$(mktemp /tmp/facility_test.XXXXXX.luau)
{ cat mock.luau; echo "local function BUILD()"; cat ../../FacilityBuilder.luau; echo "end"; echo "local META"; echo "FACILITY_TEST_HOOK = function(m) META = m end"; echo "local root = BUILD()"; for a in "$@"; do cat "$a"; done; } > "$tmp"
"$LUAU" "$tmp"
