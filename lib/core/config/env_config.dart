/// Configuração de variáveis de ambiente para Supabase.
/// Em produção (Vercel), use --dart-define na build para não expor chaves no código.
class EnvConfig {
  EnvConfig._();

  /// URL do projeto Supabase (ex.: https://xyz.supabase.co)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mjmqadpqcatwgskywisk.supabase.co',
  );

  /// Chave anon (pública) do Supabase para o cliente
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qbXFhZHBxY2F0d2dza3l3aXNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNDI4NDMsImV4cCI6MjA4NzgxODg0M30.0YTch1mkk0Ik_GVvE5oPKMxdYb6zRzBPcLnj_O-Uv2M',
  );

  /// Chave de API Google (tipicamente criada para **Places API** no Cloud Console).
  /// O app usa a **mesma** chave no Dart para: Places (Autocomplete, Details, Text Search) e
  /// **Geocoding API** (endereço ↔ coordenadas). Ative essas APIs no mesmo projeto/credencial.
  /// O `web/index.html` usa esta chave no script do **Maps JavaScript API**.
  /// Default alinhado ao HTML para `flutter run` web sem `--dart-define`.
  /// Produção: `--dart-define=GOOGLE_MAPS_API_KEY=...` (ex.: variável na Vercel).
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDgeOvier1TIBJJd3o0ElQoMiugqrnOrCI',
  );

  /// Chave ArcGIS (Location / basemap). Obrigatória no Android/iOS para o mapa nativo não falhar.
  /// Crie em https://developers.arcgis.com/ e passe na build:
  /// `flutter build apk --dart-define=ARCGIS_API_KEY=sua_chave`
  static const String arcgisApiKey = String.fromEnvironment(
    'ARCGIS_API_KEY',
    defaultValue: '',
  );

  /// Chave pública VAPID para Web Push (PWA).
  /// A chave privada fica somente nos Supabase Secrets (VAPID_PRIVATE_KEY).
  static const String vapidPublicKey = String.fromEnvironment(
    'VAPID_PUBLIC_KEY',
    defaultValue: 'BBDwFPKAU0cMMay9-WE1DadHmv_lFmGts80CaorhOl2zKW1HTSw4sQLpboixKQkerXexwYwJxSF4PcOK35Qa2DY',
  );

  /// URL pública do app (usada no link do e-mail de convite para assessores).
  /// Em produção use --dart-define=APP_URL=https://seu-dominio.vercel.app
  static const String appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://web-liart-iota-22.vercel.app',
  );

  /// Base sem barra final (redirects Supabase Auth).
  static String get supabaseRedirectOrigin =>
      appUrl.replaceAll(RegExp(r'/+$'), '');

  /// Web + hash router: onde o GoRouter deve abrir após o clique no e-mail de **reset**.
  /// Adiciona em Supabase → Authentication → URL Configuration → Redirect URLs.
  static String get webPasswordRecoveryRedirectTo =>
      '$supabaseRedirectOrigin/#/redefinir-senha';
}
