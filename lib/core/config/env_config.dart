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

  /// Chave da API Google Maps (Web: configurar também no web/index.html).
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// URL pública do app (usada no link do e-mail de convite para assessores).
  /// Em produção use --dart-define=APP_URL=https://seu-dominio.vercel.app
  static const String appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://web-liart-iota-22.vercel.app',
  );
}
