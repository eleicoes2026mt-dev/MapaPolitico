import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env_config.dart';
import '../constants/amigos_gilberto.dart';

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
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _AmigosGilbertoQrInfographic(
      url: url,
      candidatePhotoUrl: candidatePhotoUrl,
      candidateName: nomeCartao,
      inviterSubtitle: labelConvite.isNotEmpty ? labelConvite : null,
      inviterLabelForShare: labelConvite,
    ),
  );
}

class _AmigosGilbertoQrInfographic extends StatefulWidget {
  const _AmigosGilbertoQrInfographic({
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

  static const double _maxDialogWidth = 1400;

  @override
  State<_AmigosGilbertoQrInfographic> createState() => _AmigosGilbertoQrInfographicState();
}

class _AmigosGilbertoQrInfographicState extends State<_AmigosGilbertoQrInfographic> {
  final GlobalKey _exportKey = GlobalKey();
  bool _exportBusy = false;

  String get _url => widget.url;
  String get _inviterLabelForShare => widget.inviterLabelForShare;

  /// Captura o cartão em PNG. Usa [Overlay] temporário para garantir pintura (evita
  /// `debugNeedsPaint` em web com widget fora da viewport).
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
        url: _url,
        inviterLabel: _inviterLabelForShare,
      );
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'convite_amigos_gilberto.png',
          ),
        ],
        text: caption,
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

  Future<void> _printCartao() async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final bytes = await _captureCartaoPng(pixelRatio: 3.75);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar a imagem do cartão.')),
        );
        return;
      }
      final image = pw.MemoryImage(bytes);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(14),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                _url,
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _ConviteFullscreenPage(
          url: widget.url,
          candidatePhotoUrl: widget.candidatePhotoUrl,
          candidateName: widget.candidateName,
          inviterSubtitle: widget.inviterSubtitle,
          onClose: () => Navigator.of(ctx).pop(),
          onPrint: _printCartao,
          onShareImage: _shareImageAndLink,
          exportBusy: _exportBusy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = (screenW - 24).clamp(320.0, _AmigosGilbertoQrInfographic._maxDialogWidth);
    final useWideLayout = maxW >= 720;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxW,
              maxHeight: screenH * 0.94,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderBar(
                  onClose: () => Navigator.of(context).pop(),
                  inviterSubtitle: widget.inviterSubtitle,
                  trailingActions: [
                    IconButton(
                      tooltip: 'Tela cheia',
                      onPressed: _exportBusy ? null : _openFullscreen,
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                    IconButton(
                      tooltip: 'Gerar PDF horizontal (cartão + link)',
                      onPressed: _exportBusy ? null : _printCartao,
                      icon: const Icon(Icons.print_outlined),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      useWideLayout ? 28 : 18,
                      20,
                      useWideLayout ? 28 : 18,
                      8,
                    ),
                    child: useWideLayout
                        ? _WideBody(
                            url: widget.url,
                            candidatePhotoUrl: widget.candidatePhotoUrl,
                            candidateName: widget.candidateName,
                            screenW: screenW,
                          )
                        : _NarrowBody(
                            url: widget.url,
                            candidatePhotoUrl: widget.candidatePhotoUrl,
                            candidateName: widget.candidateName,
                            screenW: screenW,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_exportBusy)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: widget.url));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Link de cadastro copiado.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.link_rounded, size: 20),
                        label: const Text('Copiar link de cadastro'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _exportBusy ? null : _shareImageAndLink,
                        icon: const Icon(Icons.chat_rounded, size: 20),
                        label: const Text('Compartilhar cartão e link'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'O cartão (imagem) e a mensagem com o link de cadastro vão juntos. Escolha o WhatsApp na lista ao compartilhar.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                    ],
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

class _ConviteFullscreenPage extends StatelessWidget {
  const _ConviteFullscreenPage({
    required this.url,
    this.candidatePhotoUrl,
    this.candidateName,
    this.inviterSubtitle,
    required this.onClose,
    required this.onPrint,
    required this.onShareImage,
    required this.exportBusy,
  });

  final String url;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;
  final VoidCallback onClose;
  final VoidCallback onPrint;
  final VoidCallback onShareImage;
  final bool exportBusy;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final useWideLayout = screenW >= 720;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Cartão de convite'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
        actions: [
          IconButton(
            tooltip: 'Gerar PDF horizontal (cartão + link)',
            onPressed: exportBusy ? null : onPrint,
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Compartilhar cartão e link',
            onPressed: exportBusy ? null : onShareImage,
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF051923),
                  Color(0xFF0D47A1),
                  Color(0xFF0277BD),
                  Color(0xFF004D6B),
                ],
                stops: [0.0, 0.28, 0.62, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.15, -0.55),
                  radius: 1.15,
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF000A12).withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight + 4,
                left: 4,
                right: 4,
                bottom: MediaQuery.paddingOf(context).bottom + 6,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final maxH = constraints.maxHeight;
                  final cardW = maxW;
                  return SizedBox(
                    width: maxW,
                    height: maxH,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: cardW,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white.withValues(alpha: 0.94),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                            child: useWideLayout
                                ? _WideBody(
                                    url: url,
                                    candidatePhotoUrl: candidatePhotoUrl,
                                    candidateName: candidateName,
                                    inviterSubtitle: inviterSubtitle,
                                    screenW: screenW,
                                    isFullscreen: true,
                                  )
                                : _NarrowBody(
                                    url: url,
                                    candidatePhotoUrl: candidatePhotoUrl,
                                    candidateName: candidateName,
                                    inviterSubtitle: inviterSubtitle,
                                    screenW: screenW,
                                    isFullscreen: true,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.onClose,
    this.inviterSubtitle,
    this.showCloseButton = true,
    this.trailingActions = const [],
  });

  final VoidCallback onClose;
  final String? inviterSubtitle;
  final bool showCloseButton;
  final List<Widget> trailingActions;

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
          ...trailingActions.map(
            (w) => IconTheme(
              data: IconThemeData(color: cs.onPrimary),
              child: w,
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

class _WideBody extends StatelessWidget {
  const _WideBody({
    required this.url,
    required this.screenW,
    this.candidatePhotoUrl,
    this.candidateName,
    this.inviterSubtitle,
    this.isFullscreen = false,
  });

  final String url;
  final double screenW;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;
  final bool isFullscreen;

  static const Color _fsBlue = Color(0xFF0D47A1);
  static const Color _fsBlueMid = Color(0xFF0277BD);
  static const Color _captionStrong = Color(0xFF263238);
  static const Color _captionMuted = Color(0xFF37474F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fs = isFullscreen;
    final qrSize = fs
        ? math.min(440.0, math.max(320.0, screenW * 0.38))
        : (screenW < 900 ? 220.0 : 260.0);

    final nameStyle = fs
        ? theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: _fsBlue,
            height: 1.15,
          )
        : theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: _fsBlue,
          );

    final taglineStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: fs ? 21 : 17,
      height: 1.45,
      color: fs ? _captionStrong : _captionMuted,
      fontWeight: FontWeight.w700,
    );

    final benefitsTitle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: fs ? 22 : 17,
      color: _fsBlue,
      height: 1.25,
    );

    final scanLabel = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      fontSize: fs ? 19 : 16,
      color: _fsBlueMid,
    );

    final footerStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: fs ? 16 : 13.5,
      color: _captionMuted,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
    );

    final mainRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: fs ? 34 : 38,
          child: Column(
            crossAxisAlignment: fs ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              _CandidatePhotoBlock(
                imageUrl: candidatePhotoUrl,
                name: candidateName,
                maxWidth: fs ? 400 : 300,
                nameStyle: nameStyle,
              ),
              SizedBox(height: fs ? 22 : 18),
              Text(
                'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
                style: taglineStyle,
                textAlign: fs ? TextAlign.left : TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(width: fs ? 28 : 24),
        Expanded(
          flex: fs ? 66 : 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a:',
                style: benefitsTitle,
              ),
              SizedBox(height: fs ? 18 : 14),
              _benefitsTwoByTwo(context, dense: !fs),
              SizedBox(height: fs ? 22 : 20),
              Text(
                'Escaneie o código ou compartilhe o link de cadastro',
                textAlign: TextAlign.right,
                style: scanLabel,
              ),
              SizedBox(height: fs ? 14 : 12),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _QrCard(url: url, size: qrSize),
                ),
              ),
              SizedBox(height: fs ? 18 : 14),
              _LinkBlock(url: url, theme: theme, emphasize: true),
              SizedBox(height: fs ? 10 : 6),
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
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.waving_hand_rounded, color: _fsBlueMid, size: fs ? 26 : 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Convite de $inv',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: fs ? 20 : null,
                        color: _fsBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: fs ? 22 : 0),
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
  });

  final String url;
  final double screenW;
  final String? candidatePhotoUrl;
  final String? candidateName;
  final String? inviterSubtitle;
  final bool isFullscreen;

  static const Color _fsBlue = Color(0xFF0D47A1);
  static const Color _fsBlueMid = Color(0xFF0277BD);
  static const Color _captionStrong = Color(0xFF263238);
  static const Color _captionMuted = Color(0xFF37474F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fs = isFullscreen;
    final qrSize = fs
        ? math.min(360.0, math.max(280.0, screenW * 0.82))
        : (screenW < 400 ? 220.0 : 248.0);

    final nameStyle = fs
        ? theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: _fsBlue,
          )
        : theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: _fsBlue,
          );

    final taglineStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: fs ? 17.5 : 16,
      height: 1.45,
      color: _captionStrong,
      fontWeight: FontWeight.w600,
    );

    final benefitsTitle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: fs ? 18.5 : 16.5,
      color: _fsBlue,
    );

    final scanLabel = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      fontSize: fs ? 16.5 : 15,
      color: _fsBlueMid,
    );

    final footerStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: fs ? 14 : 12.5,
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
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.waving_hand_rounded, color: _fsBlueMid, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Convite de $inv',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _fsBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Center(
          child: _CandidatePhotoBlock(
            imageUrl: candidatePhotoUrl,
            name: candidateName,
            maxWidth: fs ? 300 : 260,
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
        Center(child: _QrCard(url: url, size: qrSize)),
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
  const _QrCard({required this.url, required this.size});

  final String url;
  final double size;

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

    return DecoratedBox(
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
