import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import 'tabs/performance_tab.dart';
import 'tabs/mapa_regional_tab.dart';
import 'tabs/metas_tab.dart';
import 'tabs/responsaveis_tab.dart';
import 'tabs/regioes_tab.dart';

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
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final padding = width < 600 ? 16.0 : 24.0;
    final isNarrow = width < 600;
    final tabViewHeight = (height * 0.55).clamp(400.0, 700.0);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Estratégia',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const EstadoMTBadge(compact: true),
            ],
          ),
          SizedBox(height: padding),
          TabBar(
            controller: _tabController,
            isScrollable: isNarrow,
            tabAlignment: isNarrow ? TabAlignment.start : TabAlignment.fill,
            tabs: const [
              Tab(icon: Icon(Icons.show_chart), text: 'Performance'),
              Tab(icon: Icon(Icons.map), text: 'Mapa Regional'),
              Tab(icon: Icon(Icons.flag), text: 'Metas'),
              Tab(icon: Icon(Icons.people), text: 'Responsáveis'),
              Tab(icon: Icon(Icons.merge_type), text: 'Regiões'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: tabViewHeight,
            child: TabBarView(
              controller: _tabController,
              children: const [
                PerformanceTab(),
                MapaRegionalTab(),
                MetasTab(),
                ResponsaveisTab(),
                RegioesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
