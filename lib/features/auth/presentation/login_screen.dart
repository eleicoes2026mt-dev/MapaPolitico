import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_callback_url.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/role_home.dart';
import '../data/login_preferences.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _saveLogin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final msg = takePendingAuthErrorMessage();
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      await _loadSavedLogin();
      if (!mounted) return;
      try {
        final email = GoRouterState.of(context).uri.queryParameters['email'];
        if (email != null && email.isNotEmpty) {
          setState(() => _emailController.text = email);
        }
      } catch (_) {}
    });
  }

  Future<void> _loadSavedLogin() async {
    final save = await LoginPreferences.saveLogin;
    final email = await LoginPreferences.savedEmail;
    if (!mounted) return;
    setState(() {
      _saveLogin = save;
      if (email != null && email.isNotEmpty) _emailController.text = email;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      if (_saveLogin) {
        await LoginPreferences.setSaveLogin(true);
        await LoginPreferences.setSavedEmail(_emailController.text.trim());
      } else {
        await LoginPreferences.setSaveLogin(false);
        await LoginPreferences.setSavedEmail(null);
      }
      if (!mounted) return;
      await ref.read(profileProvider.future);
      final role = ref.read(profileProvider).valueOrNull?.role;
      if (mounted) context.go(homePathForProfileRole(role));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _mostrarEsqueciSenha() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Redefinir senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informe o e-mail cadastrado. Você receberá um link para criar uma nova senha.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'seu@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar link')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final email = controller.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um e-mail válido.')),
        );
        return;
      }
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email,
          redirectTo: kIsWeb
              ? EnvConfig.webPasswordRecoveryRedirectTo
              : EnvConfig.appUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Se existir conta com este e-mail, enviamos o link. Confira a caixa de entrada e o spam.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('AuthException: ', ''))),
          );
        }
      }
    } finally {
      controller.dispose();
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
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          image: const DecorationImage(
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
                              Icons.how_to_vote_rounded,
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
                          const SizedBox(height: 36),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              hintText: 'seu@email.com',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Informe o e-mail' : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                            ),
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (_formKey.currentState?.validate() ?? false) {
                                _submit();
                              }
                            },
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Informe a senha' : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : _mostrarEsqueciSenha,
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _saveLogin,
                                  onChanged: (v) {
                                    setState(() => _saveLogin = v ?? true);
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  activeColor: primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _saveLogin = !_saveLogin);
                                },
                                child: Text(
                                  'Salvar login',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer
                                    .withValues(alpha: 0.5),
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
                            onPressed: _loading
                                ? null
                                : () {
                                    if (_formKey.currentState?.validate() ??
                                        false) _submit();
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
                                : const Text('Entrar'),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => context.push('/cadastro'),
                            child: Text(
                              'Não tem conta? Criar conta',
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

