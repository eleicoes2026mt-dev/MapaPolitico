import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/amigos_gilberto.dart';
import '../../../../core/services/cep_br_service.dart';
import '../../../../core/utils/municipio_resolver.dart' show chaveMunicipioMtApartirCepLocalidade;
import '../../../../core/widgets/municipio_mt_picker_sheet.dart';
import '../../../apoiadores/presentation/utils/apoiadores_form_utils.dart'
    show CepInputFormatter, TelefoneInputFormatter, cepSoDigitos;

/// Campos de dados (nome, contacto, município, abrangência, endereço) alinhados ao
/// formulário «Novo cadastro — Amigos do Gilberto» do painel.
class AmigosGilbertoDadosFormFields extends ConsumerStatefulWidget {
  const AmigosGilbertoDadosFormFields({
    super.key,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.qtd,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.complemento,
    required this.selectedCidadeKey,
    required this.onCidadeSelected,
    this.cidadeErro,
    required this.abrangencia,
    required this.onAbrangenciaChanged,
    this.emailValidator,
    this.footerWidget,
  });

  final TextEditingController nome;
  final TextEditingController telefone;
  final TextEditingController email;
  final TextEditingController qtd;
  final TextEditingController cep;
  final TextEditingController logradouro;
  final TextEditingController numero;
  final TextEditingController complemento;

  final String? selectedCidadeKey;
  final ValueChanged<String?> onCidadeSelected;
  final String? cidadeErro;

  final String abrangencia;
  final ValueChanged<String> onAbrangenciaChanged;

  final String? Function(String?)? emailValidator;

  /// Ex.: cartão «Cadastro pelo candidato» ou texto do link público.
  final Widget? footerWidget;

  @override
  ConsumerState<AmigosGilbertoDadosFormFields> createState() => _AmigosGilbertoDadosFormFieldsState();
}

class _AmigosGilbertoDadosFormFieldsState extends ConsumerState<AmigosGilbertoDadosFormFields> {
  Timer? _cepDebounce;
  bool _cepLoading = false;

  @override
  void dispose() {
    _cepDebounce?.cancel();
    super.dispose();
  }

  void _onCepDigitado(String _) {
    _cepDebounce?.cancel();
    final d = cepSoDigitos(widget.cep.text);
    if (d.length != 8) return;
    _cepDebounce = Timer(const Duration(milliseconds: 450), _buscarCep);
  }

  Future<void> _buscarCep() async {
    if (!mounted) return;
    final d = cepSoDigitos(widget.cep.text);
    if (d.length != 8) return;
    setState(() => _cepLoading = true);
    try {
      final r = await fetchCepBr(d);
      if (!mounted || r == null) return;
      final chave = chaveMunicipioMtApartirCepLocalidade(r.localidade, r.uf);
      setState(() {
        if (r.logradouro.trim().isNotEmpty) {
          widget.logradouro.text = r.logradouro.trim();
        }
        final comp = r.complemento?.trim();
        final bairro = r.bairro?.trim();
        if (widget.complemento.text.trim().isEmpty) {
          if (comp != null && comp.isNotEmpty) {
            widget.complemento.text = comp;
          } else if (bairro != null && bairro.isNotEmpty) {
            widget.complemento.text = bairro;
          }
        }
      });
      // Não sobrescreve o município já escolhido no picker (evita apagar cidade ao completar o CEP).
      if (chave != null) {
        final jaEscolhido = widget.selectedCidadeKey?.trim();
        if (jaEscolhido == null || jaEscolhido.isEmpty) {
          widget.onCidadeSelected(chave);
        }
      }
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  String? _emailPadrao(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Informe o e-mail';
    }
    final t = v.trim();
    if (!t.contains('@') || !t.contains('.')) return 'E-mail inválido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ev = widget.emailValidator ?? _emailPadrao;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.nome,
          decoration: const InputDecoration(labelText: 'Nome *'),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.telefone,
          decoration: const InputDecoration(
            labelText: 'Telefone',
            hintText: '(00) 0 0000-0000',
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [TelefoneInputFormatter()],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.email,
          decoration: const InputDecoration(labelText: 'E-mail *'),
          keyboardType: TextInputType.emailAddress,
          validator: ev,
        ),
        const SizedBox(height: 12),
        MunicipioMtFormRow(
          selectedNormalizedKey: widget.selectedCidadeKey,
          errorText: widget.cidadeErro,
          label: 'Município (MT) *',
          onSelected: widget.onCidadeSelected,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: widget.abrangencia,
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
            widget.onAbrangenciaChanged(novo);
            if (novo == 'Individual') widget.qtd.text = '1';
          },
        ),
        const SizedBox(height: 12),
        if (widget.abrangencia == 'Familiar')
          TextFormField(
            controller: widget.qtd,
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
        if (widget.footerWidget != null) ...[
          const SizedBox(height: 12),
          widget.footerWidget!,
        ],
        const SizedBox(height: 8),
        Text(
          'Endereço (opcional)',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.cep,
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
            helperText:
                'Ao concluir o CEP, preenche rua e complemento; a cidade do mapa só é definida pelo CEP se você ainda não tiver escolhido o município.',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [CepInputFormatter()],
          onChanged: _onCepDigitado,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.logradouro,
          decoration: const InputDecoration(labelText: 'Rua / logradouro'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.numero,
          decoration: const InputDecoration(labelText: 'Número'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.complemento,
          decoration: const InputDecoration(labelText: 'Complemento'),
        ),
        const SizedBox(height: 8),
        Text(
          'A cidade alimenta o mapa regional e a estimativa por município.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Texto de validação de e-mail igual ao painel (obrigatório para painel Amigos do Gilberto).
String? amigosGilbertoEmailValidatorPainel(String? v) {
  if (v == null || v.trim().isEmpty) {
    return 'E-mail obrigatório para acessar o painel $kAmigosGilbertoLabel';
  }
  final t = v.trim();
  if (!t.contains('@') || !t.contains('.')) return 'E-mail inválido';
  return null;
}
