#!/usr/bin/env bash
# Roda na Vercel (Linux). Não use PowerShell localmente para isto — o deploy real é na cloud.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/flutter/bin:$PATH"

if [[ ! -x "$ROOT/flutter/bin/flutter" ]]; then
  echo ">>> Clonando Flutter (stable, shallow)..."
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

echo ">>> Flutter doctor (web)..."
flutter config --enable-web --no-analytics
flutter precache --web --no-android --no-ios

echo ">>> pub get..."
flutter pub get
