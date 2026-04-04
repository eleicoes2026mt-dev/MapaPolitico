import 'package:flutter/material.dart';

import '../../../models/municipio.dart';

/// Resultado ao escolher município na agenda (novo fluxo com opção de mapa).
class AgendaMunicipioPickResult {
  const AgendaMunicipioPickResult({
    this.municipioId,
    this.openMapPicker = false,
  });

  /// `null` = sem cidade específica.
  final String? municipioId;

  /// Quando `true`, o formulário deve abrir o mapa para marcar o ponto após aplicar [municipioId].
  final bool openMapPicker;
}

/// Lista de municípios com busca; ordenação A–Z por nome.
/// Total exibido = quantidade vinda do banco (142 após migration completa).
Future<AgendaMunicipioPickResult?> showAgendaMunicipioPickerSheet(
  BuildContext context, {
  required List<Municipio> municipios,
  String? municipioIdSelecionado,
}) {
  return showModalBottomSheet<AgendaMunicipioPickResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return _AgendaMunicipioPickerBody(
            scrollController: scrollController,
            municipios: municipios,
            selectedId: municipioIdSelecionado,
          );
        },
      );
    },
  );
}

class _AgendaMunicipioPickerBody extends StatefulWidget {
  const _AgendaMunicipioPickerBody({
    required this.scrollController,
    required this.municipios,
    this.selectedId,
  });

  final ScrollController scrollController;
  final List<Municipio> municipios;
  final String? selectedId;

  @override
  State<_AgendaMunicipioPickerBody> createState() => _AgendaMunicipioPickerBodyState();
}

class _AgendaMunicipioPickerBodyState extends State<_AgendaMunicipioPickerBody> {
  late final TextEditingController _q;
  late final List<Municipio> _ordenados;
  late List<Municipio> _filtrados;
  Municipio? _pendente;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
    _ordenados = List<Municipio>.from(widget.municipios)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    _filtrados = List<Municipio>.from(_ordenados);
    _q.addListener(_filtrar);
  }

  void _filtrar() {
    final t = _q.text.trim().toLowerCase();
    setState(() {
      if (t.isEmpty) {
        _filtrados = List<Municipio>.from(_ordenados);
      } else {
        _filtrados = _ordenados
            .where((m) => m.nome.toLowerCase().contains(t) || m.nomeNormalizado.toLowerCase().contains(t))
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
    final t = _q.text.trim();
    final contagem = t.isEmpty
        ? '${_ordenados.length} municípios (MT • A–Z)'
        : '${_filtrados.length} resultado(s) em ${_ordenados.length} municípios';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Cidade (MT)',
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
              hintText: 'Buscar município (A–Z na lista)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.not_listed_location_outlined),
          title: const Text('Sem cidade específica'),
          subtitle: const Text('Visita sem filtro por município no mapa de apoiadores'),
          selected: widget.selectedId == null,
          onTap: () => Navigator.pop(context, const AgendaMunicipioPickResult()),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            contagem,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: widget.scrollController,
                itemCount: _filtrados.length,
                itemBuilder: (_, i) {
                  final m = _filtrados[i];
                  final sel = m.id == widget.selectedId;
                  return ListTile(
                    title: Text(m.nome),
                    selected: sel,
                    onTap: () => setState(() => _pendente = m),
                  );
                },
              ),
              if (_pendente != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 12,
                    color: theme.colorScheme.surface,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _pendente!.nome,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Confirme o município ou marque o local exato no mapa.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => Navigator.pop(
                                context,
                                AgendaMunicipioPickResult(municipioId: _pendente!.id),
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Só confirmar o município'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(
                                context,
                                AgendaMunicipioPickResult(
                                  municipioId: _pendente!.id,
                                  openMapPicker: true,
                                ),
                              ),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Marcar local no mapa'),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _pendente = null),
                              child: const Text('Voltar à lista'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
