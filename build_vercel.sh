#!/bin/sh
# Build Flutter Web para deploy na Vercel.
# As variáveis SUPABASE_URL e SUPABASE_ANON_KEY devem estar definidas no ambiente
# (no painel da Vercel: Settings > Environment Variables).

set -e
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Saída em build/web (configurar "Output Directory" = build/web na Vercel)
