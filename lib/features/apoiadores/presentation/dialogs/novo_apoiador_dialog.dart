import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/cep_br_service.dart';
import '../../../../core/utils/municipio_resolver.dart';
import '../../../../core/widgets/municipio_mt_picker_sheet.dart';
import '../../data/brasil_api_cnpj.dart';
import '../../../mapa/data/mt_municipios_coords.dart';
import '../../providers/apoiadores_provider.dart'
    show apoiadoresListProvider, criarApoiadorProvider, NovoApoiadorParams, NovaBenfeitoriaItem;
import '../utils/apoiadores_form_utils.dart';

class NovoApoiadorDialog extends ConsumerStatefulWidget {
  const NovoApoiadorDialog({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  ConsumerState<NovoApoiadorDialog> createState() => NovoApoiadorDialogState();
}

class NovoApoiadorDialogState extends ConsumerState<NovoApoiadorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nascimentoController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _contatoRespController = TextEditingController();
  final _emailRespController = TextEditingController();
  final _votosPfController = TextEditingController(text: '0');
  final _votosFamiliaController = TextEditingController(text: '0');
  final _votosFuncController = TextEditingController(text: '0');
  final _estimativaController = TextEditingController(text: '0');
  final _qtdFamiliaController = TextEditingController(text: '0');
  final _legadoController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();

  String? _cidadeNome;
  String _tipo = 'PF';
  String? _perfil;
  bool _votosSozinho = true;
  bool _loading = false;
  String? _error;
  bool _cnpjCarregado = false;
  String? _razaoSocial;
  String? _nomeFantasia;
  String? _situacaoCnpj;
  String? _endereco;
  String? _cidadeFromApi;
  final List<_BenfeitoriaForm> _benfeitorias = [];
  final ScrollController _scrollController = ScrollController();
  String? _cidadeErro;
  Timer? _cepDebounce;
  bool _cepLoading = false;

  @override
  void dispose() {
    _cepDebounce?.cancel();
    _scrollController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _nascimentoController.dispose();
    _cnpjController.dispose();
    _contatoRespController.dispose();
    _emailRespController.dispose();
    _votosPfController.dispose();
    _votosFamiliaController.dispose();
    _votosFuncController.dispose();
    _estimativaController.dispose();
    _qtdFamiliaController.dispose();
    _legadoController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    super.dispose();
  }

  int get _estimativaVotos {
    if (_tipo == 'PF') {
      return _votosSozinho ? (int.tryParse(_estimativaController.text) ?? 0) : (int.tryParse(_qtdFamiliaController.text) ?? 0);
    }
    return (int.tryParse(_votosPfController.text) ?? 0) +
        (int.tryParse(_votosFamiliaController.text) ?? 0) +
        (int.tryParse(_votosFuncController.text) ?? 0);
  }

  Future<void> _buscarCnpj() async {
    final cnpj = _cnpjController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cnpj.length != 14) {
      setState(() => _error = 'CNPJ deve ter 14 dígitos.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _cnpjCarregado = false;
    });
    try {
      final dados = await DadosCnpjBrasilApi.buscar(cnpj);
      if (!mounted) return;
      _nomeController.text = dados.razaoSocial;
      setState(() {
        _razaoSocial = dados.razaoSocial;
        _nomeFantasia = dados.nomeFantasia;
        _situacaoCnpj = dados.situacaoCadastral;
        _endereco = dados.enderecoCompleto;
        _cidadeFromApi = dados.municipio;
        if (dados.municipio.isNotEmpty) {
          final porUf = chaveMunicipioMtApartirCepLocalidade(dados.municipio, 'MT');
          final k = normalizarNomeMunicipioMT(dados.municipio);
          final porNome = listCidadesMTNomesNormalizados.contains(k) ? k : null;
          final nova = porUf ?? porNome;
          if (nova != null) {
            _cidadeNome = nova;
            _cidadeErro = null;
          }
        }
        _cnpjCarregado = true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
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

  Future<void> _salvar() async {
    if (_cidadeNome == null || _cidadeNome!.trim().isEmpty) {
      setState(() {
        _error = 'Selecione a cidade.';
        _cidadeErro = 'Selecione a cidade.';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifique os campos obrigatórios e tente novamente.')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        });
      }
      return;
    }
    if (_tipo == 'PJ' && (!_cnpjCarregado || _razaoSocial == null)) {
      setState(() => _error = 'Informe e busque o CNPJ antes de cadastrar.');
      return;
    }
    final telefone = _telefoneController.text.trim();
    final email = _emailController.text.trim();
    if (_tipo == 'PF') {
      final lista = ref.read(apoiadoresListProvider).valueOrNull ?? [];
      final telDig = telefoneSoDigitos(telefone);
      if (telDig.length >= 10) {
        final jaCadastrado = lista.any((a) => telefoneSoDigitos(a.telefone) == telDig);
        if (jaCadastrado) {
          setState(() => _error = 'Este contato já está cadastrado para outro apoiador.');
          return;
        }
      }
      if (email.isNotEmpty) {
        final emailNorm = email.toLowerCase();
        final jaCadastrado = lista.any((a) => (a.email ?? '').trim().toLowerCase() == emailNorm);
        if (jaCadastrado) {
          setState(() => _error = 'Este e-mail já está cadastrado para outro apoiador.');
          return;
        }
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final criar = ref.read(criarApoiadorProvider);
      await criar(NovoApoiadorParams(
        nome: _nomeController.text.trim(),
        cidadeNome: _cidadeNome!,
        tipo: _tipo,
        perfil: _perfil,
        telefone: telefone.isEmpty ? null : telefone,
        email: email.isEmpty ? null : email,
        estimativaVotos: _estimativaVotos,
        dataNascimento: _tipo == 'PF' ? parseDataDDMMYYYY(_nascimentoController.text) : null,
        votosSozinho: _votosSozinho,
        qtdVotosFamilia: _tipo == 'PF' ? (int.tryParse(_qtdFamiliaController.text) ?? 0) : 0,
        cnpj: _tipo == 'PJ' ? _cnpjController.text.replaceAll(RegExp(r'[^\d]'), '') : null,
        razaoSocial: _razaoSocial,
        nomeFantasia: _nomeFantasia,
        situacaoCnpj: _situacaoCnpj,
        endereco: _endereco,
        contatoResponsavel: _contatoRespController.text.trim().isEmpty ? null : _contatoRespController.text.trim(),
        emailResponsavel: _emailRespController.text.trim().isEmpty ? null : _emailRespController.text.trim(),
        votosPf: _tipo == 'PJ' ? (int.tryParse(_votosPfController.text) ?? 0) : 0,
        votosFamilia: _tipo == 'PJ' ? (int.tryParse(_votosFamiliaController.text) ?? 0) : 0,
        votosFuncionarios: _tipo == 'PJ' ? (int.tryParse(_votosFuncController.text) ?? 0) : 0,
        votosPrometidosUltimaEleicao: parseLegado(_legadoController.text),
        benfeitorias: _benfeitorias
            .where((b) => b.titulo.trim().isNotEmpty)
            .map((b) => NovaBenfeitoriaItem(
                  titulo: b.titulo,
                  tipo: b.tipo,
                  valor: b.valor,
                  dataRealizacao: b.data,
                  descricao: b.descricao,
                ))
            .toList(),
        cep: _cepController.text.trim().isEmpty ? null : _cepController.text.trim(),
        logradouro: _logradouroController.text.trim().isEmpty ? null : _logradouroController.text.trim(),
        numero: _numeroController.text.trim().isEmpty ? null : _numeroController.text.trim(),
        complemento: _complementoController.text.trim().isEmpty ? null : _complementoController.text.trim(),
      ));
      if (mounted) {
        widget.onCreate();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _loading = false;
          _error = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Novo Apoiador'),
      content: SizedBox(
        width: 500,
        height: 520,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MunicipioMtFormRow(
                  selectedNormalizedKey: _cidadeNome,
                  errorText: _cidadeErro,
                  onSelected: (k) => setState(() {
                    _cidadeNome = k;
                    _cidadeErro = null;
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'PF', child: Text('Pessoa Física')),
                    DropdownMenuItem(value: 'PJ', child: Text('Pessoa Jurídica (Empresarial)')),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? 'PF'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    labelText: _tipo == 'PJ' ? 'Razão social (preenchido pela busca do CNPJ)' : 'Nome *',
                    hintText: _tipo == 'PF' ? 'Nome completo' : 'Busque o CNPJ para preencher',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),
                if (_tipo == 'PF') ..._buildCamposPF(theme),
                if (_tipo == 'PJ') ..._buildCamposPJ(theme),
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
                _buildSecaoLegado(theme),
                const SizedBox(height: 16),
                _buildSecaoBenfeitorias(theme),
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
          child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cadastrar'),
        ),
      ],
    );
  }

  Future<void> _abrirCalendarioNascimento() async {
    final dataAtual = parseDataDDMMYYYY(_nascimentoController.text) ?? DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: dataAtual.isBefore(DateTime(1900, 1, 1)) || dataAtual.isAfter(DateTime.now()) ? DateTime(1990, 1, 1) : dataAtual,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      _nascimentoController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  List<Widget> _buildCamposPF(ThemeData theme) {
    return [
      TextFormField(
        controller: _nascimentoController,
        inputFormatters: [DataNascimentoInputFormatter()],
        decoration: InputDecoration(
          labelText: 'Data de nascimento',
          hintText: 'DD/MM/AAAA',
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _abrirCalendarioNascimento,
            tooltip: 'Abrir calendário',
          ),
        ),
        keyboardType: TextInputType.datetime,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(labelText: 'E-mail', hintText: 'exemplo@email.com'),
        keyboardType: TextInputType.emailAddress,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          if (!isEmailValido(v)) return 'Informe um e-mail válido.';
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _telefoneController,
        decoration: const InputDecoration(labelText: 'Contato', hintText: '(00) 0 0000-0000'),
        keyboardType: TextInputType.phone,
        inputFormatters: [TelefoneInputFormatter()],
      ),
      const SizedBox(height: 16),
      const Text('Os votos serão apenas dele ou da família?'),
      Row(
        children: [
          Radio<bool>(value: true, groupValue: _votosSozinho, onChanged: (v) => setState(() => _votosSozinho = true)),
          const Text('Só dele'),
          Radio<bool>(value: false, groupValue: _votosSozinho, onChanged: (v) => setState(() => _votosSozinho = false)),
          const Text('Da família'),
        ],
      ),
      if (!_votosSozinho) ...[
        TextFormField(
          controller: _qtdFamiliaController,
          decoration: const InputDecoration(labelText: 'Quantidade de votos (família)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
      ],
      if (_votosSozinho)
        TextFormField(
          controller: _estimativaController,
          decoration: const InputDecoration(labelText: 'Votos estimados'),
          keyboardType: TextInputType.number,
        ),
    ];
  }

  List<Widget> _buildCamposPJ(ThemeData theme) {
    return [
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _cnpjController,
              decoration: const InputDecoration(labelText: 'CNPJ *', hintText: '00.000.000/0001-00'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _cnpjCarregado = false),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _loading ? null : _buscarCnpj,
            child: const Text('Buscar'),
          ),
        ],
      ),
      if (_cnpjCarregado && _razaoSocial != null) ...[
        const SizedBox(height: 12),
        Text('Razão social: $_razaoSocial', style: theme.textTheme.bodyMedium),
        if (_nomeFantasia != null && _nomeFantasia!.isNotEmpty) Text('Nome fantasia: $_nomeFantasia', style: theme.textTheme.bodySmall),
        Text('Situação: $_situacaoCnpj', style: theme.textTheme.bodySmall),
        if (_endereco != null) Text('Endereço: $_endereco', style: theme.textTheme.bodySmall),
        if (_cidadeFromApi != null) Text('Cidade: $_cidadeFromApi', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
      TextFormField(
        controller: _contatoRespController,
        decoration: const InputDecoration(labelText: 'Contato do responsável *'),
        keyboardType: TextInputType.phone,
        validator: (v) {
          if (_tipo != 'PJ') return null;
          return (v == null || v.trim().isEmpty) ? 'Informe o contato do responsável' : null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailRespController,
        decoration: const InputDecoration(labelText: 'E-mail do responsável *'),
        keyboardType: TextInputType.emailAddress,
        validator: (v) {
          if (_tipo != 'PJ') return null;
          return (v == null || v.trim().isEmpty) ? 'Informe o e-mail do responsável' : null;
        },
      ),
      const SizedBox(height: 16),
      const Text('Votos em pessoa física (responsável):'),
      TextFormField(
        controller: _votosPfController,
        decoration: const InputDecoration(hintText: '0'),
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 8),
      const Text('Estende para família? Quantos com a família:'),
      TextFormField(
        controller: _votosFamiliaController,
        decoration: const InputDecoration(hintText: '0'),
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 8),
      const Text('Votos de funcionários (empresa):'),
      TextFormField(
        controller: _votosFuncController,
        decoration: const InputDecoration(hintText: '0'),
        keyboardType: TextInputType.number,
      ),
    ];
  }

  Widget _buildSecaoLegado(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Legado (última eleição)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        TextFormField(
          controller: _legadoController,
          decoration: const InputDecoration(
            labelText: 'Votos prometidos na última eleição',
            hintText: 'Opcional',
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  void _adicionarBenfeitoria() {
    setState(() => _benfeitorias.add(_BenfeitoriaForm()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildSecaoBenfeitorias(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Benfeitorias', style: theme.textTheme.titleSmall),
            FilledButton.tonalIcon(
              onPressed: _adicionarBenfeitoria,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_benfeitorias.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BenfeitoriaTile(
              form: _benfeitorias[i],
              tipos: tiposBenfeitoriaLista,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _benfeitorias.removeAt(i)),
            ),
          );
        }),
      ],
    );
  }
}

class _BenfeitoriaForm {
  String titulo = '';
  String tipo = 'Outro';
  String descricao = '';
  double valor = 0;
  DateTime? data;
}

class _BenfeitoriaTile extends StatelessWidget {
  const _BenfeitoriaTile({
    required this.form,
    required this.tipos,
    required this.onChanged,
    required this.onRemove,
  });

  final _BenfeitoriaForm form;
  final List<(String, String)> tipos;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

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
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'O que foi feito', hintText: 'Obra, manutenção, ajuda de custo...'),
                    onChanged: (v) {
                      form.titulo = v;
                      onChanged();
                    },
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: form.tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: tipos.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
              onChanged: (v) {
                if (v != null) {
                  form.tipo = v;
                  onChanged();
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0.000,00'),
              keyboardType: TextInputType.number,
              inputFormatters: [ValorRealInputFormatter()],
              onChanged: (v) {
                form.valor = parseValorReal(v);
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Data (DD/MM/AAAA)', hintText: 'DD/MM/AAAA'),
              inputFormatters: [DataNascimentoInputFormatter()],
              onChanged: (v) {
                form.data = parseDataDDMMYYYY(v);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

