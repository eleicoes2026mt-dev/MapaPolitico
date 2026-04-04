import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/cep_br_service.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/utils/municipio_resolver.dart';
import '../../../../core/widgets/municipio_mt_picker_sheet.dart';
import '../../../../models/apoiador.dart';
import '../../../../models/benfeitoria.dart';
import '../../../../models/municipio.dart';
import '../../../benfeitorias/providers/benfeitorias_provider.dart';
import '../../../mapa/data/mt_municipios_coords.dart';
import '../../../votantes/providers/votantes_provider.dart' show refreshMunicipiosMTList, municipiosMTListProvider;
import '../../providers/apoiadores_provider.dart' show atualizarApoiadorProvider, AtualizarApoiadorParams;
import '../utils/apoiadores_form_utils.dart';

const _statusBenfeitoriaOpcoes = <(String, String)>[
  ('em_andamento', 'Em andamento'),
  ('concluida', 'Concluída'),
  ('planejada', 'Planejada'),
];

class EditarApoiadorDialog extends ConsumerStatefulWidget {
  const EditarApoiadorDialog({super.key, required this.apoiador, required this.onSaved});

  final Apoiador apoiador;
  final VoidCallback onSaved;

  @override
  ConsumerState<EditarApoiadorDialog> createState() => _EditarApoiadorDialogState();
}

class _EditarApoiadorDialogState extends ConsumerState<EditarApoiadorDialog> {
  late final TextEditingController _nomeController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _estimativaController;
  late final TextEditingController _legadoController;
  late final TextEditingController _cepController;
  late final TextEditingController _logradouroController;
  late final TextEditingController _numeroController;
  late final TextEditingController _complementoController;
  late String? _cidadeNome;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  String? _cidadeErro;
  Timer? _cepDebounce;
  bool _cepLoading = false;

  List<_BenfEditForm>? _benfForms;
  bool _benfInited = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.apoiador.nome);
    _telefoneController = TextEditingController(text: widget.apoiador.telefone ?? '');
    _emailController = TextEditingController(text: widget.apoiador.email ?? '');
    _estimativaController = TextEditingController(text: widget.apoiador.estimativaVotos.toString());
    _legadoController = TextEditingController(
      text: widget.apoiador.votosPrometidosUltimaEleicao != null ? widget.apoiador.votosPrometidosUltimaEleicao.toString() : '',
    );
    _cepController = TextEditingController(text: widget.apoiador.cep ?? '');
    _logradouroController = TextEditingController(text: widget.apoiador.logradouro ?? '');
    _numeroController = TextEditingController(text: widget.apoiador.numero ?? '');
    _complementoController = TextEditingController(text: widget.apoiador.complemento ?? '');
    _cidadeNome = widget.apoiador.cidadeNome;
  }

  void _onCepChanged(String _) {
    _cepDebounce?.cancel();
    final d = cepSoDigitos(_cepController.text);
    if (d.length != 8) return;
    _cepDebounce = Timer(const Duration(milliseconds: 450), _buscarCep);
  }

  Future<void> _buscarCep() async {
    if (!mounted) return;
    final d = cepSoDigitos(_cepController.text);
    if (d.length != 8) return;
    setState(() => _cepLoading = true);
    try {
      final r = await fetchCepBr(d);
      if (!mounted || r == null) return;
      setState(() {
        if (r.logradouro.trim().isNotEmpty) {
          _logradouroController.text = r.logradouro.trim();
        }
        final comp = r.complemento?.trim();
        final bairro = r.bairro?.trim();
        if (_complementoController.text.trim().isEmpty) {
          if (comp != null && comp.isNotEmpty) {
            _complementoController.text = comp;
          } else if (bairro != null && bairro.isNotEmpty) {
            _complementoController.text = bairro;
          }
        }
        final chave = chaveMunicipioMtApartirCepLocalidade(r.localidade, r.uf);
        if (chave != null) {
          _cidadeNome = chave;
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
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _estimativaController.dispose();
    _legadoController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    super.dispose();
  }

  String? _chaveCidadePadraoBenfeitoria() {
    final n = widget.apoiador.cidadeNome?.trim();
    if (n == null || n.isEmpty) return null;
    return normalizarNomeMunicipioMT(n);
  }

  void _adicionarBenfeitoria() {
    setState(() {
      _benfForms ??= [];
      _benfForms!.add(_BenfEditForm.nova(cidadePadraoKey: _chaveCidadePadraoBenfeitoria()));
    });
  }

  Future<void> _sincronizarBenfeitorias(String apoiadorId, String? municipioPadraoId, List<Municipio> municipios) async {
    final forms = _benfForms ?? [];
    final existing = await ref.read(benfeitoriasPorApoiadorProvider(apoiadorId).future);
    final idsNaLista = forms.map((f) => f.id).whereType<String>().toSet();
    for (final b in existing) {
      if (!idsNaLista.contains(b.id)) {
        await supabase.from('benfeitorias').delete().eq('id', b.id);
      }
    }
    for (final f in forms) {
      final titulo = f.titulo.trim();
      if (titulo.isEmpty) continue;
      final mid = (f.cidadeKey != null && f.cidadeKey!.trim().isNotEmpty)
          ? municipioIdParaNomeCidade(f.cidadeKey!, municipios)
          : municipioPadraoId;
      final row = <String, dynamic>{
        'apoiador_id': apoiadorId,
        'titulo': titulo,
        'tipo': f.tipo,
        'valor': f.valor,
        'descricao': f.descricao.trim().isEmpty ? null : f.descricao.trim(),
        'data_realizacao': f.data?.toIso8601String().split('T').first,
        'status': f.status,
        'municipio_id': mid,
      };
      if (f.id == null) {
        await supabase.from('benfeitorias').insert(row);
      } else {
        await supabase.from('benfeitorias').update(row).eq('id', f.id!);
      }
    }
  }

  Future<void> _salvar() async {
    if (_cidadeNome == null || _cidadeNome!.trim().isEmpty) {
      setState(() => _cidadeErro = 'Selecione a cidade.');
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cidadeNome == null || _cidadeNome!.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final municipios = await refreshMunicipiosMTList(ref);
      final mid = municipioIdParaNomeCidade(_cidadeNome, municipios);
      final atualizar = ref.read(atualizarApoiadorProvider);
      await atualizar(
        widget.apoiador.id,
        AtualizarApoiadorParams(
          nome: _nomeController.text.trim(),
          cidadeNome: _cidadeNome?.trim().isEmpty == true ? null : _cidadeNome?.trim(),
          municipioId: mid,
          telefone: _telefoneController.text.trim().isEmpty ? null : _telefoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          estimativaVotos: int.tryParse(_estimativaController.text) ?? 0,
          votosPrometidosUltimaEleicao: parseLegado(_legadoController.text),
          atualizarLegado: true,
          atualizarEndereco: true,
          cep: _cepController.text.trim(),
          logradouro: _logradouroController.text.trim(),
          numero: _numeroController.text.trim(),
          complemento: _complementoController.text.trim(),
        ),
      );
      await _sincronizarBenfeitorias(widget.apoiador.id, mid, municipios);
      invalidateBenfeitoriasCaches(ref, apoiadorId: widget.apoiador.id);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final benfAsync = ref.watch(benfeitoriasPorApoiadorProvider(widget.apoiador.id));
    final munAsync = ref.watch(municipiosMTListProvider);

    if (!_benfInited) {
      final list = benfAsync.asData?.value;
      final munList = munAsync.asData?.value;
      if (list != null && munList != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _benfInited) return;
          final idToKey = {for (final m in munList) m.id: m.nomeNormalizado};
          setState(() {
            _benfForms = list.map((b) => _BenfEditForm.fromBenfeitoria(b, idToKey)).toList();
            _benfInited = true;
          });
        });
      }
    }

    return AlertDialog(
      title: const Text('Editar Apoiador'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),
                MunicipioMtFormRow(
                  selectedNormalizedKey: _cidadeNome,
                  errorText: _cidadeErro,
                  onSelected: (k) => setState(() {
                    _cidadeNome = k;
                    _cidadeErro = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefoneController,
                  decoration: const InputDecoration(labelText: 'Contato', hintText: '(00) 0 0000-0000'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [TelefoneInputFormatter()],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!isEmailValido(v)) return 'E-mail inválido.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _estimativaController,
                  decoration: const InputDecoration(labelText: 'Votos estimados'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Text('Endereço (opcional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cepController,
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
                    helperText: 'Preenche endereço e cidade (MT) ao concluir os 8 dígitos.',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [CepInputFormatter()],
                  onChanged: _onCepChanged,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _logradouroController,
                  decoration: const InputDecoration(labelText: 'Rua / logradouro'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _numeroController,
                  decoration: const InputDecoration(labelText: 'Número'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _complementoController,
                  decoration: const InputDecoration(labelText: 'Complemento'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _legadoController,
                  decoration: const InputDecoration(
                    labelText: 'Legado: votos prometidos na última eleição',
                    hintText: 'Opcional',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Text('Benfeitorias', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Informe o município de cada benfeitoria para somar no mapa regional. Se não escolher, usa a cidade do apoiador.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                if (benfAsync.isLoading || munAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (benfAsync.hasError)
                  Text(
                    'Não foi possível carregar benfeitorias.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _adicionarBenfeitoria,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Adicionar benfeitoria'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_benfForms?.length ?? 0, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BenfeitoriaEditarTile(
                        form: _benfForms![i],
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _benfForms!.removeAt(i)),
                      ),
                    );
                  }),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _salvar,
          child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _BenfEditForm {
  _BenfEditForm({
    this.id,
    required this.titulo,
    required this.tipo,
    required this.valor,
    this.data,
    required this.descricao,
    required this.status,
    this.cidadeKey,
  });

  factory _BenfEditForm.fromBenfeitoria(Benfeitoria b, Map<String, String> municipioIdParaChave) {
    return _BenfEditForm(
      id: b.id,
      titulo: b.titulo,
      tipo: b.tipo,
      valor: b.valor,
      data: b.dataRealizacao,
      descricao: b.descricao ?? '',
      status: b.status,
      cidadeKey: b.municipioId != null ? municipioIdParaChave[b.municipioId] : null,
    );
  }

  factory _BenfEditForm.nova({String? cidadePadraoKey}) => _BenfEditForm(
        titulo: '',
        tipo: 'Outro',
        valor: 0,
        descricao: '',
        status: 'concluida',
        cidadeKey: cidadePadraoKey,
      );

  String? id;
  String titulo;
  String tipo;
  double valor;
  DateTime? data;
  String descricao;
  String status;
  String? cidadeKey;
}

class _BenfeitoriaEditarTile extends StatelessWidget {
  const _BenfeitoriaEditarTile({
    required this.form,
    required this.onChanged,
    required this.onRemove,
  });

  final _BenfEditForm form;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  String _dataText() {
    final d = form.data;
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _valorText() {
    if (form.valor == 0) return '0,00';
    final s = form.valor.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0];
    final dec = parts.length > 1 ? parts[1] : '00';
    final buf = StringBuffer();
    for (var i = 0; i < intP.length; i++) {
      if (i > 0 && (intP.length - i) % 3 == 0) buf.write('.');
      buf.write(intP[i]);
    }
    return '$buf,$dec';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: form.titulo,
                    decoration: const InputDecoration(
                      labelText: 'O que foi feito *',
                      hintText: 'Obra, manutenção, ajuda de custo...',
                    ),
                    onChanged: (v) {
                      form.titulo = v;
                      onChanged();
                    },
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: onRemove, tooltip: 'Remover'),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final k = await showMunicipioMtPicker(context, currentNormalizedKey: form.cidadeKey);
                if (k != null) {
                  form.cidadeKey = k;
                  onChanged();
                }
              },
              icon: const Icon(Icons.place_outlined, size: 18),
              label: Text(
                form.cidadeKey == null ? 'Município (usa cidade do apoiador se vazio)' : displayNomeCidadeMT(form.cidadeKey!),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: form.tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: tiposBenfeitoriaLista.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
              onChanged: (v) {
                if (v != null) {
                  form.tipo = v;
                  onChanged();
                }
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _statusBenfeitoriaOpcoes.any((e) => e.$1 == form.status) ? form.status : 'em_andamento',
              decoration: const InputDecoration(labelText: 'Status'),
              items: _statusBenfeitoriaOpcoes.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
              onChanged: (v) {
                if (v != null) {
                  form.status = v;
                  onChanged();
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _valorText(),
              decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0.000,00'),
              keyboardType: TextInputType.number,
              inputFormatters: [ValorRealInputFormatter()],
              onChanged: (v) {
                form.valor = parseValorReal(v);
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _dataText(),
              decoration: const InputDecoration(labelText: 'Data (DD/MM/AAAA)', hintText: 'DD/MM/AAAA'),
              inputFormatters: [DataNascimentoInputFormatter()],
              onChanged: (v) {
                form.data = parseDataDDMMYYYY(v);
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: form.descricao,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              maxLines: 2,
              onChanged: (v) {
                form.descricao = v;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
