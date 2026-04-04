import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/utils/municipio_resolver.dart' show municipioIdParaNomeCidade;
import '../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT;
import '../../apoiadores/presentation/utils/apoiadores_form_utils.dart'
    show cepSoDigitos, telefoneSoDigitos;
import '../../votantes/presentation/widgets/amigos_gilberto_dados_form_fields.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../providers/auth_provider.dart';

/// Página pública: mesmo conjunto de dados do painel «Novo — Amigos do Gilberto» + senha para login.
class CadastroAmigosGilbertoScreen extends ConsumerStatefulWidget {
  const CadastroAmigosGilbertoScreen({super.key});

  @override
  ConsumerState<CadastroAmigosGilbertoScreen> createState() =>
      _CadastroAmigosGilbertoScreenState();
}

class _CadastroAmigosGilbertoScreenState extends ConsumerState<CadastroAmigosGilbertoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _telefone;
  late final TextEditingController _emailController;
  late final TextEditingController _qtd;
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  String? _cidadeNomeNormalizado;
  String? _cidadeErro;
  String _abrangencia = 'Individual';

  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController();
    _telefone = TextEditingController();
    _emailController = TextEditingController();
    _qtd = TextEditingController(text: '1');
    _cep = TextEditingController();
    _logradouro = TextEditingController();
    _numero = TextEditingController();
    _complemento = TextEditingController();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefone.dispose();
    _emailController.dispose();
    _qtd.dispose();
    _cep.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_cidadeNomeNormalizado == null || _cidadeNomeNormalizado!.trim().isEmpty) {
      setState(() => _cidadeErro = 'Selecione o município.');
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cidadeNomeNormalizado == null || _cidadeNomeNormalizado!.trim().isEmpty) {
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final email = _emailController.text.trim();
    final refConv = GoRouterState.of(context).uri.queryParameters['ref']?.trim();

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
            email,
            _passwordController.text,
            fullName: _nomeController.text.trim().isEmpty ? null : _nomeController.text.trim(),
            cadastroAmigosGilberto: true,
            convitePorProfileId: (refConv != null && refConv.isNotEmpty) ? refConv : null,
          );

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Sessão não iniciada após cadastro. Tente entrar com e-mail e senha.');
      }

      await supabase.rpc('ensure_votante_amigos_cadastro');
      final row = await supabase.from('votantes').select('id').eq('profile_id', user.id).maybeSingle();
      if (row == null) {
        throw Exception(
          'Não foi possível vincular seu cadastro à campanha. Confirme se o candidato está ativo ou tente mais tarde.',
        );
      }

      final municipios = await refreshMunicipiosMTList(ref);
      var municipioIdResolvido = municipioIdParaNomeCidade(_cidadeNomeNormalizado, municipios);
      municipioIdResolvido ??=
          municipioIdParaNomeCidade(displayNomeCidadeMT(_cidadeNomeNormalizado!), municipios);
      final cidadeTexto = displayNomeCidadeMT(_cidadeNomeNormalizado!);
      final qtd = int.tryParse(_qtd.text.trim()) ?? 1;

      await ref.read(atualizarVotanteProvider)(
        row['id'] as String,
        AtualizarVotanteParams(
          nome: _nomeController.text.trim(),
          telefone: telefoneSoDigitos(_telefone.text).isEmpty ? null : telefoneSoDigitos(_telefone.text),
          email: email,
          municipioId: municipioIdResolvido,
          cidadeNome: cidadeTexto,
          abrangencia: _abrangencia,
          qtdVotosFamilia: qtd < 1 ? 1 : qtd,
          cep: cepSoDigitos(_cep.text).isEmpty ? null : cepSoDigitos(_cep.text),
          logradouro: _logradouro.text.trim().isEmpty ? null : _logradouro.text.trim(),
          numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
          complemento: _complemento.text.trim().isEmpty ? null : _complemento.text.trim(),
        ),
      );

      await ref.read(authNotifierProvider.notifier).signOut();

      if (!mounted) return;
      setState(() => _loading = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.check_circle_outline_rounded,
            color: Theme.of(ctx).colorScheme.primary,
            size: 48,
          ),
          title: const Text('Cadastro concluído'),
          content: const Text(
            'Sua conta e seus dados na campanha foram registrados. Na próxima tela, entre com o mesmo e-mail e senha para acessar o painel.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ir para o login'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.go('/login?email=${Uri.encodeComponent(email)}');
    } catch (e) {
      try {
        await ref.read(authNotifierProvider.notifier).signOut();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          image: DecorationImage(
            image: AssetImage('assets/images/map_base_1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    elevation: isDark ? 8 : 12,
                    shadowColor: isDark ? Colors.black54 : primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Cadastro',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              kAmigosGilbertoLabel,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Preencha todos os dados para entrar na rede do candidato e acessar o painel com e-mail e senha.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Theme(
                              data: theme.copyWith(
                                inputDecorationTheme: InputDecorationTheme(
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              child: AmigosGilbertoDadosFormFields(
                                nome: _nomeController,
                                telefone: _telefone,
                                email: _emailController,
                                qtd: _qtd,
                                cep: _cep,
                                logradouro: _logradouro,
                                numero: _numero,
                                complemento: _complemento,
                                selectedCidadeKey: _cidadeNomeNormalizado,
                                cidadeErro: _cidadeErro,
                                onCidadeSelected: (k) => setState(() {
                                  _cidadeNomeNormalizado = k;
                                  _cidadeErro = null;
                                }),
                                abrangencia: _abrangencia,
                                onAbrangenciaChanged: (novo) => setState(() {
                                  _abrangencia = novo;
                                  if (novo == 'Individual') _qtd.text = '1';
                                }),
                                emailValidator: null,
                                footerWidget: Card(
                                  elevation: 0,
                                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.link_rounded, color: theme.colorScheme.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '$kAmigosGilbertoLabel — cidade e endereço alimentam o mapa e a estimativa da campanha.',
                                            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Acesso ao painel',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Informe a senha';
                                if (v.length < 6) {
                                  return 'Senha deve ter no mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmarPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirmar senha',
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                              ),
                              obscureText: _obscureConfirm,
                              onFieldSubmitted: (_) {
                                if (_formKey.currentState?.validate() ?? false) _submit();
                              },
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Confirme a senha';
                                if (v != _passwordController.text) {
                                  return 'As senhas não coincidem';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 20,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      if (_formKey.currentState?.validate() ?? false) {
                                        _submit();
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text('Criar minha conta'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _loading ? null : () => context.go('/login'),
                              child: Text(
                                'Já tem conta? Entrar',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
