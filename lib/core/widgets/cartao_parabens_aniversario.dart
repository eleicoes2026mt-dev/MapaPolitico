import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/profile.dart';
import '../../models/visita.dart';
import 'cartao_parabens_whatsapp_direct_stub.dart'
    if (dart.library.io) 'cartao_parabens_whatsapp_direct_io.dart';
import 'share_cartao_invite.dart';

/// Chave por pessoa + dia local — marca se o cartão já foi partilhado hoje.
class ParabensAniversarioPrefs {
  ParabensAniversarioPrefs._();

  static String key(Aniversariante a) {
    final n = DateTime.now();
    final day =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    return 'parabens_cartao_v1_${a.tipo}_${a.refId}_$day';
  }

  static Future<bool> jaEnviou(Aniversariante a) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(key(a)) ?? false;
  }

  static Future<void> marcarEnviado(Aniversariante a) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key(a), true);
  }
}

String legendaCompartilhamentoParabens({
  required String nomeAniversariante,
  required String nomeRemetente,
}) {
  final n = nomeAniversariante.trim();
  final d = nomeRemetente.trim();
  final assinatura = d.isEmpty ? 'Um abraço' : d;
  return 'Olá $n! Feliz aniversário! 🎂\n\n'
      'Quis te mandar este carinho hoje: que seu dia seja leve, com saúde e muita alegria ao seu redor. Estou pensando em você.\n\n'
      'Com carinho,\n$assinatura';
}

/// Gera PNG + abre partilha (ex.: WhatsApp) e marca [ParabensAniversarioPrefs] para hoje.
Future<bool> shareCartaoParabensAniversario(
  BuildContext context, {
  required Aniversariante aniversariante,
  required Profile deputado,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  late OverlayEntry entry;
  const w = 920.0;

  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 0,
      top: 0,
      width: w,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.01,
          child: Material(
            color: Colors.white,
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: w,
                child: _CartaoParabensExport(
                  aniversariante: aniversariante,
                  deputado: deputado,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final avatar = deputado.avatarUrl?.trim();
  if (avatar != null && avatar.isNotEmpty && context.mounted) {
    try {
      await precacheImage(NetworkImage(avatar), context);
    } catch (_) {}
  }

  overlay.insert(entry);
  try {
    Uint8List? out;
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!context.mounted) {
        return false;
      }
      final ctx = boundaryKey.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderRepaintBoundary) continue;
      try {
        final image = await ro.toImage(pixelRatio: 2.5);
        final bd = await image.toByteData(format: ui.ImageByteFormat.png);
        out = bd?.buffer.asUint8List();
        if (out != null && out.isNotEmpty) break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
    if (out == null || out.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar a imagem. Tente de novo.')),
        );
      }
      return false;
    }

    final nomeRemetente = deputado.fullName?.trim().isNotEmpty == true
        ? deputado.fullName!.trim()
        : '';
    final legenda = legendaCompartilhamentoParabens(
      nomeAniversariante: aniversariante.nome,
      nomeRemetente: nomeRemetente,
    );
    final safeName = aniversariante.nome
        .trim()
        .replaceAll(RegExp(r'[^\w\- ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'feliz_aniversario_${safeName.isEmpty ? 'aniversariante' : safeName}.png';

    final phoneDigits = aniversariante.telefoneWhatsappDigits;
    if (!kIsWeb && phoneDigits != null && phoneDigits.isNotEmpty) {
      final direct = await shareCartaoPngToWhatsappDirect(
        bytes: out,
        fileName: fileName,
        phoneDigits: phoneDigits,
      );
      if (direct == true) {
        await Clipboard.setData(ClipboardData(text: legenda));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'WhatsApp aberto com o contato. A mensagem foi copiada — cole no chat se quiser.',
              ),
            ),
          );
        }
        await ParabensAniversarioPrefs.marcarEnviado(aniversariante);
        return true;
      }
    }

    await shareInvitePngWithCaption(
      bytes: out,
      caption: legenda,
      fileName: fileName,
    );
    await ParabensAniversarioPrefs.marcarEnviado(aniversariante);
    return true;
  } finally {
    entry.remove();
  }
}

/// Layout estático para raster (alto contraste, tema claro).
class _CartaoParabensExport extends StatelessWidget {
  const _CartaoParabensExport({
    required this.aniversariante,
    required this.deputado,
  });

  final Aniversariante aniversariante;
  final Profile deputado;

  static const Color _navy = Color(0xFF0A2744);
  static const Color _navyLight = Color(0xFF1565C0);
  static const Color _textBody = Color(0xFF1A1D21);
  static const Color _accentBlue = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _accentBlue, brightness: Brightness.light),
    );
    final nomeRemetente = deputado.fullName?.trim().isNotEmpty == true
        ? deputado.fullName!.trim()
        : '';
    final hoje = DateTime.now();
    final dataFmt =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
    final url = deputado.avatarUrl?.trim();

    return Theme(
      data: theme,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navy, _navyLight],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.cake_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feliz aniversário!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Eu quis te mandar este cartão — como se eu estivesse aí para te dar um abraço e dizer parabéns.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontSize: 17,
                            height: 1.38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarExport(url: url),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeRemetente.isNotEmpty ? nomeRemetente : 'Com carinho',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: _accentBlue,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Este cartão vai direto de mim para você.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _textBody.withValues(alpha: 0.78),
                                fontSize: 15.5,
                                height: 1.35,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          _accentBlue.withValues(alpha: 0.25),
                          _navyLight.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Parabéns, ${aniversariante.nome.trim()}!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: _accentBlue,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hoje é o seu dia — e eu quis parar um instante só para te lembrar o quanto você merece ser celebrado. '
                    'Te desejo saúde, paz no coração, risos com quem você ama e um ano novo de vida repleto de coisas boas. '
                    'Estou na torcida por você, de verdade.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _textBody,
                      fontWeight: FontWeight.w500,
                      height: 1.52,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Com um grande abraço,',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _textBody.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nomeRemetente.isNotEmpty ? nomeRemetente : 'Com carinho',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _accentBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_rounded, size: 18, color: _navyLight.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        dataFmt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _textBody.withValues(alpha: 0.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarExport extends StatelessWidget {
  const _AvatarExport({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(size),
        ),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.person_rounded, size: 44, color: Color(0xFF1565C0)),
    );
  }
}
