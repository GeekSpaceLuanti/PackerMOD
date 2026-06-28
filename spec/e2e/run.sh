#!/usr/bin/env bash
# E2E runner: install PackerMOD into a throwaway $HOME, boot Luanti
# briefly with a dummy base game + smoke pack, and fail if the log
# contains Mod security or ERROR[Main] lines.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v luanti >/dev/null && ! command -v minetest >/dev/null; then
    echo "E2E SKIP: luanti binary not found" >&2
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp"
mkdir -p "$HOME/.minetest"

bash "$repo_root/install/install.sh" copy >/dev/null

mkdir -p "$HOME/.minetest/games/packerbase_0_91/mods"
cat > "$HOME/.minetest/games/packerbase_0_91/game.conf" <<'CONF'
title = E2E Dummy Base
name = E2E Dummy Base
description = Used by spec/e2e/run.sh; not for actual play.
CONF

mkdir -p "$HOME/.minetest/PackerMOD/packs/smoke"
cat > "$HOME/.minetest/PackerMOD/packs/smoke/manifest.yaml" <<'YAML'
schema_version: 1
id: smoke
name: E2E Smoke
version: "0.1.0"
base_game:
  id: packerbase
  version: "0.91"
YAML

log="$tmp/luanti.log"
runner="luanti"
command -v luanti >/dev/null || runner="minetest"

if [[ "${USE_XVFB:-}" == "1" ]] && command -v xvfb-run >/dev/null; then
    runner="xvfb-run -a $runner"
fi

# Boot just long enough to load the main menu script.
timeout 4 $runner --logfile "$log" >/dev/null 2>&1 || true

if [[ ! -s "$log" ]]; then
    echo "E2E FAIL: Luanti produced no log (display unavailable?)" >&2
    exit 1
fi

if grep -E "ERROR\[Main\]|Mod security" "$log" >/dev/null; then
    echo "E2E FAIL: Luanti reported errors:" >&2
    grep -E "ERROR\[Main\]|Mod security" "$log" >&2
    exit 1
fi

echo "E2E PASS: Luanti booted with PackerMOD mainmenu and dummy base game."
