import 'package:flutter/material.dart';

class ResponsaveisTab extends StatelessWidget {
  const ResponsaveisTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final polos = [
      ('Cuiabá', 'Centro-Sul - 30 municípios', Colors.blue),
      ('Rondonópolis', 'Sudeste - 18 municípios', Colors.red),
      ('Sinop', 'Norte - 43 municípios', Colors.green),
      ('Barra do Garças', 'Leste - 30 municípios', Colors.orange),
      ('Cáceres', 'Sudoeste/Oeste - 41 municípios', Colors.purple),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Atribuição de Responsáveis Regionais', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ...polos.map((p) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: p.$3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(p.$1),
              subtitle: Text(p.$2),
              trailing: DropdownButton<String>(
                value: 'Sem responsável',
                items: const [
                  DropdownMenuItem(value: 'Sem responsável', child: Text('Sem responsável')),
                ],
                onChanged: (_) {},
              ),
            ),
          )),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('Salvar Responsáveis'),
          ),
        ],
      ),
    );
  }
}
