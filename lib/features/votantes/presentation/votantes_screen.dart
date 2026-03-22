import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/apoiador.dart';
import '../../../models/municipio.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mapa/data/mt_municipios_coords.dart';
import '../providers/votantes_provider.dart';

class VotantesScreen extends ConsumerStatefulWidget {
  const VotantesScreen({super.key});

  @override
  ConsumerState<VotantesScreen> createState() => _VotantesScreenState();
}

class _VotantesScreenState extends ConsumerState<VotantesScreen> {
  String _query = '';
  String _cidadeFilter = '';

  Future<void> _abrirNovoOuEditar({Votante? existente}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VotanteFormDialog(existente: existente),
    );
  }

  Future<void> _promoverParaApoiador(Votante v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promover a apoiador'),
        content: Text(
          'Criar cadastro de apoiador para "${v.nome}" e remover o registro de votante? '
          'É necessário ter município definido e o votante não pode estar vinculado a outro apoiador.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Promover')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(promoverVotanteParaApoiadorProvider)(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votante promovido a apoiador.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _confirmarExcluir(Votante v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir votante'),
        content: Text('Remover "${v.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(removerVotanteProvider)(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Votante removido.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeCadastrar =
        profile?.role == 'candidato' || profile?.role == 'assessor' || profile?.role == 'apoiador';
    final podePromoverApoiador = profile?.role == 'candidato' || profile?.role == 'assessor';

    final list = ref.watch(votantesListProvider);
    final apoiadoresAsync = ref.watch(apoiadoresListProvider);
    final apoiadorPorId = Map<String, String>.fromEntries(
      (apoiadoresAsync.valueOrNull ?? []).map((a) => MapEntry(a.id, a.nome)),
    );

    final votantes = list.valueOrNull ?? [];
    final votosTotal = votantes.fold<int>(0, (a, v) => a + v.qtdVotosFamilia);
    var filtered = votantes;
    if (_query.isNotEmpty) {
      filtered = filtered.where((v) => v.nome.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    if (_cidadeFilter.isNotEmpty) {
      final q = _cidadeFilter.toLowerCase();
      filtered = filtered.where((v) {
        final nome = (v.municipioNome ?? '').toLowerCase();
        final id = v.municipioId ?? '';
        return nome.contains(q) || id.toLowerCase().contains(q);
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Votantes', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const EstadoMTBadge(compact: true),
            ],
          ),
          if (profile?.role == 'apoiador') ...[
            const SizedBox(height: 8),
            Text(
              'Cadastre pessoas da sua rede com cidade em MT para somarem na estimativa e aparecerem no mapa regional.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar votante...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filtrar por cidade...',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  onChanged: (v) => setState(() => _cidadeFilter = v),
                ),
              ),
              const SizedBox(width: 12),
              if (podeCadastrar)
                FilledButton.icon(
                  onPressed: () => _abrirNovoOuEditar(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Votante'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(label: Text('${filtered.length} votantes')),
              const SizedBox(width: 8),
              Chip(label: Text('$votosTotal votos estimados')),
            ],
          ),
          const SizedBox(height: 16),
          list.when(
            data: (_) => _VotantesTable(
              votantes: filtered,
              apoiadorPorId: apoiadorPorId,
              podePromoverApoiador: podePromoverApoiador,
              onEdit: (v) => _abrirNovoOuEditar(existente: v),
              onDelete: _confirmarExcluir,
              onPromover: _promoverParaApoiador,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    );
  }
}

class _VotantesTable extends StatelessWidget {
  const _VotantesTable({
    required this.votantes,
    required this.apoiadorPorId,
    required this.podePromoverApoiador,
    required this.onEdit,
    required this.onDelete,
    required this.onPromover,
  });

  final List<Votante> votantes;
  final Map<String, String> apoiadorPorId;
  final bool podePromoverApoiador;
  final void Function(Votante) onEdit;
  final void Function(Votante) onDelete;
  final void Function(Votante) onPromover;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 700;
    if (isNarrow) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: votantes.length,
        itemBuilder: (_, i) {
          final v = votantes[i];
          final cidade = v.municipioNome ?? '—';
          final ap = v.apoiadorId != null ? (apoiadorPorId[v.apoiadorId!] ?? '—') : '—';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(v.nome),
              subtitle: Text('${v.telefone ?? ""} • $cidade • ${v.abrangencia} • ${v.qtdVotosFamilia} voto(s) • $ap'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (podePromoverApoiador && v.apoiadorId == null && v.municipioId != null)
                    IconButton(
                      icon: const Icon(Icons.upgrade),
                      tooltip: 'Promover a apoiador',
                      onPressed: () => onPromover(v),
                    ),
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => onEdit(v)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => onDelete(v)),
                ],
              ),
            ),
          );
        },
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nome')),
          DataColumn(label: Text('Contato')),
          DataColumn(label: Text('Cidade')),
          DataColumn(label: Text('Abrangência')),
          DataColumn(label: Text('Votos')),
          DataColumn(label: Text('Apoiador')),
          DataColumn(label: Text('Ações')),
        ],
        rows: votantes.map((v) {
          final cidade = v.municipioNome ?? (v.municipioId != null ? v.municipioId! : '—');
          final ap = v.apoiadorId != null ? (apoiadorPorId[v.apoiadorId!] ?? '—') : '—';
          final podePromover = podePromoverApoiador && v.apoiadorId == null && v.municipioId != null;
          return DataRow(
            cells: [
              DataCell(Text(v.nome)),
              DataCell(Text(v.telefone ?? '—')),
              DataCell(Text(displayNomeCidadeMT(cidade))),
              DataCell(Text(v.abrangencia)),
              DataCell(Text('${v.qtdVotosFamilia}')),
              DataCell(Text(ap)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (podePromover)
                    IconButton(
                      icon: const Icon(Icons.upgrade, size: 20),
                      tooltip: 'Promover a apoiador',
                      onPressed: () => onPromover(v),
                    ),
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => onEdit(v)),
                  IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () => onDelete(v)),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _VotanteFormDialog extends ConsumerStatefulWidget {
  const _VotanteFormDialog({this.existente});

  final Votante? existente;

  @override
  ConsumerState<_VotanteFormDialog> createState() => _VotanteFormDialogState();
}

class _VotanteFormDialogState extends ConsumerState<_VotanteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  late final TextEditingController _qtd;
  String? _municipioId;
  String _abrangencia = 'Individual';
  String? _apoiadorOpcionalId;
  bool _loading = false;
  /// Apoiador criando votante: true = escolher outra cidade no dropdown.
  bool _usarOutroMunicipio = false;
  bool _municipioPadraoApoiadorAplicado = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existente;
    _nome = TextEditingController(text: v?.nome ?? '');
    _telefone = TextEditingController(text: v?.telefone ?? '');
    _email = TextEditingController(text: v?.email ?? '');
    _qtd = TextEditingController(text: '${v?.qtdVotosFamilia ?? 1}');
    _municipioId = v?.municipioId;
    _abrangencia = v?.abrangencia ?? 'Individual';
    _apoiadorOpcionalId = v?.apoiadorId;
    if (v != null) {
      _municipioPadraoApoiadorAplicado = true;
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _qtd.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_municipioId == null || _municipioId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o município.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final qtd = int.tryParse(_qtd.text.trim()) ?? 1;
      if (widget.existente != null) {
        await ref.read(atualizarVotanteProvider)(
          widget.existente!.id,
          AtualizarVotanteParams(
            nome: _nome.text.trim(),
            telefone: _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            municipioId: _municipioId,
            abrangencia: _abrangencia,
            qtdVotosFamilia: qtd,
          ),
        );
      } else {
        final profile = ref.read(profileProvider).valueOrNull;
        await ref.read(criarVotanteProvider)(
          NovoVotanteParams(
            nome: _nome.text.trim(),
            telefone: _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            municipioId: _municipioId,
            abrangencia: _abrangencia,
            qtdVotosFamilia: qtd < 1 ? 1 : qtd,
            apoiadorId: profile?.role == 'apoiador' ? null : _apoiadorOpcionalId,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existente != null ? 'Votante atualizado.' : 'Votante cadastrado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _nomeMunicipioParaExibir(List<Municipio> municipios, String municipioId, String? cidadeNomeFallback) {
    for (final m in municipios) {
      if (m.id == municipioId) return displayNomeCidadeMT(m.nome);
    }
    if (cidadeNomeFallback != null && cidadeNomeFallback.trim().isNotEmpty) {
      return displayNomeCidadeMT(normalizarNomeMunicipioMT(cidadeNomeFallback));
    }
    return 'Município';
  }

  /// Novo votante como apoiador: padrão = cidade do cadastro do apoiador; opção de outro município.
  List<Widget> _camposMunicipioApoiador(ThemeData theme, List<Municipio> municipios) {
    return ref.watch(meuApoiadorProvider).when(
          loading: () => [
            Text(
              'Carregando seu município de cadastro...',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          error: (e, _) => [
            Text(
              'Erro ao carregar seu cadastro: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          data: (meuAp) {
            final midAp = meuAp?.municipioId?.trim();
            final temCidadeCadastro = midAp != null && midAp.isNotEmpty;

            if (!temCidadeCadastro) {
              return [
                Text(
                  'Seu cadastro de apoiador não tem município. Escolha a cidade do votante abaixo ou defina o município em Meu perfil (via assessor/candidato).',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _municipioId != null && municipios.any((m) => m.id == _municipioId)
                      ? _municipioId
                      : null,
                  decoration: const InputDecoration(labelText: 'Município (MT) *'),
                  items: municipios
                      .map((m) => DropdownMenuItem(value: m.id, child: Text(displayNomeCidadeMT(m.nome))))
                      .toList(),
                  onChanged: (v) => setState(() => _municipioId = v),
                  validator: (v) => v == null || v.isEmpty ? 'Selecione' : null,
                ),
              ];
            }

            final out = <Widget>[];
            if (!_usarOutroMunicipio) {
              out.add(
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Município (MT) *',
                    helperText: 'Padrão: mesma cidade do seu cadastro de apoiador',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _nomeMunicipioParaExibir(municipios, midAp, meuAp?.cidadeNome),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              );
            } else {
              out.add(
                DropdownButtonFormField<String>(
                  value: _municipioId != null && municipios.any((m) => m.id == _municipioId)
                      ? _municipioId
                      : null,
                  decoration: const InputDecoration(labelText: 'Município (MT) *'),
                  items: municipios
                      .map((m) => DropdownMenuItem(value: m.id, child: Text(displayNomeCidadeMT(m.nome))))
                      .toList(),
                  onChanged: (v) => setState(() => _municipioId = v),
                  validator: (v) => v == null || v.isEmpty ? 'Selecione' : null,
                ),
              );
            }
            out.add(
              CheckboxListTile(
                value: _usarOutroMunicipio,
                onChanged: (v) {
                  setState(() {
                    _usarOutroMunicipio = v ?? false;
                    if (!_usarOutroMunicipio) {
                      _municipioId = midAp;
                    }
                  });
                },
                title: const Text('Cadastrar em outro município'),
                subtitle: _usarOutroMunicipio
                    ? const Text('Desmarque para voltar à sua cidade de cadastro')
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            );
            return out;
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final munAsync = ref.watch(municipiosMTListProvider);
    final apoiadoresAsync = ref.watch(apoiadoresListProvider);
    final mostrarApoiadorOpcional = profile?.role == 'candidato' || profile?.role == 'assessor';

    ref.listen<AsyncValue<Apoiador?>>(meuApoiadorProvider, (_, next) {
      if (widget.existente != null) return;
      if (ref.read(profileProvider).valueOrNull?.role != 'apoiador') return;
      next.whenData((ap) {
        if (!mounted || _municipioPadraoApoiadorAplicado) return;
        setState(() {
          _municipioPadraoApoiadorAplicado = true;
          final id = ap?.municipioId?.trim();
          if (id != null && id.isNotEmpty) {
            _municipioId = id;
            _usarOutroMunicipio = false;
          } else {
            _usarOutroMunicipio = true;
          }
        });
      });
    });

    return AlertDialog(
      title: Text(widget.existente != null ? 'Editar votante' : 'Novo votante'),
      content: SizedBox(
        width: 420,
        child: munAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro ao carregar cidades: $e'),
          data: (municipios) {
            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nome,
                      decoration: const InputDecoration(labelText: 'Nome *'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telefone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    if (profile?.role == 'apoiador' && widget.existente == null)
                      ..._camposMunicipioApoiador(theme, municipios)
                    else ...[
                      DropdownButtonFormField<String>(
                        value: _municipioId != null && municipios.any((m) => m.id == _municipioId)
                            ? _municipioId
                            : null,
                        decoration: const InputDecoration(labelText: 'Município (MT) *'),
                        items: municipios
                            .map((m) => DropdownMenuItem(value: m.id, child: Text(displayNomeCidadeMT(m.nome))))
                            .toList(),
                        onChanged: (v) => setState(() => _municipioId = v),
                        validator: (v) => v == null || v.isEmpty ? 'Selecione' : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _abrangencia,
                      decoration: const InputDecoration(labelText: 'Abrangência'),
                      items: const [
                        DropdownMenuItem(value: 'Individual', child: Text('Individual')),
                        DropdownMenuItem(value: 'Familiar', child: Text('Familiar')),
                      ],
                      onChanged: (v) => setState(() => _abrangencia = v ?? 'Individual'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qtd,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de votos (família/rede)',
                        hintText: '1',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    if (mostrarApoiadorOpcional && widget.existente == null) ...[
                      const SizedBox(height: 12),
                      apoiadoresAsync.when(
                        data: (apoiadores) {
                          final items = <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(value: null, child: Text('Nenhum (só campanha)')),
                            ...apoiadores.map(
                              (a) => DropdownMenuItem(value: a.id, child: Text(a.nome)),
                            ),
                          ];
                          return DropdownButtonFormField<String?>(
                            value: _apoiadorOpcionalId,
                            decoration: const InputDecoration(
                              labelText: 'Vincular a apoiador (opcional)',
                            ),
                            items: items,
                            onChanged: (v) => setState(() => _apoiadorOpcionalId = v),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'A cidade do votante alimenta o mapa regional e a estimativa por município.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _salvar,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
