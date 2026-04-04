import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'reload_page_stub.dart'
    if (dart.library.html) 'reload_page_web.dart' as reload_page;

const _kPrefsDeployVersion = 'campanha_mt_deploy_version_seen';

bool _dialogAberto = false;

/// Compara [web/version.json] com a última versão guardada; se mudou, oferece recarregar.
/// Em cada deploy, o CI deve gravar um `version` novo (ex.: hash do commit) em `build/web/version.json`.
Future<void> checkAndMaybePromptDeployUpdate(BuildContext context) async {
  if (!kIsWeb) return;
  try {
    final url = Uri.base.resolve('version.json').replace(
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final server = map?['version']?.toString().trim();
    if (server == null || server.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(_kPrefsDeployVersion);

    if (seen == null) {
      await prefs.setString(_kPrefsDeployVersion, server);
      return;
    }
    if (seen == server) return;
    if (!context.mounted || _dialogAberto) return;

    _dialogAberto = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova versão disponível'),
        content: const Text(
          'Publicamos uma atualização no site. Recarregue a página para usar a versão mais recente e evitar erros.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dialogAberto = false;
            },
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setString(_kPrefsDeployVersion, server);
              if (ctx.mounted) Navigator.pop(ctx);
              _dialogAberto = false;
              reload_page.reloadPageIfWeb();
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
    _dialogAberto = false;
  } catch (_) {
    _dialogAberto = false;
  }
}
