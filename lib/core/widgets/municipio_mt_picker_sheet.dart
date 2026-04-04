import 'package:flutter/material.dart';

import '../../features/mapa/data/mt_municipios_coords.dart';

/// Abre busca por nome e retorna a chave normalizada do município (lista MT).
Future<String?> showMunicipioMtPicker(
  BuildContext context, {
  String? currentNormalizedKey,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return _MunicipioPickerBody(
            scrollController: scrollController,
            initialSelected: currentNormalizedKey,
          );
        },
      );
    },
  );
}

class _MunicipioPickerBody extends StatefulWidget {
  const _MunicipioPickerBody({
    required this.scrollController,
    this.initialSelected,
  });

  final ScrollController scrollController;
  final String? initialSelected;

  @override
  State<_MunicipioPickerBody> createState() => _MunicipioPickerBodyState();
}

class _MunicipioPickerBodyState extends State<_MunicipioPickerBody> {
  late final TextEditingController _q;
  late List<String> _todas;
  late List<String> _filtradas;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
    _todas = listCidadesMTNomesNormalizados.toList()..sort((a, b) => displayNomeCidadeMT(a).compareTo(displayNomeCidadeMT(b)));
    _filtradas = List<String>.from(_todas);
    _q.addListener(_filtrar);
  }

  void _filtrar() {
    final t = _q.text.trim().toLowerCase();
    setState(() {
      if (t.isEmpty) {
        _filtradas = List<String>.from(_todas);
      } else {
        _filtradas = _todas
            .where((k) {
              final disp = displayNomeCidadeMT(k).toLowerCase();
              return disp.contains(t) || k.contains(t);
            })
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _q.removeListener(_filtrar);
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Selecionar cidade (MT)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _q,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Pesquisar por nome...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${_filtradas.length} municípios',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _filtradas.length,
            itemBuilder: (_, i) {
              final k = _filtradas[i];
              final sel = widget.initialSelected == k;
              return ListTile(
                title: Text(displayNomeCidadeMT(k)),
                trailing: sel ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                selected: sel,
                onTap: () => Navigator.pop(context, k),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Linha de formulário: toque abre busca; exige seleção para salvar (validar no pai).
class MunicipioMtFormRow extends StatelessWidget {
  const MunicipioMtFormRow({
    super.key,
    required this.selectedNormalizedKey,
    required this.onSelected,
    this.label = 'Cidade (MT) *',
    this.errorText,
  });

  final String? selectedNormalizedKey;
  final ValueChanged<String?> onSelected;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disp = selectedNormalizedKey != null && selectedNormalizedKey!.isNotEmpty
        ? displayNomeCidadeMT(selectedNormalizedKey!)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () async {
              final k = await showMunicipioMtPicker(context, currentNormalizedKey: selectedNormalizedKey);
              if (k != null) onSelected(k);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          disp ?? 'Toque para buscar e selecionar',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: disp != null ? FontWeight.w600 : FontWeight.normal,
                            color: disp != null ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.search, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(errorText!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
