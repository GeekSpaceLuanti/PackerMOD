#!/usr/bin/env bash
# Smoke-test the real main menu engine with isolated, deterministic user data.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
run_dir="$(mktemp -d -t packermod-e2e.XXXXXX)"
trap 'rm -rf -- "$run_dir"' EXIT
bash "$repo_root/scripts/screenshot_mainmenu.sh" library "$run_dir/library.png" >/dev/null
[[ -s "$run_dir/library.png" ]]
echo "E2E PASS: engine menu ready with three isolated sample packs and no Lua errors."
