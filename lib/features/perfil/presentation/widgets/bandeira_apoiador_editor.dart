import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/apoiador.dart';
import '../../../../models/bandeira_visual.dart';
import '../../../apoiadores/providers/apoiadores_provider.dart';
import '../../../mapa/providers/cidades_marcadores_provider.dart';
import '../../../mapa/presentation/widgets/bandeira_marcador_widget.dart';

/// Editor completo da bandeira no mapa (cores visuais, layout, emoji, estilo das iniciais).
class BandeiraApoiadorEditor extends ConsumerStatefulWidget {
  const BandeiraApoiadorEditor({super.key, required this.apoiador});

  final Apoiador apoiador;

  @override
  ConsumerState<BandeiraApoiadorEditor> createState() => _BandeiraApoiadorEditorState();
}

class _BandeiraApoiadorEditorState extends ConsumerState<BandeiraApoiadorEditor> {
  late BandeiraVisual _v;
  late final TextEditingController _iniciaisCtrl;
  bool _saving = false;

  void _resetFromApoiador() {
    _v = widget.apoiador.bandeiraVisualResolvida;
    _iniciaisCtrl.text = _v.iniciais ?? '';
  }

  @override
  void initState() {
    super.initState();
    _iniciaisCtrl = TextEditingController();
    _resetFromApoiador();
  }

  @override
  void dispose() {
    _iniciaisCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BandeiraApoiadorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apoiador.id != widget.apoiador.id) {
      _resetFromApoiador();
      return;
    }
    final a = oldWidget.apoiador.bandeiraVisualJson;
    final b = widget.apoiador.bandeiraVisualJson;
    if (jsonEncode(a ?? {}) != jsonEncode(b ?? {})) {
      _resetFromApoiador();
    }
  }

  Future<void> _escolherCor({required bool primaria}) async {
    final atual = corDeHex(primaria ? _v.corPrimariaHex : _v.corSecundariaHex);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Color pickerColor = atual;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(primaria ? 'Cor 1 (principal)' : 'Cor 2'),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (c) => setDialogState(() => pickerColor = c),
                  pickerAreaHeightPercent: 0.65,
                  displayThumbColor: true,
                  enableAlpha: false,
                  hexInputBar: false,
                  labelTypes: const [],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    final hex = corParaHexRgb(pickerColor);
                    setState(() {
                      _v = primaria
                          ? _v.copyWith(corPrimariaHex: hex)
                          : _v.copyWith(corSecundariaHex: hex);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Usar esta cor'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _escolherCorEstilo({required bool letra, required bool borda, required bool sombra}) async {
    final atual = corDeHex(
      letra
          ? (_v.iniciaisEstilo.corLetraHex ?? '#FFFFFF')
          : borda
              ? (_v.iniciaisEstilo.bordaCorHex ?? '#000000')
              : (_v.iniciaisEstilo.sombraCorHex ?? '#000000'),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Color pickerColor = atual;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                letra ? 'Cor das letras' : borda ? 'Cor da borda' : 'Cor da sombra',
              ),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (c) => setDialogState(() => pickerColor = c),
                  pickerAreaHeightPercent: 0.65,
                  enableAlpha: false,
                  labelTypes: const [],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    final hex = corParaHexRgb(pickerColor);
                    setState(() {
                      final e = _v.iniciaisEstilo;
                      _v = _v.copyWith(
                        iniciaisEstilo: e.copyWith(
                          corLetraHex: letra ? hex : null,
                          bordaCorHex: borda ? hex : null,
                          sombraCorHex: sombra ? hex : null,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirGradeEmoji() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Escolha um emoji', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Expanded(
              child: GridView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: kBandeiraEmojisOpcoes.length,
                itemBuilder: (_, i) {
                  final em = kBandeiraEmojisOpcoes[i];
                  return InkWell(
                    onTap: () {
                      setState(() => _v = _v.copyWith(emoji: em));
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Center(child: Text(em, style: const TextStyle(fontSize: 26))),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _v = _v.copyWith(emoji: null));
                Navigator.pop(ctx);
              },
              child: const Text('Remover emoji (mostrar iniciais)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      final json = _v.toJson();
      await ref.read(atualizarApoiadorProvider)(
        widget.apoiador.id,
        AtualizarApoiadorParams(
          atualizarBandeira: true,
          bandeiraVisualJson: json,
        ),
      );
      ref.invalidate(meuApoiadorProvider);
      ref.invalidate(cidadesMarcadoresMapaCampanhaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bandeira salva')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _amostraCor(String label, String hex, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: corDeHex(hex),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  Text(hex, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'As alterações da bandeira só são gravadas ao tocar em "Salvar bandeira" abaixo (não use apenas "Salvar perfil" no fim da página).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text('Pré-visualização', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: BandeiraMarcadorWidget(
              visual: _v,
              tamanho: 88,
              fallbackIniciais: widget.apoiador.initial,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Cores do fundo', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _amostraCor('Cor 1', _v.corPrimariaHex, () => _escolherCor(primaria: true)),
        const SizedBox(height: 8),
        _amostraCor('Cor 2', _v.corSecundariaHex, () => _escolherCor(primaria: false)),
        const SizedBox(height: 16),
        Text('Formato do fundo', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<BandeiraFundoLayout>(
          value: _v.layout,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.dashboard_customize_outlined),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: BandeiraFundoLayout.values
              .map((l) => DropdownMenuItem(value: l, child: Text(l.labelPt, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (l) {
            if (l != null) setState(() => _v = _v.copyWith(layout: l));
          },
        ),
        const SizedBox(height: 20),
        Text('Emoji', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _abrirGradeEmoji,
          icon: const Icon(Icons.emoji_emotions_outlined),
          label: Text(_v.emoji == null || _v.emoji!.isEmpty ? 'Escolher entre 100 emojis' : 'Emoji: ${_v.emoji}'),
        ),
        const SizedBox(height: 20),
        Text('Iniciais (se não usar emoji)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _iniciaisCtrl,
          maxLength: 3,
          decoration: const InputDecoration(
            hintText: 'Ex.: AB',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (s) => setState(() => _v = _v.copyWith(iniciais: s.trim().isEmpty ? null : s.trim())),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Negrito nas iniciais'),
          value: _v.iniciaisEstilo.negrito,
          onChanged: (b) => setState(() => _v = _v.copyWith(iniciaisEstilo: _v.iniciaisEstilo.copyWith(negrito: b))),
        ),
        _amostraCor(
          'Cor das letras',
          _v.iniciaisEstilo.corLetraHex ?? '#FFFFFF',
          () => _escolherCorEstilo(letra: true, borda: false, sombra: false),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Borda no texto'),
          value: _v.iniciaisEstilo.bordaAtiva,
          onChanged: (b) => setState(() => _v = _v.copyWith(iniciaisEstilo: _v.iniciaisEstilo.copyWith(bordaAtiva: b))),
        ),
        if (_v.iniciaisEstilo.bordaAtiva) ...[
          _amostraCor(
            'Cor da borda',
            _v.iniciaisEstilo.bordaCorHex ?? '#000000',
            () => _escolherCorEstilo(letra: false, borda: true, sombra: false),
          ),
          Slider(
            value: _v.iniciaisEstilo.bordaLargura.clamp(0.5, 4.0),
            min: 0.5,
            max: 4,
            divisions: 7,
            label: 'Espessura ${_v.iniciaisEstilo.bordaLargura.toStringAsFixed(1)}',
            onChanged: (x) => setState(() => _v = _v.copyWith(iniciaisEstilo: _v.iniciaisEstilo.copyWith(bordaLargura: x))),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sombra no texto'),
          value: _v.iniciaisEstilo.sombraAtiva,
          onChanged: (b) => setState(() => _v = _v.copyWith(iniciaisEstilo: _v.iniciaisEstilo.copyWith(sombraAtiva: b))),
        ),
        if (_v.iniciaisEstilo.sombraAtiva)
          _amostraCor(
            'Cor da sombra',
            _v.iniciaisEstilo.sombraCorHex ?? '#000000',
            () => _escolherCorEstilo(letra: false, borda: false, sombra: true),
          ),
        const SizedBox(height: 20),
        FilledButton.tonal(
          onPressed: _saving ? null : _salvar,
          child: _saving
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar bandeira'),
        ),
      ],
    );
  }
}
