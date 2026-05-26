#!/usr/bin/env bash
set -euo pipefail

ROOT_SKILLS="skills"
PLUGIN_SKILLS="plugins/runes/skills"

if [[ ! -d "$ROOT_SKILLS" ]]; then
  echo "Missing root skills directory: $ROOT_SKILLS" >&2
  exit 1
fi

if [[ ! -d "$PLUGIN_SKILLS" ]]; then
  echo "Missing plugin skills directory: $PLUGIN_SKILLS" >&2
  exit 1
fi

diff -ruN "$ROOT_SKILLS" "$PLUGIN_SKILLS"
