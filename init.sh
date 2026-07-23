#!/usr/bin/env bash
# init.sh — bring the Emberdelve (Flutter) dev environment up and prove it works.
# Safe to re-run. Requires: bash, curl, git. Installs Flutter locally if missing.
set -euo pipefail
cd "$(dirname "$0")"

echo "== Emberdelve init (Flutter) =="

FLUTTER_VERSION="3.32.7"

if ! command -v flutter >/dev/null 2>&1; then
  echo "-- flutter not on PATH."
  echo "   Install Flutter $FLUTTER_VERSION (stable) from https://docs.flutter.dev/get-started/install"
  echo "   or: git clone -b $FLUTTER_VERSION https://github.com/flutter/flutter.git and add flutter/bin to PATH."
  exit 1
fi

echo "-- flutter version"
flutter --version

echo "-- pub get"
flutter pub get

echo "-- analyze"
flutter analyze

echo "-- test (sim determinism, map properties, content, autoplay balance, UI smoke)"
flutter test

echo "-- balance stats (optional): dart run bin/autoplay.dart 200"
echo "== init OK =="
