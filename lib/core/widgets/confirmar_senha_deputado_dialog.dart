import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_provider.dart';

/// Pede a senha de login do candidato (conta atual) e reautentica via [signInWithPassword].
/// Só faz sentido quando o utilizador logado é o deputado/candidato.
Future<bool> confirmarSenhaDeputado(BuildContext context) async {
  final email = supabase.auth.currentUser?.email;
  if (email == null || email.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão sem e-mail; faça login novamente.')),
      );
    }
    return false;
  }

  final password = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _SenhaDeputadoDialogContent(),
  );

  if (password == null || password.isEmpty) return false;

  try {
    await supabase.auth.signInWithPassword(email: email, password: password);
    return true;
  } on AuthException catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha incorreta.')),
      );
    }
    return false;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível verificar a senha. Tente de novo.')),
      );
    }
    return false;
  }
}

class _SenhaDeputadoDialogContent extends StatefulWidget {
  const _SenhaDeputadoDialogContent();

  @override
  State<_SenhaDeputadoDialogContent> createState() => _SenhaDeputadoDialogContentState();
}

class _SenhaDeputadoDialogContentState extends State<_SenhaDeputadoDialogContent> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Senha do deputado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Digite a senha de login do candidato (esta conta) para confirmar a exclusão.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
