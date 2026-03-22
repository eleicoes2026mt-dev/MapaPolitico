#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/flutter/bin:$PATH"
export FLUTTER_ROOT="$ROOT/flutter"

# Só passar --dart-define quando a variável está definida e não vazia.
# Se passares SUPABASE_URL= vazio, o Dart usa string vazia e IGNORA o defaultValue
# de env_config.dart → o cliente aponta para o domínio da Vercel e o login dá 405.
DEFS=()
[[ -n "${SUPABASE_URL:-}" ]] && DEFS+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
[[ -n "${SUPABASE_ANON_KEY:-}" ]] && DEFS+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
[[ -n "${GOOGLE_MAPS_API_KEY:-}" ]] && DEFS+=(--dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY")
[[ -n "${APP_URL:-}" ]] && DEFS+=(--dart-define=APP_URL="$APP_URL")

if [[ ${#DEFS[@]} -eq 0 ]]; then
  echo ">>> Nenhuma variável SUPABASE_*/APP_URL/GOOGLE_* no ambiente de build — a usar defaultValue de lib/core/config/env_config.dart."
else
  echo ">>> dart-define: ${#DEFS[@]} opção(ões) a partir do ambiente Vercel."
fi

echo ">>> build web --release..."
flutter build web --release "${DEFS[@]}"
