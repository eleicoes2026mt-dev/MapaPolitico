import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/env_config.dart';
import '../constants/amigos_gilberto.dart';

/// URL pública de cadastro «Amigos do Gilberto» (`?amigos=1` nos metadados do signup).
///
/// Usa [EnvConfig.appUrl] (`APP_URL` na build / Vercel), igual aos redirects de convite —
/// **não** usa [Uri.base], para o QR e o link copiado apontarem sempre ao site online.
/// A rota `/cadastro-amigos` é pública e exibe só o formulário de cadastro.
String urlCadastroAmigosGilberto() {
  final base = EnvConfig.supabaseRedirectOrigin;
  return '$base/cadastro-amigos';
}

/// Painel largo estilo infográfico: foto do candidato, benefícios e QR.
/// [candidatePhotoUrl] — preferencialmente `avatarUrl`; use `Profile.sidebarBrandImageUrl` ao chamar.
void showAmigosGilbertoQrDialog(
  BuildContext context, {
  String? candidatePhotoUrl,
  String? candidateName,
}) {
  final url = urlCadastroAmigosGilberto();
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _AmigosGilbertoQrInfographic(
      url: url,
      candidatePhotoUrl: candidatePhotoUrl,
      candidateName: candidateName,
    ),
  );
}

class _AmigosGilbertoQrInfographic extends StatelessWidget {
  const _AmigosGilbertoQrInfographic({
    required this.url,
    this.candidatePhotoUrl,
    this.candidateName,
  });

  final String url;
  final String? candidatePhotoUrl;
  final String? candidateName;

  static const double _maxDialogWidth = 920;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = (screenW - 24).clamp(320.0, _maxDialogWidth);
    final useWideLayout = maxW >= 720;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: screenH * 0.94,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderBar(
              onClose: () => Navigator.of(context).pop(),
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
                        url: url,
                        candidatePhotoUrl: candidatePhotoUrl,
                        candidateName: candidateName,
                        screenW: screenW,
                      )
                    : _NarrowBody(
                        url: url,
                        candidatePhotoUrl: candidatePhotoUrl,
                        candidateName: candidateName,
                        screenW: screenW,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        Navigator.of(context).pop();
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
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onClose});

  final VoidCallback onClose;

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
              ],
            ),
          ),
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
  });

  final String url;
  final double screenW;
  final String? candidatePhotoUrl;
  final String? candidateName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrSize = screenW < 900 ? 220.0 : 260.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CandidatePhotoBlock(
                imageUrl: candidatePhotoUrl,
                name: candidateName,
                maxWidth: 280,
              ),
              const SizedBox(height: 18),
              Text(
                'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          flex: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _benefitsTwoByTwo(context),
              const SizedBox(height: 22),
              Text(
                'Escaneie o código ou compartilhe o link de cadastro',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 14),
              Center(child: _QrCard(url: url, size: qrSize)),
              const SizedBox(height: 14),
              _LinkBlock(url: url, theme: theme),
              const SizedBox(height: 6),
              Text(
                'O cadastro exige e-mail para acesso seguro ao painel.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody({
    required this.url,
    required this.screenW,
    this.candidatePhotoUrl,
    this.candidateName,
  });

  final String url;
  final double screenW;
  final String? candidatePhotoUrl;
  final String? candidateName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrSize = screenW < 400 ? 220.0 : 248.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _CandidatePhotoBlock(
            imageUrl: candidatePhotoUrl,
            name: candidateName,
            maxWidth: 260,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Acompanhe a trajetória, participe da rede e receba tudo o que importa para a campanha — em um só lugar.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Ao cadastrar-se com e-mail válido, a pessoa passa a ter acesso a:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const _BenefitTile(
          icon: Icons.campaign_outlined,
          title: 'Informações da campanha',
          subtitle: 'Atualizações e comunicados oficiais.',
        ),
        const _BenefitTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Mensagens da campanha',
          subtitle: 'Conteúdos enviados à rede de apoio.',
        ),
        const _BenefitTile(
          icon: Icons.event_available_outlined,
          title: 'Reuniões e encontros',
          subtitle: 'Convites e avisos sobre encontros em polos e cidades.',
        ),
        const _BenefitTile(
          icon: Icons.calendar_month_outlined,
          title: 'Agenda e ações',
          subtitle: 'Datas e mobilizações para não perder nada.',
        ),
        const SizedBox(height: 20),
        Text(
          'Escaneie o código ou compartilhe o link de cadastro',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 14),
        Center(child: _QrCard(url: url, size: qrSize)),
        const SizedBox(height: 14),
        _LinkBlock(url: url, theme: theme),
        const SizedBox(height: 8),
        Text(
          'O cadastro exige e-mail para acesso seguro ao painel.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

Widget _benefitsTwoByTwo(BuildContext context) {
  return Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            child: _BenefitTile(
              icon: Icons.campaign_outlined,
              title: 'Informações da campanha',
              subtitle: 'Atualizações e comunicados oficiais.',
              compact: true,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _BenefitTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Mensagens da campanha',
              subtitle: 'Conteúdos enviados à rede de apoio.',
              compact: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            child: _BenefitTile(
              icon: Icons.event_available_outlined,
              title: 'Reuniões e encontros',
              subtitle: 'Convites e avisos em polos e cidades.',
              compact: true,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _BenefitTile(
              icon: Icons.calendar_month_outlined,
              title: 'Agenda e ações',
              subtitle: 'Datas e mobilizações.',
              compact: true,
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
  });

  final String? imageUrl;
  final String? name;
  final double maxWidth;

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
            style: theme.textTheme.titleMedium?.copyWith(
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
  const _LinkBlock({required this.url, required this.theme});

  final String url;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SelectableText(
          url,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.35,
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

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pad = compact ? 8.0 : 8.0;
    final iconBox = compact ? 36.0 : 40.0;
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
              color: cs.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: compact ? 20 : 22, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                    fontSize: compact ? 11.5 : null,
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
