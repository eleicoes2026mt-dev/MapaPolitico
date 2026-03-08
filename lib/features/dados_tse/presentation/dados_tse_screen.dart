import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../data/tse_csv_parser.dart';
import '../providers/dados_tse_provider.dart';

class DadosTseScreen extends ConsumerStatefulWidget {
  const DadosTseScreen({super.key});

  @override
  ConsumerState<DadosTseScreen> createState() => _DadosTseScreenState();
}

class _DadosTseScreenState extends ConsumerState<DadosTseScreen> {
  bool _uploading = false;
  String? _error;

  Future<void> _pickAndImportCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) setState(() => _error = 'Arquivo vazio');
      return;
    }
    setState(() {
      _error = null;
      _uploading = true;
    });
    try {
      final content = String.fromCharCodes(bytes);
      final rows = parseTseCsv(content);
      if (rows.isEmpty) {
        if (mounted) setState(() => _error = 'Nenhuma linha válida no CSV');
        return;
      }
      await ref.read(tseRowsProvider.notifier).appendRows(rows);
      if (mounted) {
        setState(() => _uploading = false);
        final total = ref.read(tseRowsProvider).valueOrNull?.length ?? rows.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+${rows.length} linhas adicionadas (total: $total). Selecione seu nome em Meu perfil > Nome no arquivo TSE.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowsAsync = ref.watch(tseRowsProvider);
    final count = rowsAsync.valueOrNull?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dados TSE', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Importar Dados TSE', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Faça upload de arquivo .csv com as colunas do TSE (DT_GERACAO, ANO_ELEICAO, NM_MUNICIPIO, QT_VOTOS, NM_VOTAVEL, etc.)',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _pickAndImportCsv,
                      icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                      label: Text(_uploading ? 'Importando...' : 'Upload CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          rowsAsync.when(
            data: (rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(Icons.bar_chart, size: 80, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('Nenhum dado TSE importado', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Importe um arquivo CSV para visualizar os dados eleitorais e mapear votos por cidade.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$count linhas importadas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'Em Meu perfil (como candidato), selecione seu nome na coluna NM_VOTAVEL para ver seus votos por cidade no mapa.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('Erro: $e', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error))),
          ),
        ],
      ),
    );
  }
}
