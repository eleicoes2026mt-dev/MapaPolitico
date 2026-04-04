import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env_config.dart';
import '../constants/amigos_gilberto.dart';
import 'share_cartao_invite.dart';

/// URL pública de cadastro com `?ref=<uuid do perfil convidador>` para rastrear a rede.
String urlCadastroAmigosGilberto({String? convitePorProfileId}) {
  final base = EnvConfig.supabaseRedirectOrigin;
  final id = convitePorProfileId?.trim();
  if (id == null || id.isEmpty) return '$base/cadastro-amigos';
  return '$base/cadastro-amigos?${Uri(queryParameters: {'ref': id}).query}';
}

/// Texto do convite sem o URL (para legenda após a imagem: primeiro o cartão, depois texto + link).
String _mensagemConviteSemUrl({required String inviterLabel}) {
  final n = inviterLabel.trim();
  if (n.isEmpty) {
    return 'Cadastre-se nos $kAmigosGilbertoLabel. O link de cadastro está logo abaixo.';
  }
  return '$n convida você a participar da campanha. Use o link de cadastro abaixo.';
}

String _legendaCompartilhamentoComLink({required String url, required String inviterLabel}) {
  return '${_mensagemConviteSemUrl(inviterLabel: inviterLabel)}\n\n$url';
}

/// QR ampliado em ecrã preto (a partir do cartão já em tela cheia).
void _showQrFullscreenOnly(BuildContext context, String url) {
  final mq = MediaQuery.of(context);
  final pad = MediaQuery.paddingOf(context);
  final maxSide = math.min(
    mq.size.width - 32,
    mq.size.height - pad.vertical - kToolbarHeight - 24,
  );
  final side = (maxSide * 0.88).clamp(180.0, 560.0);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Código QR'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: url,
              size: side,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0D1117),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0D1117),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// QR e link amarrados ao perfil logado ([inviterProfileId]) para rede de convites.
void showAmigosGilbertoQrDialog(
  BuildContext context, {
  required String inviterProfileId,
  String? inviterDisplayName,
  String? candidatePhotoUrl,
  String? candidateName,
}) {
  final url = urlCadastroAmigosGilberto(convitePorProfileId: inviterProfileId);
  final nomeCartao = (candidateName != null && candidateName.trim().isNotEmpty)
      ? candidateName.trim()
      : (inviterDisplayName != null && inviterDisplayName.trim().isNotEmpty)
          ? inviterDisplayName.trim()
          : null;
  final labelConvite = inviterDisplayName?.trim().isNotEmpty == true
      ? inviterDisplayName!.trim()
      : (nomeCartao ?? '');
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _ConviteFullscreenPage(
        url: url,
        candidatePhotoUrl: candidatePhotoUrl,
        candidateName: nomeCartao,
        inviterSubtitle: labelConvite.isNotEmpty ? labelConvite : null,
        inviterLabelForShare: labelConvite,
      ),
    ),
  );
}

/// Cartão estático (sem animação no QR) para captura PNG / impressão.
class _ExportCaptureCard extends StatelessWidget {
  const _ExportCaptureCard({
    required this.url,
    this.candidatePhotoUrl,
    this.candidateName,
    this.inviterSubtitle,
  });

  final String url;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;

  static const Color _bodyText = Color(0xFF37474F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderBar(
          onClose: () {},
          inviterSubtitle: inviterSubtitle,
          showCloseButton: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CandidatePhotoBlock(
                      imageUrl: candidatePhotoUrl,
                      name: candidateName,
                      maxWidth: 360,
                      nameStyle: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _bodyText,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a informações da campanha, mensagens, reuniões e agenda.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _bodyText,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _QrCardStatic(url: url, size: 300),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LinkBlock(url: url, theme: theme, emphasize: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrCardStatic extends StatelessWidget {
  const _QrCardStatic({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D1117).withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: url,
        size: size,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0D1117),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0D1117),
        ),
      ),
    );
  }
}

BoxDecoration _conviteFullscreenCardDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    color: Colors.white,
    border: Border.all(color: const Color(0xFFE0E7EF)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _ConviteFullscreenPage extends StatefulWidget {
  const _ConviteFullscreenPage({
    required this.url,
    this.candidatePhotoUrl,
    this.candidateName,
    this.inviterSubtitle,
    required this.inviterLabelForShare,
  });

  final String url;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;
  final String inviterLabelForShare;

  @override
  State<_ConviteFullscreenPage> createState() => _ConviteFullscreenPageState();
}

class _ConviteFullscreenPageState extends State<_ConviteFullscreenPage> {
  static const Color _bgTop = Color(0xFF0A1628);
  static const Color _bgBottom = Color(0xFF0D3D5C);

  final GlobalKey _exportKey = GlobalKey();
  bool _exportBusy = false;

  String get _inviterLabelForShare => widget.inviterLabelForShare;

  /// Captura o cartão em PNG (overlay invisível — necessário para pintura estável na web).
  Future<Uint8List?> _captureCartaoPng({double pixelRatio = 2.5}) async {
    if (!mounted) return null;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 0,
        top: 0,
        width: 1100,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: Material(
              color: Colors.white,
              child: RepaintBoundary(
                key: _exportKey,
                child: SizedBox(
                  width: 1100,
                  child: _ExportCaptureCard(
                    url: widget.url,
                    candidatePhotoUrl: widget.candidatePhotoUrl,
                    candidateName: widget.candidateName,
                    inviterSubtitle: widget.inviterSubtitle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
        await SchedulerBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (!mounted) return null;
        final ctx = _exportKey.currentContext;
        if (ctx == null || !ctx.mounted) continue;
        final ro = ctx.findRenderObject();
        if (ro is! RenderRepaintBoundary) continue;
        try {
          final image = await ro.toImage(pixelRatio: pixelRatio);
          final bd = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = bd?.buffer.asUint8List();
          if (out != null && out.isNotEmpty) return out;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
      }
      return null;
    } finally {
      entry.remove();
    }
  }

  Future<void> _shareImageAndLink() async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final bytes = await _captureCartaoPng();
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar a imagem do cartão. Tente de novo.')),
        );
        return;
      }
      final caption = _legendaCompartilhamentoComLink(
        url: widget.url,
        inviterLabel: _inviterLabelForShare,
      );
      await shareInvitePngWithCaption(
        bytes: bytes,
        caption: caption,
        fileName: 'convite_amigos_gilberto.png',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compartilhamento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link de cadastro copiado.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2137),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Conexão com a campanha',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.4,
                  ),
            ),
            Text(
              'Cartão de convite',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_exportBusy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Copiar link de cadastro',
            onPressed: _exportBusy ? null : _copyLink,
            icon: const Icon(Icons.link_rounded),
          ),
          IconButton(
            tooltip: 'Compartilhar cartão e link',
            onPressed: _exportBusy ? null : _shareImageAndLink,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final maxH = constraints.maxHeight;
              final isWide = maxW >= 800;
              final hPad = maxW >= 1400
                  ? 48.0
                  : maxW >= 1000
                      ? 32.0
                      : maxW >= 600
                          ? 20.0
                          : 12.0;
              const vPad = 10.0;
              final innerW = (maxW - 2 * hPad).clamp(280.0, double.infinity);
              final cardViewportH = math.max(0.0, maxH - 2 * vPad);

              void onQrTap() => _showQrFullscreenOnly(context, widget.url);

              if (!isWide) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad + 8),
                  child: DecoratedBox(
                    decoration: _conviteFullscreenCardDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: _NarrowBody(
                        url: widget.url,
                        candidatePhotoUrl: widget.candidatePhotoUrl,
                        candidateName: widget.candidateName,
                        inviterSubtitle: widget.inviterSubtitle,
                        screenW: screenW,
                        layoutWidth: innerW,
                        isFullscreen: true,
                        onQrTap: onQrTap,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
                child: DecoratedBox(
                  decoration: _conviteFullscreenCardDecoration(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: cardViewportH,
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.inviterSubtitle != null &&
                              widget.inviterSubtitle!.trim().isNotEmpty) ...[
                            _ConviteInviteBanner(text: widget.inviterSubtitle!.trim()),
                          ],
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                widget.inviterSubtitle != null &&
                                        widget.inviterSubtitle!.trim().isNotEmpty
                                    ? 8
                                    : 20,
                                24,
                                20,
                              ),
                              child: _WideBody(
                                url: widget.url,
                                candidatePhotoUrl: widget.candidatePhotoUrl,
                                candidateName: widget.candidateName,
                                inviterSubtitle: widget.inviterSubtitle,
                                screenW: screenW,
                                layoutWidth: innerW,
                                isFullscreen: true,
                                fullscreenDesktopSplit: true,
                                onQrTap: onQrTap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConviteInviteBanner extends StatelessWidget {
  const _ConviteInviteBanner({required this.text});

  final String text;
  static const Color _fsBlue = Color(0xFF0D47A1);
  static const Color _fsBlueMid = Color(0xFF0277BD);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFFE8F4FC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
        child: Row(
          children: [
            Icon(Icons.waving_hand_rounded, color: _fsBlueMid, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Convite de $text',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _fsBlue,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.onClose,
    this.inviterSubtitle,
    this.showCloseButton = true,
  });

  final VoidCallback onClose;
  final String? inviterSubtitle;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 10, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            Color.lerp(cs.primary, cs.tertiary, 0.35)!,
          ],
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
            child: Icon(
              Icons.groups_2_rounded,
              size: 34,
              color: cs.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conexão com a campanha',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.9),
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Junte-se aos $kAmigosGilbertoLabel',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                if (inviterSubtitle != null && inviterSubtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Convite de ${inviterSubtitle!.trim()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.92),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showCloseButton)
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: cs.onPrimary),
              tooltip: 'Fechar',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cartão em duas colunas (PC / tela larga): preenche a largura e faz scroll por coluna se precisar.
class _WideBody extends StatelessWidget {
  const _WideBody({
    required this.url,
    required this.screenW,
    this.candidatePhotoUrl,
    this.candidateName,
    this.inviterSubtitle,
    this.isFullscreen = false,
    this.layoutWidth,
    this.fullscreenDesktopSplit = false,
    this.onQrTap,
  });

  final String url;
  final double screenW;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;
  final bool isFullscreen;
  final double? layoutWidth;
  final bool fullscreenDesktopSplit;
  final VoidCallback? onQrTap;

  static const Color _fsBlue = Color(0xFF0D47A1);
  static const Color _fsBlueMid = Color(0xFF0277BD);
  static const Color _captionStrong = Color(0xFF263238);
  static const Color _captionMuted = Color(0xFF37474F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fs = isFullscreen;
    final lw = layoutWidth ?? screenW;

    if (fullscreenDesktopSplit && fs) {
      final qrSize = math.min(340.0, math.max(210.0, lw * 0.17));
      final photoMax = math.min(340.0, math.max(220.0, lw * 0.23));

      final nameStyle = theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: lw >= 1100 ? 24 : 22,
        color: _fsBlue,
        height: 1.2,
      );

      final taglineStyle = theme.textTheme.bodyLarge?.copyWith(
        fontSize: lw >= 1100 ? 18.5 : 17.5,
        height: 1.5,
        color: _captionStrong,
        fontWeight: FontWeight.w600,
      );

      final benefitsTitle = theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: lw >= 1100 ? 19.5 : 18.5,
        color: _fsBlue,
        height: 1.35,
      );

      final scanLabel = theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        fontSize: 16.5,
        color: _fsBlueMid,
      );

      final footerStyle = theme.textTheme.bodySmall?.copyWith(
        fontSize: 13.5,
        color: _captionMuted,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 42,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CandidatePhotoBlock(
                    imageUrl: candidatePhotoUrl,
                    name: candidateName,
                    maxWidth: photoMax,
                    nameStyle: nameStyle,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
                    style: taglineStyle,
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 58,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a:',
                    style: benefitsTitle,
                  ),
                  const SizedBox(height: 14),
                  _benefitsTwoByTwo(context, dense: false),
                  const SizedBox(height: 18),
                  Text(
                    'Escaneie o código ou compartilhe o link de cadastro',
                    textAlign: TextAlign.right,
                    style: scanLabel,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _QrCard(
                      url: url,
                      size: qrSize,
                      onTap: onQrTap,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LinkBlock(url: url, theme: theme, emphasize: true),
                  const SizedBox(height: 10),
                  Text(
                    'O cadastro exige e-mail para acesso seguro ao painel.',
                    textAlign: TextAlign.center,
                    style: footerStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final qrSize = fs
        ? math.min(288.0, math.max(220.0, screenW * 0.26))
        : (screenW < 900 ? 220.0 : 260.0);

    final nameStyle = fs
        ? theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: _fsBlue,
            height: 1.2,
          )
        : theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: _fsBlue,
          );

    final taglineStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: fs ? 17.5 : 17,
      height: 1.5,
      color: fs ? _captionStrong : _captionMuted,
      fontWeight: fs ? FontWeight.w600 : FontWeight.w700,
    );

    final benefitsTitle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: fs ? 18.5 : 17,
      color: _fsBlue,
      height: 1.35,
    );

    final scanLabel = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
      fontSize: fs ? 16.5 : 16,
      color: _fsBlueMid,
    );

    final footerStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: fs ? 13.5 : 13.5,
      color: _captionMuted,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
    );

    final mainRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: fs ? 42 : 38,
          child: Column(
            crossAxisAlignment: fs ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              _CandidatePhotoBlock(
                imageUrl: candidatePhotoUrl,
                name: candidateName,
                maxWidth: fs ? 280 : 300,
                nameStyle: nameStyle,
              ),
              SizedBox(height: fs ? 18 : 18),
              Text(
                'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
                style: taglineStyle,
                textAlign: fs ? TextAlign.left : TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(width: fs ? 24 : 24),
        Expanded(
          flex: fs ? 58 : 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a:',
                style: benefitsTitle,
              ),
              SizedBox(height: fs ? 16 : 14),
              _benefitsTwoByTwo(context, dense: !fs),
              SizedBox(height: fs ? 20 : 20),
              Text(
                'Escaneie o código ou compartilhe o link de cadastro',
                textAlign: TextAlign.right,
                style: scanLabel,
              ),
              SizedBox(height: fs ? 12 : 12),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _QrCard(
                    url: url,
                    size: qrSize,
                    onTap: onQrTap,
                  ),
                ),
              ),
              SizedBox(height: fs ? 16 : 14),
              _LinkBlock(url: url, theme: theme, emphasize: true),
              SizedBox(height: fs ? 12 : 6),
              Text(
                'O cadastro exige e-mail para acesso seguro ao painel.',
                textAlign: TextAlign.center,
                style: footerStyle,
              ),
            ],
          ),
        ),
      ],
    );

    final inv = inviterSubtitle?.trim();
    if (fs && inv != null && inv.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFFE8F4FC),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.waving_hand_rounded, color: _fsBlueMid, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Convite de $inv',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _fsBlue,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: fs ? 20 : 0),
          mainRow,
        ],
      );
    }

    return mainRow;
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody({
    required this.url,
    required this.screenW,
    this.candidatePhotoUrl,
    this.candidateName,
    this.inviterSubtitle,
    this.isFullscreen = false,
    this.layoutWidth,
    this.onQrTap,
  });

  final String url;
  final double screenW;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;
  final bool isFullscreen;
  final double? layoutWidth;
  final VoidCallback? onQrTap;

  static const Color _fsBlue = Color(0xFF0D47A1);
  static const Color _fsBlueMid = Color(0xFF0277BD);
  static const Color _captionStrong = Color(0xFF263238);
  static const Color _captionMuted = Color(0xFF37474F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fs = isFullscreen;
    final w = layoutWidth ?? screenW;
    final qrSize = fs
        ? math.min(300.0, math.max(215.0, w * 0.72))
        : (screenW < 400 ? 220.0 : 248.0);

    final nameStyle = fs
        ? theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            color: _fsBlue,
            height: 1.2,
          )
        : theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: _fsBlue,
          );

    final taglineStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: fs ? 16.5 : 16,
      height: 1.5,
      color: _captionStrong,
      fontWeight: FontWeight.w600,
    );

    final benefitsTitle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: fs ? 17.5 : 16.5,
      color: _fsBlue,
    );

    final scanLabel = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
      fontSize: fs ? 15.5 : 15,
      color: _fsBlueMid,
    );

    final footerStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: fs ? 13 : 12.5,
      color: _captionMuted,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
    );

    final inv = inviterSubtitle?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fs && inv != null && inv.isNotEmpty) ...[
          Material(
            color: const Color(0xFFE8F4FC),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.waving_hand_rounded, color: _fsBlueMid, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Convite de $inv',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _fsBlue,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Center(
          child: _CandidatePhotoBlock(
            imageUrl: candidatePhotoUrl,
            name: candidateName,
            maxWidth: fs ? 268 : 260,
            nameStyle: nameStyle,
          ),
        ),
        SizedBox(height: fs ? 22 : 18),
        Text(
          'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
          style: taglineStyle,
        ),
        SizedBox(height: fs ? 22 : 18),
        Text(
          'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a:',
          style: benefitsTitle,
        ),
        SizedBox(height: fs ? 14 : 12),
        _BenefitTile(
          icon: Icons.campaign_outlined,
          title: 'Informações da campanha',
          subtitle: 'Atualizações e comunicados oficiais.',
          compact: !fs,
        ),
        _BenefitTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Mensagens da campanha',
          subtitle: 'Conteúdos enviados à rede de apoio.',
          compact: !fs,
        ),
        _BenefitTile(
          icon: Icons.event_available_outlined,
          title: 'Reuniões e encontros',
          subtitle: 'Convites e avisos sobre encontros em polos e cidades.',
          compact: !fs,
        ),
        _BenefitTile(
          icon: Icons.calendar_month_outlined,
          title: 'Agenda e ações',
          subtitle: 'Datas e mobilizações para não perder nada.',
          compact: !fs,
        ),
        SizedBox(height: fs ? 24 : 20),
        Text(
          'Escaneie o código ou compartilhe o link de cadastro',
          textAlign: TextAlign.center,
          style: scanLabel,
        ),
        SizedBox(height: fs ? 18 : 14),
        Center(
          child: _QrCard(
            url: url,
            size: qrSize,
            onTap: onQrTap,
          ),
        ),
        SizedBox(height: fs ? 18 : 14),
        _LinkBlock(url: url, theme: theme, emphasize: true),
        SizedBox(height: fs ? 10 : 8),
        Text(
          'O cadastro exige e-mail para acesso seguro ao painel.',
          textAlign: TextAlign.center,
          style: footerStyle,
        ),
      ],
    );
  }
}

Widget _benefitsTwoByTwo(BuildContext context, {bool dense = true}) {
  return Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BenefitTile(
              icon: Icons.campaign_outlined,
              title: 'Informações da campanha',
              subtitle: 'Atualizações e comunicados oficiais.',
              compact: dense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BenefitTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Mensagens da campanha',
              subtitle: 'Conteúdos enviados à rede de apoio.',
              compact: dense,
            ),
          ),
        ],
      ),
      SizedBox(height: dense ? 10 : 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BenefitTile(
              icon: Icons.event_available_outlined,
              title: 'Reuniões e encontros',
              subtitle: 'Convites e avisos em polos e cidades.',
              compact: dense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BenefitTile(
              icon: Icons.calendar_month_outlined,
              title: 'Agenda e ações',
              subtitle: 'Datas e mobilizações.',
              compact: dense,
            ),
          ),
        ],
      ),
    ],
  );
}

class _CandidatePhotoBlock extends StatelessWidget {
  const _CandidatePhotoBlock({
    this.imageUrl,
    this.name,
    required this.maxWidth,
    this.nameStyle,
  });

  final String? imageUrl;
  final String? name;
  final double maxWidth;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final url = imageUrl?.trim();

    Widget image;
    if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _photoPlaceholder(cs),
      );
    } else {
      image = _photoPlaceholder(cs);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            elevation: 4,
            shadowColor: Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 1,
              child: image,
            ),
          ),
        ),
        if (name != null && name!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            name!.trim(),
            style: nameStyle ??
                theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _photoPlaceholder(ColorScheme cs) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 72,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// QR com anel animado (gradiente azul/ciano rotativo) por trás do cartão branco.
class _QrCard extends StatefulWidget {
  const _QrCard({
    required this.url,
    required this.size,
    this.onTap,
  });

  final String url;
  final double size;
  final VoidCallback? onTap;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> with SingleTickerProviderStateMixin {
  static const double _ring = 4;
  static const double _innerPad = 18;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.size + 2 * _innerPad + 2 * _ring;

    Widget core = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0x5500B4FF),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: total,
        height: total,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Anel: gradiente em arco que gira (faixa azul/ciano brilhante no contorno)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: RotationTransition(
                turns: _controller,
                child: Container(
                  width: total,
                  height: total,
                  decoration: const BoxDecoration(
                    gradient: SweepGradient(
                      center: Alignment.center,
                      startAngle: 0,
                      endAngle: 6.2831853,
                      colors: [
                        Color(0xFF051923),
                        Color(0xFF0277BD),
                        Color(0xFF00B0FF),
                        Color(0xFF64FFFF),
                        Color(0xFF00E5FF),
                        Color(0xFF00B0FF),
                        Color(0xFF0277BD),
                        Color(0xFF051923),
                      ],
                      stops: [0.0, 0.1, 0.22, 0.36, 0.5, 0.64, 0.78, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Cartão branco por cima (só o anel _ring mostra o gradiente)
            Container(
              margin: const EdgeInsets.all(_ring),
              padding: const EdgeInsets.all(_innerPad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: widget.url,
                size: widget.size,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D1117),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D1117),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final tap = widget.onTap;
    if (tap != null) {
      core = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: 'Abrir em tela cheia',
          child: Semantics(
            button: true,
            label: 'Abrir em tela cheia',
            child: GestureDetector(
              onTap: tap,
              behavior: HitTestBehavior.opaque,
              child: core,
            ),
          ),
        ),
      );
    }
    return core;
  }
}

class _LinkBlock extends StatelessWidget {
  const _LinkBlock({
    required this.url,
    required this.theme,
    this.emphasize = false,
  });

  final String url;
  final ThemeData theme;
  final bool emphasize;

  static const Color _linkBg = Color(0xFFE3F2FD);
  static const Color _linkText = Color(0xFF0D47A1);
  static const Color _linkAccent = Color(0xFF0277BD);

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link inválido.')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = emphasize ? 14.0 : 11.0;
    final iconSize = emphasize ? 22.0 : 18.0;

    return Material(
      color: _linkBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _linkAccent.withValues(alpha: 0.45),
        ),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: emphasize ? 14 : 12,
            vertical: emphasize ? 12 : 10,
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: iconSize, color: _linkAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: fontSize,
                    height: 1.35,
                    color: _linkText,
                    fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: _linkAccent.withValues(alpha: 0.75),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: 'Abrir no navegador',
                child: Icon(
                  Icons.open_in_new_rounded,
                  size: emphasize ? 20 : 18,
                  color: _linkAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  static const Color _titleColor = Color(0xFF0D47A1);
  static const Color _subtitleColor = Color(0xFF37474F);
  static const Color _iconBg = Color(0xFFE3F2FD);
  static const Color _iconFg = Color(0xFF0277BD);

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact ? 8.0 : 8.0;
    final iconBox = compact ? 38.0 : 44.0;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            padding: EdgeInsets.all(pad * 0.5),
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: compact ? 21 : 24, color: _iconFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : 15,
                    color: _titleColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _subtitleColor,
                    height: 1.35,
                    fontSize: compact ? 11.5 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
