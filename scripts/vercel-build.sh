#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/flutter/bin:$PATH"
export FLUTTER_ROOT="$ROOT/flutter"

# Variáveis Vercel → compiladas no bundle (ver lib/core/config/env_config.dart)
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo ">>> AVISO: SUPABASE_URL ou SUPABASE_ANON_KEY vazias. Define-as em Settings → Environment Variables (Production)."
fi

echo ">>> build web --release (dart-define a partir do ambiente Vercel)..."
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}" \
  --dart-define=APP_URL="${APP_URL:-}"
