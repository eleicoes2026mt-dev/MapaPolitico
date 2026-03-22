import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../core/widgets/convite_link_dialog.dart';
import '../../../models/apoiador.dart';
import '../../mapa/data/mt_municipios_coords.dart';
import '../../auth/providers/auth_provider.dart' show profileProvider;
import '../data/brasil_api_cnpj.dart';
import '../providers/apoiadores_provider.dart'
    show
        apoiadoresListProvider,
        criarApoiadorProvider,
        atualizarApoiadorProvider,
        NovoApoiadorParams,
        NovaBenfeitoriaItem,
        AtualizarApoiadorParams,
        convidarApoiadorPorEmail,
        reenviarConviteApoiador;

/// Parse de data no padrão dd/MM/yyyy; retorna null se inválido.
/// Aceita "15/04/1992" ou "15041992" (8 dígitos).
DateTime? _parseDataDDMMYYYY(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  var s = text.trim().replaceAll(RegExp(r'[^\d]'), '');
  if (s.length == 8) s = '${s.substring(0, 2)}/${s.substring(2, 4)}/${s.substring(4)}';
  if (s.length != 10) return null;
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(s);
  } catch (_) {
    return null;
  }
}

/// Formata data ao digitar: dd/MM/yyyy.
class _DataNascimentoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 8) return oldValue;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Formata telefone ao digitar: (00) 0 0000-0000 (11 dígitos: DDD + 9 + 8).
class _TelefoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 11) return oldValue;
    if (digits.isEmpty) return newValue;
    String s;
    if (digits.length <= 2) {
      s = digits.length == 0 ? '' : '($digits';
    } else if (digits.length <= 7) {
      s = '(${digits.substring(0, 2)}) ${digits[2]} ${digits.substring(3)}';
    } else {
      s = '(${digits.substring(0, 2)}) ${digits[2]} ${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Retorna só os dígitos do telefone (para comparação/banco).
String _telefoneSoDigitos(String? s) => (s ?? '').replaceAll(RegExp(r'[^\d]'), '');

/// Formata valor ao digitar no padrão Real: 0.000,00 (milhar com ponto, decimal com vírgula).
class _ValorRealFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text.replaceAll(RegExp(r'[^\d,]'), '');
    final commaIndex = t.indexOf(',');
    final onlyOneComma = commaIndex == -1 || commaIndex == t.lastIndexOf(',');
    if (!onlyOneComma) return oldValue;
    String intPart = commaIndex <= 0 ? t : t.substring(0, commaIndex);
    String decPart = commaIndex < 0 ? '' : t.substring(commaIndex + 1);
    if (decPart.length > 2) decPart = decPart.substring(0, 2);
    intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
    if (intPart.isEmpty) intPart = '0';
    var intFormatted = '';
    for (var i = intPart.length; i > 0; i -= 3) {
      final start = (i - 3).clamp(0, intPart.length);
      final chunk = intPart.substring(start, i);
      intFormatted = intFormatted.isEmpty ? chunk : '$chunk.$intFormatted';
    }
    final decPadded = decPart.padRight(2, '0');
    final s = decPart.isEmpty && commaIndex < 0
        ? intFormatted
        : '$intFormatted,$decPadded';
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Parse de valor no formato Real (1.500,00) para double.
double _parseValorReal(String? text) {
  if (text == null || text.trim().isEmpty) return 0;
  final n = text.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(n) ?? 0;
}

/// Retorna votos prometidos (legado) ou null se vazio/inválido.
int? _parseLegado(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final n = int.tryParse(text.trim());
  return n != null && n >= 0 ? n : null;
}

/// Regex para e-mail válido.
final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);
bool _isEmailValido(String? s) => s != null && s.trim().isNotEmpty && _emailRegex.hasMatch(s.trim());

/// E-mail para convite (PF: email; PJ: e-mail do responsável).
String? _emailParaConviteApoiador(Apoiador a) {
  for (final cand in [a.email, a.emailResponsavel]) {
    final s = cand?.trim() ?? '';
    if (s.isNotEmpty && _emailRegex.hasMatch(s)) return s;
  }
  return null;
}

const _perfisOpcoes = ['Prefeitural', 'Vereador(a)', 'Líder Religional', 'Empresarial'];

const _tiposBenfeitoria = [
  ('Obra', 'Obra'),
  ('Manutencao', 'Manutenção'),
  ('Ajuda_de_custo', 'Ajuda de custo'),
  ('Reforma', 'Reforma'),
  ('Doação', 'Doação'),
  ('Evento', 'Evento'),
  ('Outro', 'Outro'),
];

class ApoiadoresScreen extends ConsumerStatefulWidget {
  const ApoiadoresScreen({super.key});

  @override
  ConsumerState<ApoiadoresScreen> createState() => _ApoiadoresScreenState();
}

class _ApoiadoresScreenState extends ConsumerState<ApoiadoresScreen> {
  String _query = '';
  String _perfilFilter = 'Todos os Perfis';

  Future<void> _abrirNovoApoiador() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _NovoApoiadorDialog(
        onCreate: () {
          ref.invalidate(apoiadoresListProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final ehApoiador = profile?.role == 'apoiador';
    final list = ref.watch(apoiadoresListProvider);
    var filtered = list.valueOrNull ?? [];
    if (_query.isNotEmpty) {
      filtered = filtered.where((a) => a.nome.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    if (_perfilFilter != 'Todos os Perfis') {
      filtered = filtered.where((a) => a.perfil == _perfilFilter).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Apoiadores', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar apoiador...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _perfilFilter,
                items: ['Todos os Perfis', ..._perfisOpcoes].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _perfilFilter = v ?? 'Todos os Perfis'),
              ),
              const SizedBox(width: 12),
              if (!ehApoiador)
                FilledButton.icon(
                  onPressed: _abrirNovoApoiador,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Apoiador'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          list.when(
            data: (_) {
              final podeEditar =
                  profile?.role == 'candidato' || profile?.role == 'assessor' || profile?.role == 'apoiador';
              return LayoutBuilder(
                builder: (_, c) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: filtered.map((a) => _ApoiadorCard(apoiador: a, podeEditar: podeEditar, onRefresh: () => ref.invalidate(apoiadoresListProvider))).toList(),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    );
  }
}

class _NovoApoiadorDialog extends ConsumerStatefulWidget {
  const _NovoApoiadorDialog({required this.onCreate});

  final VoidCallback onCreate;

  @override
  ConsumerState<_NovoApoiadorDialog> createState() => _NovoApoiadorDialogState();
}

class _NovoApoiadorDialogState extends ConsumerState<_NovoApoiadorDialog> {
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

  @override
  void dispose() {
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
        _cidadeNome = dados.municipio.isNotEmpty ? dados.municipio : _cidadeNome;
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

  Future<void> _salvar() async {
    if (_cidadeNome == null || _cidadeNome!.trim().isEmpty) {
      setState(() => _error = 'Selecione a cidade.');
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
      final telDig = _telefoneSoDigitos(telefone);
      if (telDig.length >= 10) {
        final jaCadastrado = lista.any((a) => _telefoneSoDigitos(a.telefone) == telDig);
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
        dataNascimento: _tipo == 'PF' ? _parseDataDDMMYYYY(_nascimentoController.text) : null,
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
        votosPrometidosUltimaEleicao: _parseLegado(_legadoController.text),
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
    final cidades = listCidadesMTNomesNormalizados.toList();
    if (_cidadeNome != null && _cidadeNome!.isNotEmpty && !cidades.contains(_cidadeNome)) cidades.add(_cidadeNome!);

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
                DropdownButtonFormField<String>(
                  value: _cidadeNome,
                  decoration: const InputDecoration(labelText: 'Cidade *'),
                  hint: const Text('Selecione a cidade'),
                  items: cidades.map((c) => DropdownMenuItem(value: c, child: Text(displayNomeCidadeMT(c)))).toList(),
                  onChanged: (v) => setState(() => _cidadeNome = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Selecione a cidade' : null,
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
    final dataAtual = _parseDataDDMMYYYY(_nascimentoController.text) ?? DateTime(1990, 1, 1);
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
        inputFormatters: [_DataNascimentoFormatter()],
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
          if (!_isEmailValido(v)) return 'Informe um e-mail válido.';
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _telefoneController,
        decoration: const InputDecoration(labelText: 'Contato', hintText: '(00) 0 0000-0000'),
        keyboardType: TextInputType.phone,
        inputFormatters: [_TelefoneFormatter()],
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
              tipos: _tiposBenfeitoria,
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
              inputFormatters: [_ValorRealFormatter()],
              onChanged: (v) {
                form.valor = _parseValorReal(v);
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Data (DD/MM/AAAA)', hintText: 'DD/MM/AAAA'),
              inputFormatters: [_DataNascimentoFormatter()],
              onChanged: (v) {
                form.data = _parseDataDDMMYYYY(v);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApoiadorCard extends ConsumerWidget {
  const _ApoiadorCard({required this.apoiador, required this.podeEditar, required this.onRefresh});

  final Apoiador apoiador;
  final bool podeEditar;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width > 800 ? 380.0 : double.infinity;
    final cidadeDisplay = apoiador.cidadeNome != null ? displayNomeCidadeMT(apoiador.cidadeNome!) : null;
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeConvidarEquipe = profile?.role == 'candidato' || profile?.role == 'assessor';
    final emailConvite = _emailParaConviteApoiador(apoiador);
    final mostrarConvite = podeConvidarEquipe && apoiador.profileId == null && emailConvite != null;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: apoiador.isPJ ? Colors.purple.shade100 : Colors.green.shade100,
                    child: apoiador.isPJ
                        ? Icon(Icons.business, color: Colors.purple.shade700)
                        : Text(apoiador.initial, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(apoiador.nome, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (apoiador.perfil != null)
                          Chip(
                            label: Text(apoiador.perfil!, style: theme.textTheme.labelSmall),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (cidadeDisplay != null)
                          Text(cidadeDisplay, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                  if (mostrarConvite) ...[
                    IconButton(
                      icon: const Icon(Icons.mark_email_read_outlined),
                      tooltip: 'Convidar por e-mail (acesso ao app)',
                      onPressed: () async {
                        try {
                          final link = await convidarApoiadorPorEmail(apoiadorId: apoiador.id);
                          onRefresh();
                          if (!context.mounted) return;
                          if (link != null && link.isNotEmpty) {
                            await showConviteLinkDialog(
                              context,
                              link: link,
                              title: 'Link de acesso do apoiador',
                              description:
                                  'O convite também foi enviado por e-mail. Copie o link e envie pelo WhatsApp se a mensagem não chegar. Com o acesso, o apoiador cadastra votantes que aparecem no mapa.',
                              snackbarMessage: 'Link copiado.',
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Convite enviado por e-mail. Se não chegar, confira spam ou reenvie e use o link copiável quando aparecer.',
                                ),
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      tooltip: 'Reenviar convite',
                      onPressed: () async {
                        try {
                          final link = await reenviarConviteApoiador(apoiadorId: apoiador.id);
                          if (!context.mounted) return;
                          if (link != null && link.isNotEmpty) {
                            await showConviteLinkDialog(
                              context,
                              link: link,
                              title: 'Link de convite (reenvio)',
                              description: 'Copie e envie pelo WhatsApp se o e-mail não chegar.',
                              snackbarMessage: 'Link copiado.',
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Convite reenviado por e-mail.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                  if (podeEditar)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _abrirEditar(context),
                      tooltip: 'Editar apoiador',
                    ),
                ],
              ),
              if (apoiador.telefone != null) ...[
                const SizedBox(height: 8),
                Row(children: [Icon(Icons.phone, size: 18, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 8), Text(apoiador.telefone!, style: theme.textTheme.bodySmall)]),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '~${apoiador.estimativaVotos} votos estimados',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (apoiador.votosPrometidosUltimaEleicao != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.history, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Legado: ${apoiador.votosPrometidosUltimaEleicao} votos prometidos (última eleição)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirEditar(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditarApoiadorDialog(apoiador: apoiador, onSaved: onRefresh),
    );
  }
}

class _EditarApoiadorDialog extends ConsumerStatefulWidget {
  const _EditarApoiadorDialog({required this.apoiador, required this.onSaved});

  final Apoiador apoiador;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditarApoiadorDialog> createState() => _EditarApoiadorDialogState();
}

class _EditarApoiadorDialogState extends ConsumerState<_EditarApoiadorDialog> {
  late final TextEditingController _nomeController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _estimativaController;
  late final TextEditingController _legadoController;
  late String? _cidadeNome;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

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
    _cidadeNome = widget.apoiador.cidadeNome;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _estimativaController.dispose();
    _legadoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final atualizar = ref.read(atualizarApoiadorProvider);
      await atualizar(
        widget.apoiador.id,
        AtualizarApoiadorParams(
          nome: _nomeController.text.trim(),
          cidadeNome: _cidadeNome?.trim().isEmpty == true ? null : _cidadeNome?.trim(),
          telefone: _telefoneController.text.trim().isEmpty ? null : _telefoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          estimativaVotos: int.tryParse(_estimativaController.text) ?? 0,
          votosPrometidosUltimaEleicao: _parseLegado(_legadoController.text),
          atualizarLegado: true,
        ),
      );
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
    final cidades = listCidadesMTNomesNormalizados.toList();
    if (_cidadeNome != null && _cidadeNome!.isNotEmpty && !cidades.contains(_cidadeNome)) cidades.add(_cidadeNome!);
    return AlertDialog(
      title: const Text('Editar Apoiador'),
      content: SizedBox(
        width: 400,
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
                DropdownButtonFormField<String>(
                  value: _cidadeNome,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                  items: cidades.map((c) => DropdownMenuItem(value: c, child: Text(displayNomeCidadeMT(c)))).toList(),
                  onChanged: (v) => setState(() => _cidadeNome = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefoneController,
                  decoration: const InputDecoration(labelText: 'Contato', hintText: '(00) 0 0000-0000'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_TelefoneFormatter()],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!_isEmailValido(v)) return 'E-mail inválido.';
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
                TextFormField(
                  controller: _legadoController,
                  decoration: const InputDecoration(
                    labelText: 'Legado: votos prometidos na última eleição',
                    hintText: 'Opcional',
                  ),
                  keyboardType: TextInputType.number,
                ),
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
