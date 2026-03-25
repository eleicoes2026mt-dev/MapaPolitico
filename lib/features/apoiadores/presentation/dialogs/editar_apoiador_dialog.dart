import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/municipio_resolver.dart';
import '../../../../models/apoiador.dart';
import '../../../mapa/data/mt_municipios_coords.dart';
import '../../../votantes/providers/votantes_provider.dart' show refreshMunicipiosMTList;
import '../../providers/apoiadores_provider.dart' show atualizarApoiadorProvider, AtualizarApoiadorParams;
import '../utils/apoiadores_form_utils.dart';

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

  @override
  void dispose() {
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

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
    if (_cidadeNome != null && _cidadeNome!.isNotEmpty && !cidades.contains(_cidadeNome)) {
      cidades.add(_cidadeNome!);
    }
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
                  decoration: const InputDecoration(labelText: 'CEP'),
                  keyboardType: TextInputType.number,
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
