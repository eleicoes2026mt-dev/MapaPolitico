import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/apoiadores_provider.dart' show apoiadorOrigemLugaresProvider;

/// Procedência: combobox (lista ao focar / ao digitar) + texto livre para lugar novo.
class OrigemApoiadorField extends ConsumerStatefulWidget {
  const OrigemApoiadorField({
    super.key,
    required this.controller,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  @override
  ConsumerState<OrigemApoiadorField> createState() => _OrigemApoiadorFieldState();
}

class _OrigemApoiadorFieldState extends ConsumerState<OrigemApoiadorField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(apoiadorOrigemLugaresProvider);
    return async.when(
      data: (lugares) {
        final nomes = lugares.map((l) => l.nome).toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = constraints.maxWidth.clamp(200.0, 560.0);
            return RawAutocomplete<String>(
              textEditingController: widget.controller,
              focusNode: _focusNode,
              displayStringForOption: (s) => s,
              optionsBuilder: (TextEditingValue value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) {
                  return nomes.take(40);
                }
                return nomes.where((n) => n.toLowerCase().contains(q)).take(40);
              },
              optionsViewBuilder: (context, onSelected, options) {
                if (options.isEmpty) {
                  return const SizedBox.shrink();
                }
                final theme = Theme.of(context);
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surfaceContainerHigh,
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 240, maxWidth: panelWidth),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final opt = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(opt),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                opt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                final cs = Theme.of(context).colorScheme;
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  decoration: InputDecoration(
                    labelText: 'De onde é / procedência',
                    hintText: 'Abra a lista ou digite um lugar…',
                    helperText:
                        'Opcional. Escolha na lista ou digite; lugares novos ficam salvos para outros cadastros.',
                    suffixIcon: IconButton(
                      tooltip: 'Abrir lista de lugares',
                      onPressed: () {
                        focusNode.requestFocus();
                        textEditingController.selection = TextSelection.collapsed(
                          offset: textEditingController.text.length,
                        );
                      },
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 28,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'De onde é / procedência',
          hintText: 'Carregando lugares…',
        ),
      ),
      error: (_, __) => TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          labelText: 'De onde é / procedência',
          errorText: 'Não foi possível carregar o catálogo de lugares.',
        ),
      ),
    );
  }
}
