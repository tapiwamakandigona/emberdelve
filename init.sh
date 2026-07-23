#!/usr/bin/env bash
# init.sh — bring the Emberdelve dev environment up from cold and prove it works.
# Safe to re-run. Requires: bash, curl. Installs lua5.4 via apt if missing (needs sudo).
set -euo pipefail
cd "$(dirname "$0")"

echo "== Emberdelve init =="

# 1. Lua for the headless sim test suite
if ! command -v lua5.4 >/dev/null 2>&1; then
  echo "-- installing lua5.4"
  sudo apt-get update -q && sudo apt-get install -y -q lua5.4
fi

# 2. Run the sim test suite (the real health check)
echo "-- running sim tests"
lua5.4 tests/run_tests.lua

# 3. Optional: local engine build needs bob.jar + OpenJDK 25.
#    CI does this automatically (.github/workflows/ci.yml). Locally:
DEFOLD_SHA1="f735c12192bf95684e6ae1ae27c400b8170fc6d8"
if command -v java >/dev/null 2>&1; then
  if [ ! -f bob.jar ]; then
    echo "-- downloading bob.jar (Defold ${DEFOLD_SHA1:0:8})"
    curl -sSL -o bob.jar "https://d.defold.com/archive/${DEFOLD_SHA1}/bob/bob.jar"
  fi
  java -jar bob.jar --version
  echo "-- to build:  java -jar bob.jar --archive --platform armv7-android --architectures armv7-android,arm64-android --variant debug --bundle-format apk --bundle-output dist/bundle resolve build bundle"
else
  echo "-- java not found: skipping engine build (sim tests are the gate; CI builds the APK)"
fi

echo "== init OK =="
