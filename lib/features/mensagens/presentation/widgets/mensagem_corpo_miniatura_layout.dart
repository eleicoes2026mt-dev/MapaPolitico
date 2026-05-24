import 'package:flutter/material.dart';

import 'mensagem_imagem_anexo.dart';

/// Corpo opcional da mensagem: texto + [linkSlot] + miniatura responsiva.
///
/// Se existir texto (ou link) **e** imagem: em ecrãs largos mantém linha com
/// miniatura à **esquerda**; quando o cartão está estreito, coloca a imagem **acima**
/// do texto.
class MensagemCorpoMiniaturaLayout extends StatelessWidget {
  const MensagemCorpoMiniaturaLayout({
    super.key,
    required this.theme,
    this.corpoTexto,
    this.linkSlot,
    this.imagemUrl,
    this.paddingTop = 10,
    this.narrowMaxWidthDp = 520,
    this.ladoImagemLadoAlado = 128,
  });

  final ThemeData theme;

  /// Conteúdo principal (opcional).
  final String? corpoTexto;

  /// Ligação clicável já estilizada (opcional): [InkWell], [TextButton], etc.
  final Widget? linkSlot;

  final String? imagemUrl;

  /// Espaço após o topo do cartão até este bloco.
  final double paddingTop;

  /// Abaixo disto o layout passa a coluna (miniatura por cima).
  final double narrowMaxWidthDp;

  /// Lado da miniatura quando **ao lado** do texto.
  final double ladoImagemLadoAlado;

  @override
  Widget build(BuildContext context) {
    final temCorpo =
        corpoTexto != null && corpoTexto!.trim().isNotEmpty;
    final temLink = linkSlot != null;
    final temImagem =
        imagemUrl != null && imagemUrl!.trim().isNotEmpty;

    if (!temCorpo && !temLink && !temImagem) {
      return const SizedBox.shrink();
    }

    Widget blocoTexto() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (temCorpo)
            Text(
              corpoTexto!.trim(),
              style: theme.textTheme.bodyMedium,
            ),
          if (temCorpo && temLink) const SizedBox(height: 8),
          if (temLink) linkSlot!,
        ],
      );
    }

    Widget miniatura() => MensagemImagemAnexo(
          imagemUrl: imagemUrl!.trim(),
          maxLadoLista: ladoImagemLadoAlado,
        );

    return LayoutBuilder(
      builder: (context, bx) {
        final estreito = bx.maxWidth < narrowMaxWidthDp;

        final Widget corpoPrincipal;
        if (temImagem && (temCorpo || temLink)) {
          if (estreito) {
            corpoPrincipal = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: miniatura(),
                ),
                const SizedBox(height: 12),
                blocoTexto(),
              ],
            );
          } else {
            corpoPrincipal = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ladoImagemLadoAlado,
                  child: miniatura(),
                ),
                const SizedBox(width: 12),
                Expanded(child: blocoTexto()),
              ],
            );
          }
        } else {
          corpoPrincipal = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (temCorpo || temLink) blocoTexto(),
              if (temImagem) ...[
                if (temCorpo || temLink) const SizedBox(height: 10),
                MensagemImagemAnexo(imagemUrl: imagemUrl!.trim()),
              ],
            ],
          );
        }

        return Padding(
          padding: EdgeInsets.only(top: paddingTop),
          child: corpoPrincipal,
        );
      },
    );
  }
}
