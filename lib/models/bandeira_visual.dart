import 'package:flutter/material.dart';

/// Lista fixa de emojis para escolha rápida (~100).
const List<String> kBandeiraEmojisOpcoes = [
  '⭐', '🔥', '💪', '❤️', '🎯', '🗳️', '✅', '🌟', '🇧🇷', '🤝', '👍', '🙏', '💚', '💛', '💙', '🧡', '⚡', '🎉', '🏆', '📣',
  '🌈', '☀️', '🌙', '⚽', '🎵', '📍', '🏠', '🌳', '🐦', '🦅', '🌾', '🚜', '🛣️', '🎓', '👨‍👩‍👧', '👥', '🧑‍🤝‍🧑', '💼', '🏛️', '📢',
  '✊', '🤲', '💯', '🎁', '🥇', '🥈', '🥉', '🎖️', '🏅', '🔔', '📌', '📎', '✏️', '📝', '📊', '📈', '💡', '🔑', '🛡️', '⚖️',
  '🕊️', '🌺', '🌻', '🌹', '🍀', '🌴', '🏞️', '🌄', '🌅', '🧭', '🗺️', '🎪', '🎭', '🎨', '🖌️', '🎬', '📷', '🎥', '📺', '📻',
  '🎸', '🥁', '🎺', '🎷', '🎻', '🎹', '🎤', '🎧', '📱', '💻', '⌚', '⏰', '📅', '🔋', '🔌', '💎', '👑', '🎩', '👔', '👗',
  '🧢', '👟', '🎒', '🧳', '🎈', '🎀', '🏁', '🚩', '🎌', '🏴', '🏳️', '🏳️‍🌈', '🔴', '🟠', '🟡', '🟢', '🔵', '🟣', '⚫', '⚪',
];

/// Como as duas cores preenchem o fundo do marcador.
enum BandeiraFundoLayout {
  solidPrimary,
  solidSecondary,
  splitLeftRight,
  splitTopBottom,
  gradientHorizontal,
  gradientVertical;

  String get storageValue => name;

  static BandeiraFundoLayout fromStorage(String? s) {
    if (s == null || s.isEmpty) return BandeiraFundoLayout.solidPrimary;
    for (final v in BandeiraFundoLayout.values) {
      if (v.name == s) return v;
    }
    return BandeiraFundoLayout.solidPrimary;
  }

  String get labelPt {
    switch (this) {
      case BandeiraFundoLayout.solidPrimary:
        return 'Só cor 1';
      case BandeiraFundoLayout.solidSecondary:
        return 'Só cor 2';
      case BandeiraFundoLayout.splitLeftRight:
        return 'Metade esquerda / direita';
      case BandeiraFundoLayout.splitTopBottom:
        return 'Metade cima / baixo';
      case BandeiraFundoLayout.gradientHorizontal:
        return 'Degradê ↔ (cor1 → cor2)';
      case BandeiraFundoLayout.gradientVertical:
        return 'Degradê ↕ (cor1 → cor2)';
    }
  }
}

/// Estilo das iniciais sobre o marcador.
@immutable
class BandeiraIniciaisEstilo {
  const BandeiraIniciaisEstilo({
    this.corLetraHex,
    this.negrito = true,
    this.bordaAtiva = false,
    this.bordaCorHex,
    this.bordaLargura = 1.0,
    this.sombraAtiva = false,
    this.sombraCorHex,
  });

  final String? corLetraHex;
  final bool negrito;
  final bool bordaAtiva;
  final String? bordaCorHex;
  final double bordaLargura;
  final bool sombraAtiva;
  final String? sombraCorHex;

  Map<String, dynamic> toJson() => {
        'cor_letra': corLetraHex,
        'negrito': negrito,
        'borda_ativa': bordaAtiva,
        'borda_cor': bordaCorHex,
        'borda_largura': bordaLargura,
        'sombra_ativa': sombraAtiva,
        'sombra_cor': sombraCorHex,
      };

  factory BandeiraIniciaisEstilo.fromJson(Map<String, dynamic>? m) {
    if (m == null) return const BandeiraIniciaisEstilo();
    return BandeiraIniciaisEstilo(
      corLetraHex: m['cor_letra'] as String?,
      negrito: m['negrito'] as bool? ?? true,
      bordaAtiva: m['borda_ativa'] as bool? ?? false,
      bordaCorHex: m['borda_cor'] as String?,
      bordaLargura: (m['borda_largura'] as num?)?.toDouble() ?? 1.0,
      sombraAtiva: m['sombra_ativa'] as bool? ?? false,
      sombraCorHex: m['sombra_cor'] as String?,
    );
  }

  BandeiraIniciaisEstilo copyWith({
    String? corLetraHex,
    bool? negrito,
    bool? bordaAtiva,
    String? bordaCorHex,
    double? bordaLargura,
    bool? sombraAtiva,
    String? sombraCorHex,
  }) {
    return BandeiraIniciaisEstilo(
      corLetraHex: corLetraHex ?? this.corLetraHex,
      negrito: negrito ?? this.negrito,
      bordaAtiva: bordaAtiva ?? this.bordaAtiva,
      bordaCorHex: bordaCorHex ?? this.bordaCorHex,
      bordaLargura: bordaLargura ?? this.bordaLargura,
      sombraAtiva: sombraAtiva ?? this.sombraAtiva,
      sombraCorHex: sombraCorHex ?? this.sombraCorHex,
    );
  }
}

@immutable
class BandeiraVisual {
  const BandeiraVisual({
    this.corPrimariaHex = '#1976D2',
    this.corSecundariaHex = '#FF6F00',
    this.layout = BandeiraFundoLayout.solidPrimary,
    this.emoji,
    this.iniciais,
    this.iniciaisEstilo = const BandeiraIniciaisEstilo(),
  });

  final String corPrimariaHex;
  final String corSecundariaHex;
  final BandeiraFundoLayout layout;
  final String? emoji;
  final String? iniciais;
  final BandeiraIniciaisEstilo iniciaisEstilo;

  Map<String, dynamic> toJson() => {
        'cor1': _normHex(corPrimariaHex),
        'cor2': _normHex(corSecundariaHex),
        'layout': layout.storageValue,
        'emoji': emoji,
        'iniciais': iniciais,
        'iniciais_estilo': iniciaisEstilo.toJson(),
      };

  factory BandeiraVisual.fromJson(dynamic raw) {
    if (raw is! Map) return const BandeiraVisual();
    final m = Map<String, dynamic>.from(raw);
    return BandeiraVisual(
      corPrimariaHex: _normHex(m['cor1'] as String? ?? '#1976D2'),
      corSecundariaHex: _normHex(m['cor2'] as String? ?? '#FF6F00'),
      layout: BandeiraFundoLayout.fromStorage(m['layout'] as String?),
      emoji: m['emoji'] as String?,
      iniciais: m['iniciais'] as String?,
      iniciaisEstilo: BandeiraIniciaisEstilo.fromJson(
        m['iniciais_estilo'] is Map ? Map<String, dynamic>.from(m['iniciais_estilo'] as Map) : null,
      ),
    );
  }

  /// A partir dos campos legados da tabela `apoiadores`.
  BandeiraVisual copyWith({
    String? corPrimariaHex,
    String? corSecundariaHex,
    BandeiraFundoLayout? layout,
    String? emoji,
    String? iniciais,
    BandeiraIniciaisEstilo? iniciaisEstilo,
  }) {
    return BandeiraVisual(
      corPrimariaHex: corPrimariaHex ?? this.corPrimariaHex,
      corSecundariaHex: corSecundariaHex ?? this.corSecundariaHex,
      layout: layout ?? this.layout,
      emoji: emoji ?? this.emoji,
      iniciais: iniciais ?? this.iniciais,
      iniciaisEstilo: iniciaisEstilo ?? this.iniciaisEstilo,
    );
  }

  factory BandeiraVisual.fromLegacy({
    String? bandeiraIniciais,
    String? bandeiraCorPrimaria,
    String? bandeiraCorSecundaria,
    String? bandeiraEmoji,
  }) {
    return BandeiraVisual(
      corPrimariaHex: _normHex(bandeiraCorPrimaria ?? '#2E7D32'),
      corSecundariaHex: _normHex(bandeiraCorSecundaria ?? '#FF6F00'),
      layout: BandeiraFundoLayout.solidPrimary,
      emoji: bandeiraEmoji,
      iniciais: bandeiraIniciais,
      iniciaisEstilo: BandeiraIniciaisEstilo(
        corLetraHex: '#FFFFFF',
        negrito: true,
      ),
    );
  }

  // ── Presets do mapa (cores fixas por tipo; não dependem do editor do apoiador) ──

  /// Apoiador na cidade — verde.
  factory BandeiraVisual.mapaApoiador() {
    return const BandeiraVisual(
      corPrimariaHex: '#2E7D32',
      corSecundariaHex: '#1B5E20',
      layout: BandeiraFundoLayout.solidPrimary,
      emoji: '🚩',
      iniciaisEstilo: BandeiraIniciaisEstilo(corLetraHex: '#FFFFFF', negrito: true),
    );
  }

  /// Assessor na cidade — roxo.
  factory BandeiraVisual.mapaAssessor() {
    return const BandeiraVisual(
      corPrimariaHex: '#6A1B9A',
      corSecundariaHex: '#4A148C',
      layout: BandeiraFundoLayout.solidPrimary,
      emoji: '🚩',
      iniciaisEstilo: BandeiraIniciaisEstilo(corLetraHex: '#FFFFFF', negrito: true),
    );
  }

  /// Amigos do Gilberto cadastrados por apoiador — verde + azul.
  factory BandeiraVisual.mapaAmigoPorApoiador() {
    return const BandeiraVisual(
      corPrimariaHex: '#2E7D32',
      corSecundariaHex: '#1565C0',
      layout: BandeiraFundoLayout.gradientHorizontal,
      emoji: '🚩',
      iniciaisEstilo: BandeiraIniciaisEstilo(corLetraHex: '#FFFFFF', negrito: true),
    );
  }

  /// Amigos do Gilberto cadastrados por assessor (sem apoiador) — roxo + azul.
  factory BandeiraVisual.mapaAmigoPorAssessor() {
    return const BandeiraVisual(
      corPrimariaHex: '#6A1B9A',
      corSecundariaHex: '#1565C0',
      layout: BandeiraFundoLayout.gradientHorizontal,
      emoji: '🚩',
      iniciaisEstilo: BandeiraIniciaisEstilo(corLetraHex: '#FFFFFF', negrito: true),
    );
  }

  /// Amigos do Gilberto cadastrados pelo candidato — azul.
  factory BandeiraVisual.mapaAmigoCandidato() {
    return const BandeiraVisual(
      corPrimariaHex: '#1565C0',
      corSecundariaHex: '#0D47A1',
      layout: BandeiraFundoLayout.solidPrimary,
      emoji: '🚩',
      iniciaisEstilo: BandeiraIniciaisEstilo(corLetraHex: '#FFFFFF', negrito: true),
    );
  }

  /// Cadastro via QR — laranja.
  factory BandeiraVisual.mapaCadastroQr() {
    return const BandeiraVisual(
      corPrimariaHex: '#EF6C00',
      corSecundariaHex: '#E65100',
      layout: BandeiraFundoLayout.solidPrimary,
      emoji: '🚩',
      iniciaisEstilo: BandeiraIniciaisEstilo(corLetraHex: '#FFFFFF', negrito: true),
    );
  }

  static String _normHex(String? h) {
    if (h == null || h.isEmpty) return '#1976D2';
    final t = h.trim();
    if (t.startsWith('#')) {
      if (t.length == 7 || t.length == 9) return t;
      return '#${t.substring(1)}'.length == 7 ? '#${t.substring(1)}' : '#1976D2';
    }
    if (t.length == 6) return '#$t';
    return '#1976D2';
  }
}

/// Converte [Color] em `#RRGGBB` maiúsculo.
String corParaHexRgb(Color c) {
  int ch(double x) => (x * 255.0).round().clamp(0, 255);
  return '#${ch(c.r).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.g).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.b).toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

Color corDeHex(String? hex, [Color fallback = Colors.blueGrey]) {
  final h = BandeiraVisual._normHex(hex);
  final s = h.replaceFirst('#', '');
  if (s.length == 6) {
    return Color(int.parse('FF$s', radix: 16));
  }
  if (s.length == 8) {
    return Color(int.parse(s, radix: 16));
  }
  return fallback;
}

extension BandeiraVisualMapaX on BandeiraVisual {
  /// Cor única para APIs que não desenham o layout completo (ex.: ArcGIS).
  Color get corDominanteMapa {
    switch (layout) {
      case BandeiraFundoLayout.solidSecondary:
        return corDeHex(corSecundariaHex);
      default:
        return corDeHex(corPrimariaHex);
    }
  }
}
