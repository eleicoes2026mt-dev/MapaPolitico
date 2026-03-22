#!/usr/bin/env bash
# Build Flutter Web (local ou referência). Na Vercel usa-se scripts/vercel-build.sh.
set -euo pipefail
flutter pub get
DEFS=()
[[ -n "${SUPABASE_URL:-}" ]] && DEFS+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
[[ -n "${SUPABASE_ANON_KEY:-}" ]] && DEFS+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
[[ -n "${GOOGLE_MAPS_API_KEY:-}" ]] && DEFS+=(--dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY")
[[ -n "${APP_URL:-}" ]] && DEFS+=(--dart-define=APP_URL="$APP_URL")
flutter build web --release "${DEFS[@]}"
