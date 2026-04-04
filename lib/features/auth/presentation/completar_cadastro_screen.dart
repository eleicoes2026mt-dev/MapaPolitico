import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_callback_url.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/profile_role_cache.dart' show clearProfileRoleCache;
import '../../../core/router/role_home.dart';
import '../providers/auth_provider.dart';

/// Tela para o convidado (assessor/apoiador) definir **só a senha** após o convite (conta já criada no Supabase),
/// ou [isPasswordRecovery] após «Esqueci minha senha».
/// Layout alinhado ao [LoginScreen] (mapa, cartão, campos).
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
  bool _sessionCheckDone = false;

  static const _kUserNotFoundHint =
      'Este link não é mais válido: o convite pode ter sido reenviado, a conta recriada ou removida. '
      'Peça um novo convite ao candidato ou, se já tiver cadastro, use «Esqueci minha senha» no login.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureUserExistsOnServer());
  }

  /// GET /user com o JWT atual — evita mostrar o formulário se o `sub` já não existe (403 user_not_found).
  Future<void> _ensureUserExistsOnServer() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      if (mounted) context.go('/login');
      return;
    }
    try {
      await auth.getUser();
    } catch (e) {
      if (!mounted) return;
      await auth.signOut();
      if (_isUserNotFoundOrGone(e)) {
        storePendingAuthErrorMessage(_kUserNotFoundHint);
      } else {
        storePendingAuthErrorMessage(
          'Não foi possível validar o acesso por este link. Tente de novo ou entre com e-mail e senha.',
        );
      }
      if (mounted) context.go('/login');
      return;
    }
    if (mounted) setState(() => _sessionCheckDone = true);
  }

  bool _isUserNotFoundOrGone(Object e) {
    if (e is AuthException) {
      final c = e.code?.toLowerCase();
      if (c == 'user_not_found') return true;
      final m = e.message.toLowerCase();
      if (m.contains('does not exist') && m.contains('sub')) return true;
    }
    final s = e.toString().toLowerCase();
    return s.contains('user_not_found') ||
        (s.contains('does not exist') && s.contains('sub claim'));
  }

  String _messageForAuthFailure(Object e) {
    if (_isUserNotFoundOrGone(e)) return _kUserNotFoundHint;
    return e.toString().replaceFirst('AuthException: ', '').replaceFirst('Exception: ', '');
  }

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
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: senha))
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;

      if (widget.isPasswordRecovery) {
        // Evita travar em profileProvider (stream/RLS após recovery) e leva ao login com a nova senha.
        clearProfileRoleCache();
        ref.invalidate(profileProvider);
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        context.go('/login');
        return;
      }

      clearProfileRoleCache();
      ref.invalidate(profileProvider);
      final profile = await ref
          .read(profileProvider.future)
          .timeout(const Duration(seconds: 25));
      final role = profile?.role;
      if (!mounted) return;
      context.go(homePathForProfileRole(role));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'A operação demorou demais. Verifique a internet e tente de novo; se a senha já tiver sido alterada, use «Voltar ao login».';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageForAuthFailure(e);
      });
    }
  }

  /// Encerra a sessão de recuperação; senão o GoRouter devolve sempre para `/redefinir-senha`.
  Future<void> _voltarAoLogin() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go('/login');
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
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final user = Supabase.instance.client.auth.currentUser;

    if (!_sessionCheckDone && Supabase.instance.client.auth.currentSession != null) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFF0D1117)),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    InputDecoration fieldDecoration({
      required String label,
      required Widget prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
      );
    }

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
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: isDark ? 8 : 12,
                    shadowColor: isDark ? Colors.black54 : primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isPasswordRecovery
                                    ? Icons.lock_reset_rounded
                                    : Icons.how_to_vote_rounded,
                                size: 56,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppConstants.appName,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppConstants.appSubtitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.isPasswordRecovery
                                  ? 'Definir nova senha'
                                  : 'Defina sua senha de acesso',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.isPasswordRecovery
                                  ? 'Escolha uma nova senha para voltar a acessar o ${AppConstants.ufLabel}.'
                                  : 'O convite já criou seu usuário e seu perfil no ${AppConstants.ufLabel}. '
                                      'Basta escolher uma senha para o primeiro acesso. '
                                      'Você entrará no painel do seu papel (assessor ou apoiador), não no do candidato.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (user?.email != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'E-mail da conta',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user!.email!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _senhaController,
                              decoration: fieldDecoration(
                                label: 'Senha',
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                                ),
                              ),
                              obscureText: _obscureSenha,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Defina uma senha';
                                if (v.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmarSenhaController,
                              decoration: fieldDecoration(
                                label: 'Confirmar senha',
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmar
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                                ),
                              ),
                              obscureText: _obscureConfirmar,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (_formKey.currentState?.validate() ?? false) {
                                  _submit();
                                }
                              },
                              validator: (v) {
                                if (v != _senhaController.text) return 'As senhas não coincidem';
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
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
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
                                  : Text(
                                      widget.isPasswordRecovery
                                          ? 'Salvar nova senha e entrar'
                                          : 'Confirmar senha e entrar',
                                    ),
                            ),
                            if (widget.isPasswordRecovery) ...[
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: _loading ? null : _voltarAoLogin,
                                child: Text(
                                  'Voltar ao login',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
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

