import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/regioes_fundidas.dart';
import '../providers/regioes_fundidas_provider.dart';

/// Exibe diálogo para editar o nome da região. Salva em [nomesCustomizadosProvider]
/// (região única) ou atualiza a fusão em [regioesFundidasProvider] (região fundida).
/// O nome atualizado reflete no mapa, Metas, Responsáveis e Regiões.
Future<bool> showEditRegiaoNomeDialog(
  BuildContext context,
  WidgetRef ref,
  RegiaoEfetiva regiao,
) async {
  final controller = TextEditingController(text: regiao.nome);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Editar nome da região'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Nome da região',
          hintText: 'Ex.: Região Cuiabá, Centro-Norte',
        ),
        textCapitalization: TextCapitalization.words,
        autofocus: true,
        onSubmitted: (_) => Navigator.of(ctx).pop(true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  if (saved != true) return false;
  final nome = controller.text.trim();
  if (nome.isEmpty) return false;
  if (regiao.eFundida) {
    await ref.read(regioesFundidasProvider.notifier).updateNome(regiao.id, nome);
  } else {
    await ref.read(nomesCustomizadosProvider.notifier).setNome(regiao.id, nome);
  }
  return true;
}
