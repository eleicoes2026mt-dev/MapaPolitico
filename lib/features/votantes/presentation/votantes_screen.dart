import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/services/cep_br_service.dart';
import '../../../core/utils/municipio_resolver.dart'
    show chaveMunicipioMtApartirCepLocalidade, municipioIdParaNomeCidade, municipioIdResolvidoParaApoiador;
import '../../../core/widgets/municipio_mt_picker_sheet.dart';
import '../../apoiadores/presentation/utils/apoiadores_form_utils.dart'
    show
        CepInputFormatter,
        TelefoneInputFormatter,
        cepSoDigitos,
        formatCepDisplayFromDigits,
        formatTelefoneBrFromDigits,
        telefoneSoDigitos;
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/profile.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../assessores/providers/assessores_provider.dart' show meuAssessorRegistroProvider;
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
          'Criar cadastro de apoiador para "${v.nome}" e remover o registro de $kAmigosGilbertoLabel? '
          'É necessário ter município definido e a pessoa não pode estar vinculada a outro apoiador.',
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
          SnackBar(content: Text('Cadastro de $kAmigosGilbertoLabel promovido a apoiador.')),
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
        title: Text('Excluir cadastro ($kAmigosGilbertoLabel)'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cadastro de $kAmigosGilbertoLabel removido.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeCadastrar = profile?.role == 'candidato' ||
        profile?.role == 'assessor' ||
        profile?.role == 'apoiador' ||
        profile?.role == 'votante';
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
        final nome = v.cidadeDisplay.toLowerCase();
        return nome.contains(q);
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(votantesListProvider);
        ref.invalidate(municipiosMTListProvider);
        await ref.read(votantesListProvider.future).then((_) {}).onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kAmigosGilbertoLabel, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                  decoration: InputDecoration(
                    hintText: 'Buscar em $kAmigosGilbertoLabel...',
                    prefixIcon: const Icon(Icons.search),
                  ),
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
                  label: Text('Novo — $kAmigosGilbertoLabel'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(label: Text('${filtered.length} cadastrados')),
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
          final cidade = v.cidadeDisplay.isNotEmpty ? displayNomeCidadeMT(v.cidadeDisplay) : '—';
          final ap = v.apoiadorId != null ? (apoiadorPorId[v.apoiadorId!] ?? '—') : '—';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(v.nome),
              subtitle: Text(
                '${v.telefone == null || v.telefone!.isEmpty ? "—" : formatTelefoneBrFromDigits(v.telefone)} • $cidade • ${v.abrangencia} • ${v.qtdVotosFamilia} voto(s) • $ap',
              ),
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
          final cidade = v.cidadeDisplay.isNotEmpty ? displayNomeCidadeMT(v.cidadeDisplay) : '—';
          final ap = v.apoiadorId != null ? (apoiadorPorId[v.apoiadorId!] ?? '—') : '—';
          final podePromover = podePromoverApoiador && v.apoiadorId == null && v.municipioId != null;
          return DataRow(
            cells: [
              DataCell(Text(v.nome)),
              DataCell(Text(
                v.telefone == null || v.telefone!.isEmpty
                    ? '—'
                    : formatTelefoneBrFromDigits(v.telefone),
              )),
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
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  /// Chave normalizada (lista `listCidadesMTNomesNormalizados`), igual ao cadastro de apoiadores.
  String? _cidadeNomeNormalizado;
  String? _cidadeErro;
  String _abrangencia = 'Individual';
  bool _loading = false;
  /// Apoiador criando votante: preenche cidade padrão uma vez a partir do cadastro.
  bool _apoiadorPadraoCidadeAplicado = false;
  bool _postFrameDefaultApoiadorAgendado = false;
  /// Edição: sincronizar dropdown a partir de `municipio_id` (uma vez).
  bool _postFrameSyncEdicaoAgendado = false;
  Timer? _cepDebounce;
  bool _cepLoading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existente;
    _nome = TextEditingController(text: v?.nome ?? '');
    _telefone = TextEditingController(text: formatTelefoneBrFromDigits(v?.telefone));
    _email = TextEditingController(text: v?.email ?? '');
    _qtd = TextEditingController(text: '${v?.qtdVotosFamilia ?? 1}');
    _cep = TextEditingController(text: formatCepDisplayFromDigits(v?.cep));
    _logradouro = TextEditingController(text: v?.logradouro ?? '');
    _numero = TextEditingController(text: v?.numero ?? '');
    _complemento = TextEditingController(text: v?.complemento ?? '');
    // Prioridade: nome do join > cidade_nome salvo > vazio
    final cidadeInicial = v?.municipioNome?.trim().isNotEmpty == true
        ? v!.municipioNome!
        : (v?.cidadeNome?.trim().isNotEmpty == true ? v!.cidadeNome! : null);
    if (cidadeInicial != null) {
      _cidadeNomeNormalizado = normalizarNomeMunicipioMT(cidadeInicial);
    }
    _abrangencia = v?.abrangencia ?? 'Individual';
    if (v != null) {
      _apoiadorPadraoCidadeAplicado = true;
    }
  }

  void _onCepDigitado(String _) {
    _cepDebounce?.cancel();
    final d = cepSoDigitos(_cep.text);
    if (d.length != 8) return;
    _cepDebounce = Timer(const Duration(milliseconds: 450), _buscarCep);
  }

  Future<void> _buscarCep() async {
    if (!mounted) return;
    final d = cepSoDigitos(_cep.text);
    if (d.length != 8) return;
    setState(() => _cepLoading = true);
    try {
      final r = await fetchCepBr(d);
      if (!mounted || r == null) return;
      setState(() {
        if (r.logradouro.trim().isNotEmpty) {
          _logradouro.text = r.logradouro.trim();
        }
        final comp = r.complemento?.trim();
        final bairro = r.bairro?.trim();
        if (_complemento.text.trim().isEmpty) {
          if (comp != null && comp.isNotEmpty) {
            _complemento.text = comp;
          } else if (bairro != null && bairro.isNotEmpty) {
            _complemento.text = bairro;
          }
        }
        final chave = chaveMunicipioMtApartirCepLocalidade(r.localidade, r.uf);
        if (chave != null) {
          _cidadeNomeNormalizado = chave;
          _cidadeErro = null;
        }
      });
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  @override
  void dispose() {
    _cepDebounce?.cancel();
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _qtd.dispose();
    _cep.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_cidadeNomeNormalizado == null || _cidadeNomeNormalizado!.trim().isEmpty) {
      setState(() => _cidadeErro = 'Selecione o município.');
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cidadeNomeNormalizado == null || _cidadeNomeNormalizado!.trim().isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      // Tenta resolver municipio_id — mas NÃO bloqueia se não conseguir.
      final municipios = await refreshMunicipiosMTList(ref);
      var municipioIdResolvido = municipioIdParaNomeCidade(_cidadeNomeNormalizado, municipios);
      municipioIdResolvido ??=
          municipioIdParaNomeCidade(displayNomeCidadeMT(_cidadeNomeNormalizado!), municipios);

      // Cidade em texto legível para salvar em cidade_nome.
      final cidadeTexto = displayNomeCidadeMT(_cidadeNomeNormalizado!);

      final qtd = int.tryParse(_qtd.text.trim()) ?? 1;
      final profile = ref.read(profileProvider).valueOrNull;
      final cadastroAvulsoQr = profile?.cadastroViaQr == true;
      if (widget.existente != null) {
        await ref.read(atualizarVotanteProvider)(
          widget.existente!.id,
          AtualizarVotanteParams(
            nome: _nome.text.trim(),
            telefone: telefoneSoDigitos(_telefone.text).isEmpty ? null : telefoneSoDigitos(_telefone.text),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            municipioId: municipioIdResolvido,
            cidadeNome: cidadeTexto,
            abrangencia: _abrangencia,
            qtdVotosFamilia: qtd,
            cep: cepSoDigitos(_cep.text).isEmpty ? null : cepSoDigitos(_cep.text),
            logradouro: _logradouro.text.trim().isEmpty ? null : _logradouro.text.trim(),
            numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
            complemento: _complemento.text.trim().isEmpty ? null : _complemento.text.trim(),
          ),
        );
      } else {
        await ref.read(criarVotanteProvider)(
          NovoVotanteParams(
            nome: _nome.text.trim(),
            telefone: telefoneSoDigitos(_telefone.text).isEmpty ? null : telefoneSoDigitos(_telefone.text),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            municipioId: municipioIdResolvido,
            cidadeNome: cidadeTexto,
            abrangencia: _abrangencia,
            qtdVotosFamilia: qtd < 1 ? 1 : qtd,
            // Candidato/assessor: sem apoiador na rede; apoiador: preenchido no provider.
            apoiadorId: null,
            cep: cepSoDigitos(_cep.text).isEmpty ? null : cepSoDigitos(_cep.text),
            logradouro: _logradouro.text.trim().isEmpty ? null : _logradouro.text.trim(),
            numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
            complemento: _complemento.text.trim().isEmpty ? null : _complemento.text.trim(),
            cadastroViaQr: cadastroAvulsoQr,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        final aviso = municipioIdResolvido == null
            ? ' (vínculo com mapa pendente — aplique as migrations do Supabase)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.existente != null ? "Cadastro atualizado" : "Cadastro concluído"} ($kAmigosGilbertoLabel)$aviso.',
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final munAsync = ref.watch(municipiosMTListProvider);
    return AlertDialog(
      title: Text(
        widget.existente != null
            ? 'Editar — $kAmigosGilbertoLabel'
            : 'Novo cadastro — $kAmigosGilbertoLabel',
      ),
      content: SizedBox(
        width: 440,
        child: munAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro ao carregar cidades: $e'),
          data: (municipios) {
            final apAsync = ref.watch(meuApoiadorProvider);
            final ex = widget.existente;
            if (ex != null && !_postFrameSyncEdicaoAgendado && _cidadeNomeNormalizado == null) {
              _postFrameSyncEdicaoAgendado = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                String? key;
                // Primeiro via municipio_id na lista do banco
                if (ex.municipioId != null) {
                  for (final m in municipios) {
                    if (m.id == ex.municipioId) {
                      key = normalizarNomeMunicipioMT(m.nome);
                      break;
                    }
                  }
                }
                // Fallback: cidade_nome salvo
                if (key == null && ex.cidadeNome != null && ex.cidadeNome!.trim().isNotEmpty) {
                  final tentKey = normalizarNomeMunicipioMT(ex.cidadeNome!);
                  if (listCidadesMTNomesNormalizados.contains(tentKey)) key = tentKey;
                }
                if (key != null && mounted) setState(() => _cidadeNomeNormalizado = key);
              });
            }
            if (profile?.role == 'apoiador' &&
                widget.existente == null &&
                !_apoiadorPadraoCidadeAplicado &&
                !_postFrameDefaultApoiadorAgendado &&
                apAsync.hasValue) {
              _postFrameDefaultApoiadorAgendado = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _apoiadorPadraoCidadeAplicado) return;
                setState(() {
                  _apoiadorPadraoCidadeAplicado = true;
                  final ap = apAsync.valueOrNull;
                  // Tenta via municipio_id → lista carregada
                  final mid = municipioIdResolvidoParaApoiador(ap, municipios);
                  if (mid != null && mid.isNotEmpty) {
                    for (final m in municipios) {
                      if (m.id == mid) {
                        _cidadeNomeNormalizado = normalizarNomeMunicipioMT(m.nome);
                        break;
                      }
                    }
                  }
                  // Fallback: texto de cidade_nome do apoiador (funciona sem municipios no banco)
                  if (_cidadeNomeNormalizado == null && ap?.cidadeNome != null) {
                    final key = normalizarNomeMunicipioMT(ap!.cidadeNome!.trim());
                    if (key.isNotEmpty && listCidadesMTNomesNormalizados.contains(key)) {
                      _cidadeNomeNormalizado = key;
                    }
                  }
                });
              });
            }
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
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        hintText: '(00) 0 0000-0000',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [TelefoneInputFormatter()],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (widget.existente != null) return null;
                        if (v == null || v.trim().isEmpty) {
                          return 'E-mail obrigatório para acessar o painel $kAmigosGilbertoLabel';
                        }
                        final t = v.trim();
                        if (!t.contains('@') || !t.contains('.')) return 'E-mail inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    MunicipioMtFormRow(
                      selectedNormalizedKey: _cidadeNomeNormalizado,
                      errorText: _cidadeErro,
                      label: 'Município (MT) *',
                      onSelected: (k) => setState(() {
                        _cidadeNomeNormalizado = k;
                        _cidadeErro = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _abrangencia,
                      decoration: const InputDecoration(
                        labelText: 'Abrangência',
                        helperText: 'Individual = 1 voto (o próprio). Familiar = total da família.',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Individual', child: Text('Individual')),
                        DropdownMenuItem(value: 'Familiar', child: Text('Familiar')),
                      ],
                      onChanged: (v) {
                        final novo = v ?? 'Individual';
                        setState(() {
                          _abrangencia = novo;
                          if (novo == 'Individual') _qtd.text = '1';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_abrangencia == 'Familiar')
                      TextFormField(
                        controller: _qtd,
                        decoration: const InputDecoration(
                          labelText: 'Total de votos na família (titular + familiares)',
                          hintText: '2',
                          helperText: 'Informe o número total esperado na família, incluindo o próprio.',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 1) return 'Informe ao menos 1 voto';
                          return null;
                        },
                      )
                    else
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Votos',
                          helperText: 'Sempre 1 para cadastro individual.',
                          enabled: false,
                        ),
                        child: const Text('1 (individual)', style: TextStyle(color: Colors.grey)),
                      ),
                    if (widget.existente == null && profile != null) ...[
                      const SizedBox(height: 12),
                      _VinculoCadastroNovoVotante(theme: theme, profile: profile),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Endereço (opcional)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cep,
                      decoration: InputDecoration(
                        labelText: 'CEP',
                        hintText: '00000-000',
                        suffixIcon: _cepLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                        helperText: 'Preenche rua, complemento e cidade (MT) ao concluir o CEP.',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [CepInputFormatter()],
                      onChanged: _onCepDigitado,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _logradouro,
                      decoration: const InputDecoration(labelText: 'Rua / logradouro'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _numero,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _complemento,
                      decoration: const InputDecoration(labelText: 'Complemento'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A cidade alimenta o mapa regional e a estimativa por município.',
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

class _VinculoCadastroNovoVotante extends ConsumerWidget {
  const _VinculoCadastroNovoVotante({
    required this.theme,
    required this.profile,
  });

  final ThemeData theme;
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (profile.role) {
      case 'candidato':
        final nome = profile.fullName?.trim().isNotEmpty == true
            ? profile.fullName!
            : (profile.email ?? 'Candidato');
        return _vinculoCadastroCard(
          theme: theme,
          icon: Icons.how_to_vote_outlined,
          label: 'Cadastro pelo candidato',
          destaque: nome,
          subtitulo:
              'Este cadastro ($kAmigosGilbertoLabel) entra na campanha direto pelo candidato (sem vínculo a apoiador).',
        );
      case 'assessor':
        return ref.watch(meuAssessorRegistroProvider).when(
              data: (a) {
                final nome =
                    a?.nome.trim().isNotEmpty == true ? a!.nome : 'Seu cadastro de assessor';
                return _vinculoCadastroCard(
                  theme: theme,
                  icon: Icons.badge_outlined,
                  label: 'Vinculado ao assessor',
                  destaque: nome,
                  subtitulo:
                      'O cadastro fica na rede como registro do assessor logado. Não é possível alterar aqui.',
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _vinculoCadastroCard(
                theme: theme,
                icon: Icons.badge_outlined,
                label: 'Vinculado ao assessor',
                destaque: 'Assessor',
                subtitulo: 'Cadastro na rede do assessor logado.',
              ),
            );
      case 'votante':
        return _vinculoCadastroCard(
          theme: theme,
          icon: Icons.link_rounded,
          label: 'Cadastro pelo link da campanha',
          destaque: kAmigosGilbertoLabel,
          subtitulo:
              'Ao salvar, você entra na rede do candidato e passa a aparecer na lista de $kAmigosGilbertoLabel do deputado.',
        );
      case 'apoiador':
        return ref.watch(meuApoiadorProvider).when(
              data: (ap) {
                final nome =
                    ap?.nome.trim().isNotEmpty == true ? ap!.nome : 'Seu cadastro de apoiador';
                return _vinculoCadastroCard(
                  theme: theme,
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Vinculado ao seu apoiador',
                  destaque: nome,
                  subtitulo:
                      'Será ligado automaticamente ao seu cadastro de apoiador. Não é possível trocar.',
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _vinculoCadastroCard(
                theme: theme,
                icon: Icons.volunteer_activism_outlined,
                label: 'Vinculado ao apoiador',
                destaque: 'Apoiador',
                subtitulo: 'Vínculo automático ao seu perfil de apoiador.',
              ),
            );
      default:
        return const SizedBox.shrink();
    }
  }
}

Widget _vinculoCadastroCard({
  required ThemeData theme,
  required IconData icon,
  required String label,
  required String destaque,
  required String subtitulo,
}) {
  return Material(
    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  destaque,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitulo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.outline),
          ),
        ],
      ),
    ),
  );
}

