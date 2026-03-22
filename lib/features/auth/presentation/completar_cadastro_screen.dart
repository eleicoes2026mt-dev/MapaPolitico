import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/profile_role_cache.dart' show clearProfileRoleCache;
import '../../../core/router/role_home.dart';
import '../providers/auth_provider.dart';

/// Tela para o convidado (assessor/apoiador) definir senha após o convite, ou [isPasswordRecovery] após «Esqueci minha senha».
class CompletarCadastroScreen extends ConsumerStatefulWidget {
  const CompletarCadastroScreen({super.key, this.isPasswordRecovery = false});

  /// `true` quando veio do link de recuperação de senha (não do convite).
  final bool isPasswordRecovery;

  @override
  ConsumerState<CompletarCadastroScreen> createState() => _CompletarCadastroScreenState();
}

class _CompletarCadastroScreenState extends ConsumerState<CompletarCadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _loading = false;
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  String? _error;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }
    final senha = _senhaController.text;
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: senha));
      if (!mounted) return;
      clearProfileRoleCache();
      ref.invalidate(profileProvider);
      final profile = await ref.read(profileProvider.future);
      final role = profile?.role;
      if (!mounted) return;
      context.go(homePathForProfileRole(role));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('AuthException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  widget.isPasswordRecovery ? 'Definir nova senha' : 'Complete seu cadastro',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isPasswordRecovery
                      ? 'Escolha uma nova senha para voltar a acessar o ${AppConstants.ufLabel}.'
                      : 'Você foi convidado(a) para acessar o ${AppConstants.ufLabel}. Defina uma senha para concluir. Você entrará no painel do seu perfil (assessor ou apoiador), não no do candidato.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    user!.email!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _senhaController,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureSenha ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                    ),
                  ),
                  obscureText: _obscureSenha,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Defina uma senha';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarSenhaController,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmar ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                    ),
                  ),
                  obscureText: _obscureConfirmar,
                  validator: (v) {
                    if (v != _senhaController.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.isPasswordRecovery ? 'Salvar nova senha e entrar' : 'Criar senha e acessar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
