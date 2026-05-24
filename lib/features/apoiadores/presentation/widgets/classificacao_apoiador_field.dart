import 'package:flutter/material.dart';

import '../utils/apoiadores_form_utils.dart';

/// Campo de classificação: opções pré-definidas e, se permitido, «Outro» com texto livre.
///
/// Só gestores da campanha ([permitirNovaClassificacaoPorTexto] = true: candidato ou
/// assessor grau 1) podem registar etiquetas novas por texto livre.
class ClassificacaoApoiadorField extends StatefulWidget {
  const ClassificacaoApoiadorField({
    super.key,
    required this.sugestoesExtras,
    this.initialPerfil,
    required this.onChanged,
    this.permitirNovaClassificacaoPorTexto = false,
  });

  /// Valores já usados em outros apoiadores (além dos [kClassificacoesApoiadorPadrao]).
  final List<String> sugestoesExtras;
  final String? initialPerfil;
  final ValueChanged<String?> onChanged;

  /// Se false: sem «Outro…» nem campo de texto; só valores já existentes na lista.
  final bool permitirNovaClassificacaoPorTexto;

  @override
  State<ClassificacaoApoiadorField> createState() =>
      _ClassificacaoApoiadorFieldState();
}

/// Sem classificação (opcional).
const kClassificacaoNenhuma = '__classificacao_nenhuma__';

class _ClassificacaoApoiadorFieldState
    extends State<ClassificacaoApoiadorField> {
  late String _dropdownValue;
  late final TextEditingController _outroController;

  List<String> get _baseOpcoes {
    final s = <String>{
      ...kClassificacoesApoiadorPadrao,
      ...widget.sugestoesExtras
    };
    final ini = widget.initialPerfil?.trim();
    if (ini != null && ini.isNotEmpty) s.add(ini);
    final list = s.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void _emitir() {
    String? v;
    if (_dropdownValue == kClassificacaoNenhuma) {
      v = null;
    } else if (_dropdownValue == kClassificacaoOutroValor) {
      final t = _outroController.text.trim();
      v = t.isEmpty ? null : t;
    } else {
      v = _dropdownValue;
    }
    widget.onChanged(v);
  }

  @override
  void initState() {
    super.initState();
    final ini = widget.initialPerfil?.trim();
    final op = _baseOpcoes;
    if (ini == null || ini.isEmpty) {
      _dropdownValue = kClassificacaoNenhuma;
      _outroController = TextEditingController();
    } else if (!op.contains(ini)) {
      _dropdownValue = widget.permitirNovaClassificacaoPorTexto
          ? kClassificacaoOutroValor
          : kClassificacaoNenhuma;
      _outroController = widget.permitirNovaClassificacaoPorTexto
          ? TextEditingController(text: ini)
          : TextEditingController();
    } else {
      _dropdownValue = ini;
      _outroController = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitir());
  }

  @override
  void dispose() {
    _outroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final op = _baseOpcoes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue:
              _dropdownValue == kClassificacaoNenhuma ||
                      _dropdownValue == kClassificacaoOutroValor ||
                      op.contains(_dropdownValue)
                  ? _dropdownValue
                  : (widget.permitirNovaClassificacaoPorTexto
                      ? kClassificacaoOutroValor
                      : kClassificacaoNenhuma),
          decoration: InputDecoration(
            labelText: 'Classificação',
            helperText: widget.permitirNovaClassificacaoPorTexto
                ? 'Pode escolher uma opção ou «Outro» para digitar uma nova.'
                : 'Apenas classificações já usadas nesta campanha ou pré-definidas. Novos rótulos: candidato ou assessor grau 1.',
          ),
          items: [
            const DropdownMenuItem(
              value: kClassificacaoNenhuma,
              child: Text('Nenhuma (opcional)'),
            ),
            ...op.map((e) => DropdownMenuItem(value: e, child: Text(e))),
            if (widget.permitirNovaClassificacaoPorTexto)
              const DropdownMenuItem(
                value: kClassificacaoOutroValor,
                child: Text('Outro… (digitar abaixo)'),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _dropdownValue = v);
            _emitir();
          },
        ),
        if (_dropdownValue == kClassificacaoOutroValor) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _outroController,
            decoration: const InputDecoration(
              labelText: 'Descreva a classificação',
              hintText: 'Ex.: Comerciante, líder comunitário…',
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _emitir(),
          ),
          const SizedBox(height: 4),
          Text(
            'Ex.: Prefeito(a) da Cidade, Vereador(a), Pastor da Igreja, Empresário, ou outro termo da sua campanha.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
