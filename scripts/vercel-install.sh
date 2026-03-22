#!/usr/bin/env bash
# Roda na Vercel (Linux). Não use PowerShell localmente para isto — o deploy real é na cloud.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/flutter/bin:$PATH"
export FLUTTER_ROOT="$ROOT/flutter"

if [[ ! -x "$ROOT/flutter/bin/flutter" ]]; then
  echo ">>> Clonando Flutter (branch stable, histórico completo)..."
  echo ">>> Nota: --depth 1 faz o SDK aparecer como 0.0.0-unknown e o pub falha."
  rm -rf flutter
  # Sem --depth: o Flutter precisa de tags/commits para reportar versão (ex.: >=3.10 para flutter_map).
  git clone https://github.com/flutter/flutter.git -b stable
fi

echo ">>> Versão do SDK:"
flutter --version

echo ">>> Config web..."
flutter config --enable-web --no-analytics
flutter precache --web --no-android --no-ios

echo ">>> pub get..."
flutter pub get
