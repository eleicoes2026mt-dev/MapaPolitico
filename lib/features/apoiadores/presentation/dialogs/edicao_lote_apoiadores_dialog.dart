import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/apoiadores_provider.dart'
    show atualizarApoiadorProvider, AtualizarApoiadorParams;
import '../../../assessores/providers/assessores_provider.dart' show messageFromException;
import '../widgets/origem_apoiador_field.dart';

/// Edição em massa: classificação e/ou procedência para vários apoiadores.
class EdicaoLoteApoiadoresDialog extends ConsumerStatefulWidget {
  const EdicaoLoteApoiadoresDialog({
    super.key,
    required this.apoiadorIds,
    required this.classificacoesSugestoes,
    required this.permitirClassificacaoTextoLivre,
    required this.onSaved,
  });

  final List<String> apoiadorIds;
  /// Opções válidas quando [permitirClassificacaoTextoLivre] é false (dropdown apenas).
  final List<String> classificacoesSugestoes;
  /// Apenas candidato ou assessor grau 1 digitam texto livre; outros usam apenas a lista.
  final bool permitirClassificacaoTextoLivre;
  final VoidCallback onSaved;

  @override
  ConsumerState<EdicaoLoteApoiadoresDialog> createState() =>
      _EdicaoLoteApoiadoresDialogState();
}

class _EdicaoLoteApoiadoresDialogState
    extends ConsumerState<EdicaoLoteApoiadoresDialog> {
  bool _alterarClassificacao = false;
  bool _alterarProcedencia = false;
  bool _removerProcedencia = false;
  final _classificacaoController = TextEditingController();
  late String _classificacaoDropdownValor;
  final _origemController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final op = [...widget.classificacoesSugestoes.toSet()]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _classificacaoDropdownValor = op.isNotEmpty ? op.first : '';
  }

  @override
  void dispose() {
    _classificacaoController.dispose();
    _origemController.dispose();
    super.dispose();
  }

  Future<void> _aplicar() async {
    if (!_alterarClassificacao && !_alterarProcedencia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marque pelo menos: classificação ou procedência.'),
        ),
      );
      return;
    }
    if (_alterarProcedencia && !_removerProcedencia) {
      final o = _origemController.text.trim();
      if (o.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe a procedência ou marque «Remover procedência».',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _salvando = true);
    final fn = ref.read(atualizarApoiadorProvider);
    try {
      for (final id in widget.apoiadorIds) {
        await fn(
          id,
          AtualizarApoiadorParams(
            atualizarPerfil: _alterarClassificacao,
            perfil: widget.permitirClassificacaoTextoLivre
                ? _classificacaoController.text
                : _classificacaoDropdownValor,
            atualizarOrigemLugar: _alterarProcedencia,
            origemLugarTexto: _removerProcedencia ? '' : _origemController.text,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageFromException(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.apoiadorIds.length;
    final chips = widget.classificacoesSugestoes.take(10).toList();
    final opcoesClassificacaoOrdenadas = [...widget.classificacoesSugestoes.toSet()]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return AlertDialog(
      title: Text('Edição em lote ($n)'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'As alterações abaixo serão aplicadas a todos os apoiadores selecionados. '
                'Classificação vazia remove a classificação.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alterar classificação'),
                subtitle: const Text('Ex.: Prefeita, Empresário, Vereador(a)'),
                value: _alterarClassificacao,
                onChanged: _salvando
                    ? null
                    : (v) => setState(() => _alterarClassificacao = v),
              ),
              if (_alterarClassificacao) ...[
                if (widget.permitirClassificacaoTextoLivre) ...[
                  TextFormField(
                    controller: _classificacaoController,
                    enabled: !_salvando,
                    decoration: const InputDecoration(
                      labelText: 'Classificação',
                      border: OutlineInputBorder(),
                      hintText: 'Deixe em branco para remover',
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sugestões',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: chips
                          .map(
                            (s) => ActionChip(
                              label: Text(s),
                              onPressed: _salvando
                                  ? null
                                  : () => setState(
                                        () => _classificacaoController.text = s,
                                      ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Só classificações já existentes nesta campanha. Para criar etiquetas novas, use conta de candidato ou assessor grau 1.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (opcoesClassificacaoOrdenadas.isEmpty)
                    Text(
                      'Ainda não há classificações na base (defina primeiro em algum cadastro ou peça ao gestor da campanha).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    )
                  else ...[
                    Builder(
                      builder: (ctx) {
                        final effectiveValor =
                            opcoesClassificacaoOrdenadas.contains(
                                        _classificacaoDropdownValor) ||
                                    _classificacaoDropdownValor.isEmpty
                                ? _classificacaoDropdownValor
                                : opcoesClassificacaoOrdenadas.first;
                        return DropdownButtonFormField<String>(
                          key: ValueKey(effectiveValor),
                          initialValue: effectiveValor,
                          decoration: const InputDecoration(
                            labelText: 'Classificação',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Remover classificação'),
                            ),
                            ...opcoesClassificacaoOrdenadas.map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              ),
                            ),
                          ],
                          onChanged: _salvando
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _classificacaoDropdownValor = v);
                                },
                        );
                      },
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alterar procedência'),
                subtitle: const Text('Lugar de origem / «de onde é»'),
                value: _alterarProcedencia,
                onChanged: _salvando
                    ? null
                    : (v) => setState(() {
                          _alterarProcedencia = v;
                          if (!v) _removerProcedencia = false;
                        }),
              ),
              if (_alterarProcedencia) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remover procedência'),
                  value: _removerProcedencia,
                  onChanged: _salvando
                      ? null
                      : (v) => setState(() {
                            _removerProcedencia = v ?? false;
                          }),
                ),
                if (!_removerProcedencia)
                  OrigemApoiadorField(controller: _origemController),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _aplicar,
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Aplicar a todos'),
        ),
      ],
    );
  }
}
