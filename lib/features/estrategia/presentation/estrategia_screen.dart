import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import 'tabs/performance_tab.dart';
import 'tabs/mapa_regional_tab.dart';
import 'tabs/metas_tab.dart';
import 'tabs/responsaveis_tab.dart';

class EstrategiaScreen extends ConsumerStatefulWidget {
  const EstrategiaScreen({super.key});

  @override
  ConsumerState<EstrategiaScreen> createState() => _EstrategiaScreenState();
}

class _EstrategiaScreenState extends ConsumerState<EstrategiaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estratégia', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(AppConstants.ufLabel, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.show_chart), text: 'Performance'),
              Tab(icon: Icon(Icons.map), text: 'Mapa Regional'),
              Tab(icon: Icon(Icons.flag), text: 'Metas'),
              Tab(icon: Icon(Icons.people), text: 'Responsáveis'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: const [
                PerformanceTab(),
                MapaRegionalTab(),
                MetasTab(),
                ResponsaveisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
