import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/apoiador.dart';
import '../providers/apoiadores_provider.dart';

const _perfisOpcoes = ['Prefeitural', 'Vereador(a)', 'Líder Religional', 'Empresarial'];

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
        onCreate: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              FilledButton.icon(
                onPressed: _abrirNovoApoiador,
                icon: const Icon(Icons.add),
                label: const Text('Novo Apoiador'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          list.when(
            data: (_) => LayoutBuilder(
              builder: (_, c) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filtered.map((a) => _ApoiadorCard(apoiador: a)).toList(),
                );
              },
            ),
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
  final _estimativaController = TextEditingController(text: '0');
  String _tipo = 'PF';
  String? _perfil;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _estimativaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final criar = ref.read(criarApoiadorProvider);
      await criar(NovoApoiadorParams(
        nome: _nomeController.text,
        tipo: _tipo,
        perfil: _perfil,
        telefone: _telefoneController.text.isEmpty ? null : _telefoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        estimativaVotos: int.tryParse(_estimativaController.text) ?? 0,
      ));
      widget.onCreate();
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

    return AlertDialog(
      title: const Text('Novo Apoiador'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  hintText: 'Nome completo ou razão social',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'PF', child: Text('Pessoa Física')),
                  DropdownMenuItem(value: 'PJ', child: Text('Pessoa Jurídica')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'PF'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _perfil,
                decoration: const InputDecoration(labelText: 'Perfil (opcional)'),
                items: [const DropdownMenuItem<String?>(value: null, child: Text('Nenhum')), ..._perfisOpcoes.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s)))],
                onChanged: (v) => setState(() => _perfil = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone (opcional)', hintText: '(65) 99999-9999'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estimativaController,
                decoration: const InputDecoration(labelText: 'Votos estimados'),
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
}

class _ApoiadorCard extends StatelessWidget {
  const _ApoiadorCard({required this.apoiador});

  final Apoiador apoiador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width > 800 ? 380.0 : double.infinity;
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
                      ],
                    ),
                  ),
                ],
              ),
              if (apoiador.telefone != null) ...[
                const SizedBox(height: 8),
                Row(children: [Icon(Icons.phone, size: 18, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 8), Text(apoiador.telefone!, style: theme.textTheme.bodySmall)]),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.people, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('~${apoiador.estimativaVotos} votos estimados', style: theme.textTheme.bodySmall),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
