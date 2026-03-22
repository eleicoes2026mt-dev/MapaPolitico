import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import 'widgets/bandeira_apoiador_editor.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../providers/perfil_provider.dart';

/// Cargos (dropdown) conforme solicitado.
const List<String> cargosOpcoes = [
  'DEPUTADO ESTADUAL',
  'DEPUTADO FEDERAL',
  'GOVERNADOR',
  'SENADOR',
];

class MeuPerfilScreen extends ConsumerStatefulWidget {
  const MeuPerfilScreen({super.key});

  @override
  ConsumerState<MeuPerfilScreen> createState() => _MeuPerfilScreenState();
}

class _MeuPerfilScreenState extends ConsumerState<MeuPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _phoneController;
  late TextEditingController _partidoController;
  late TextEditingController _numeroController;
  String? _cargo;
  DateTime? _dataNascimento;
  String? _avatarUrl;
  int? _sqCandidatoTse2022;
  bool _loading = false;
  bool _uploadingImage = false;
  String? _error;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController();
    _phoneController = TextEditingController();
    _partidoController = TextEditingController();
    _numeroController = TextEditingController();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _phoneController.dispose();
    _partidoController.dispose();
    _numeroController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final p = ref.read(profileProvider).valueOrNull;
      final isCand = p?.role == 'candidato';
      await ref.read(updateProfileProvider)(
        (
          fullName: _nomeController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          cargo: isCand ? _cargo : p?.cargo,
          partido: isCand
              ? (_partidoController.text.trim().isEmpty ? null : _partidoController.text.trim())
              : p?.partido,
          numeroCandidato: isCand
              ? (_numeroController.text.trim().isEmpty ? null : _numeroController.text.trim())
              : p?.numeroCandidato,
          dataNascimento: _dataNascimento,
          avatarUrl: _avatarUrl,
          sqCandidatoTse2022: isCand ? _sqCandidatoTse2022 : p?.sqCandidatoTse2022,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImage(ThemeData theme) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (xfile == null || !mounted) return;
    setState(() => _uploadingImage = true);
    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) return;
      final name = xfile.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      final path = '$userId.$ext';
      final bytes = await xfile.readAsBytes();
      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      if (mounted) setState(() {
        _avatarUrl = url;
        _uploadingImage = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final currentUser = ref.watch(currentUserProvider);

    return profileAsync.when(
      data: (profile) {
        if (currentUser == null) {
          return const Center(child: Text('Faça login para editar seu perfil.'));
        }
        final email = profile?.email ?? currentUser.email ?? '';
        final role = profile?.role ?? 'votante';
        final isCandidato = role == 'candidato';
        if (!_prefilled) {
          _prefilled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final nome = profile?.fullName ??
                currentUser.userMetadata?['full_name']?.toString() ??
                '';
            if (nome.isNotEmpty) _nomeController.text = nome;
            _phoneController.text = profile?.phone ?? '';
            _partidoController.text = profile?.partido ?? '';
            _numeroController.text = profile?.numeroCandidato ?? '';
            if (_cargo == null && profile?.cargo != null) {
              setState(() => _cargo = profile?.cargo);
            }
            if (_dataNascimento == null && profile?.dataNascimento != null) {
              setState(() => _dataNascimento = profile?.dataNascimento);
            }
            if (_avatarUrl == null && profile?.avatarUrl != null) {
              setState(() => _avatarUrl = profile?.avatarUrl);
            }
            if (_sqCandidatoTse2022 == null && profile?.sqCandidatoTse2022 != null) {
              setState(() => _sqCandidatoTse2022 = profile?.sqCandidatoTse2022);
            }
          });
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meu perfil',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const EstadoMTBadge(compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profile == null
                    ? 'Complete seu perfil. Ele será criado ao salvar.'
                    : isCandidato
                        ? 'Edite seu nome, contato e dados de candidato.'
                        : 'Edite seu nome e contato. Os dados de campanha do candidato ficam só no perfil dele — aqui é o seu acesso (${_roleLabel(role)}).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: email,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O e-mail não pode ser alterado aqui.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contato (Telefone)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _DataNascimentoField(
                      value: _dataNascimento,
                      onChanged: (d) => setState(() => _dataNascimento = d),
                    ),
                    const SizedBox(height: 16),
                    _ImagemPerfilField(
                      avatarUrl: _avatarUrl,
                      uploading: _uploadingImage,
                      onPick: () => _pickAndUploadImage(theme),
                    ),
                    if (isCandidato) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _partidoController,
                        decoration: const InputDecoration(
                          labelText: 'Partido Político (sigla)',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      const EstadoMTBadge(),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        value: _cargo ?? profile?.cargo,
                        decoration: const InputDecoration(
                          labelText: 'Cargo',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Selecione o cargo'),
                          ),
                          ...cargosOpcoes.map((c) => DropdownMenuItem<String?>(
                                value: c,
                                child: Text(c),
                              )),
                        ],
                        onChanged: (v) => setState(() => _cargo = v),
                      ),
                    ],
                    if (isCandidato) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _numeroController,
                        decoration: const InputDecoration(
                          labelText: 'Número na urna',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                      ),
                      const SizedBox(height: 16),
                      _CandidatoTse2022Field(
                        value: _sqCandidatoTse2022,
                        onChanged: (v) => setState(() => _sqCandidatoTse2022 = v),
                      ),
                      const SizedBox(height: 16),
                      _NmVotavelTseField(),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Função: ${_roleLabel(role)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (role == 'apoiador') ...[
                      const SizedBox(height: 24),
                      Text(
                        'Bandeira no mapa',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cores, formato do fundo, emoji e estilo das iniciais no marcador da sua cidade.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, _) {
                          final async = ref.watch(meuApoiadorProvider);
                          return async.when(
                            data: (ap) {
                              if (ap == null) {
                                return Text(
                                  'Cadastro de apoiador não encontrado para esta conta.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                );
                              }
                              return BandeiraApoiadorEditor(key: ValueKey(ap.id), apoiador: ap);
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            error: (e, _) => Text(
                              'Erro ao carregar apoiador: $e',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          );
                        },
                      ),
                    ],
                    if (isCandidato)
                      Text(
                        'Função é seu tipo de conta no sistema. Cargo acima é a posição política que você indica.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Text(
                        'Sua função (${_roleLabel(role)}) define o que você vê no menu. Não é o perfil do candidato.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : () {
                              _formKey.currentState?.save();
                              _submit();
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar perfil'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'candidato':
        return 'Candidato';
      case 'assessor':
        return 'Assessor';
      case 'apoiador':
        return 'Apoiador';
      case 'votante':
        return 'Votante';
      default:
        return role;
    }
  }
}

class _DataNascimentoField extends StatelessWidget {
  const _DataNascimentoField({this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(1990),
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Data de Nascimento',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null ? 'Toque para selecionar' : DateFormat('dd/MM/yyyy').format(value!),
          style: TextStyle(
            color: value == null ? Theme.of(context).hintColor : null,
          ),
        ),
      ),
    );
  }
}

class _ImagemPerfilField extends StatelessWidget {
  const _ImagemPerfilField({
    this.avatarUrl,
    required this.uploading,
    required this.onPick,
  });

  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagem de Perfil',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? Icon(Icons.person, size: 40, color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: uploading ? null : onPick,
                    icon: uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera),
                    label: Text(uploading ? 'Enviando...' : 'Escolher foto'),
                  ),
                  if (avatarUrl != null && avatarUrl!.isNotEmpty)
                    Text(
                      'Foto definida. Toque para trocar.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Campo para o candidato escolher quem é na eleição 2022 (dados da tabela votacao_secao no Supabase).
/// Abre diálogo com pesquisa para filtrar a lista de nomes.
class _CandidatoTse2022Field extends ConsumerWidget {
  const _CandidatoTse2022Field({this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final candidatosAsync = ref.watch(candidatos2022MtProvider);

    return candidatosAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'Não há candidatos da eleição 2022 (MT) na base. Verifique a carga na tabela votacao_secao.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        final selected = list.where((c) => c.sqCandidato == value).firstOrNull;
        return InkWell(
          onTap: () => _showCandidato2022Picker(context, list, value, onChanged),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Quem sou eu na eleição 2022 (TSE)',
              hintText: 'Toque para pesquisar e selecionar seu nome',
              prefixIcon: Icon(Icons.how_to_vote_outlined),
            ),
            isEmpty: selected == null,
            child: selected != null
                ? Text(selected.nmVotavel, overflow: TextOverflow.ellipsis)
                : null,
          ),
        );
      },
      loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Text(
        'Erro ao carregar candidatos 2022: $e. Confira se a tabela votacao_secao tem a coluna nm_votavel com os nomes (equivalente ao NM_VOTAVEL do CSV). Após importar, rode no SQL do Supabase: REFRESH MATERIALIZED VIEW candidatos_2022_mt;',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}

void _showCandidato2022Picker(
  BuildContext context,
  List<({int sqCandidato, String nmVotavel})> list,
  int? currentValue,
  ValueChanged<int?> onChanged,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => _Candidato2022SearchDialog(
      list: list,
      currentValue: currentValue,
      onSelected: (sq) {
        onChanged(sq);
        Navigator.of(ctx).pop();
      },
    ),
  );
}

class _Candidato2022SearchDialog extends StatefulWidget {
  const _Candidato2022SearchDialog({
    required this.list,
    required this.currentValue,
    required this.onSelected,
  });

  final List<({int sqCandidato, String nmVotavel})> list;
  final int? currentValue;
  final void Function(int?) onSelected;

  @override
  State<_Candidato2022SearchDialog> createState() => _Candidato2022SearchDialogState();
}

class _Candidato2022SearchDialogState extends State<_Candidato2022SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<({int sqCandidato, String nmVotavel})> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.list;
    return widget.list.where((c) => c.nmVotavel.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AlertDialog(
      title: const Text('Selecione seu nome (eleição 2022)'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: const InputDecoration(
                hintText: 'Pesquisar nome...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.clear_outlined),
                      title: const Text('Não selecionado'),
                      selected: widget.currentValue == null,
                      onTap: () => widget.onSelected(null),
                    );
                  }
                  final c = filtered[index - 1];
                  return ListTile(
                    title: Text(c.nmVotavel, overflow: TextOverflow.ellipsis),
                    selected: widget.currentValue == c.sqCandidato,
                    onTap: () => widget.onSelected(c.sqCandidato),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NmVotavelTseField extends ConsumerWidget {
  const _NmVotavelTseField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final opcoes = ref.watch(tseDistinctNmVotavelProvider);
    final selected = ref.watch(tseNmVotavelSelectedProvider);

    return opcoes.when(
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'Selecione acima (Eleição 2022) para vincular seu candidato. O campo NM_VOTAVEL é opcional para importação de CSV.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        final current = selected.valueOrNull;
        return DropdownButtonFormField<String?>(
          value: list.contains(current) ? current : null,
          decoration: const InputDecoration(
            labelText: 'Meu nome no arquivo TSE (NM_VOTAVEL)',
            hintText: 'Selecione como seu nome aparece no CSV',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Não selecionado')),
            ...list.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => ref.read(tseNmVotavelSelectedProvider.notifier).setSelected(v),
        );
      },
      loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
