import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/apoiador.dart';
import '../../../models/assessor.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show
        AtualizarMeuAssessorEnderecoParams,
        atualizarMeuAssessorEnderecoProvider,
        meuAssessorRegistroProvider;
import '../../auth/providers/auth_provider.dart';
import '../../../core/router/profile_role_cache.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../providers/perfil_provider.dart';
import '../providers/partidos_provider.dart';
import '../../../models/partido.dart';
import '../../../core/constants/amigos_gilberto.dart';

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
  String? _cargo;
  String? _partidoId;
  DateTime? _dataNascimento;
  String? _avatarUrl;
  int? _sqCandidatoTse2022;
  bool _loading = false;
  bool _uploadingImage = false;
  String? _error;
  bool _prefilled = false;
  String? _prefillSignature;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController();
    _phoneController = TextEditingController();
    // ref.* não pode rodar durante initState (UncontrolledProviderScope).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      clearProfileRoleCache();
      ref.invalidate(profileProvider);
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _phoneController.dispose();
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
      String? partidoSigla;
      if (isCand) {
        if (_partidoId != null) {
          final list = await ref.read(partidosListProvider.future);
          for (final x in list) {
            if (x.id == _partidoId) {
              partidoSigla = x.sigla;
              break;
            }
          }
        } else {
          partidoSigla = null;
        }
      }
      final podeFoto = p?.role == 'candidato' || p?.role == 'assessor';
      await ref.read(updateProfileProvider)(
        (
          fullName: _nomeController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          cargo: isCand ? _cargo : p?.cargo,
          partido: isCand ? partidoSigla : p?.partido,
          partidoId: isCand ? _partidoId : null,
          dataNascimento: _dataNascimento,
          avatarUrl: podeFoto ? _avatarUrl : p?.avatarUrl,
          sqCandidatoTse2022:
              isCand ? _sqCandidatoTse2022 : p?.sqCandidatoTse2022,
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
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
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
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _uploadingImage = false;
        });
        ref.invalidate(profileProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e')));
      }
    }
  }

  bool _partidoIdValido(List<Partido> lista, String? id) {
    if (id == null) {
      return true;
    }
    return lista.any((p) => p.id == id);
  }

  Future<void> _abrirCadastroPartido(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) async {
    final siglaCtrl = TextEditingController();
    final nomeCtrl = TextEditingController();
    Uint8List? bandeiraBytes;
    var ext = 'jpg';

    final criado = await showDialog<Partido>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Cadastrar partido'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: siglaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sigla',
                        hintText: 'Ex.: PT, PL',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do partido',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          imageQuality: 88,
                        );
                        if (x == null || !ctx.mounted) {
                          return;
                        }
                        final name = x.name;
                        ext = name.contains('.')
                            ? name.split('.').last.toLowerCase()
                            : 'jpg';
                        bandeiraBytes = await x.readAsBytes();
                        setLocal(() {});
                      },
                      icon: const Icon(Icons.flag_circle_outlined),
                      label: Text(
                        bandeiraBytes == null
                            ? 'Anexar imagem da bandeira'
                            : 'Trocar imagem da bandeira',
                      ),
                    ),
                    if (bandeiraBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Imagem selecionada (${(bandeiraBytes!.length / 1024).toStringAsFixed(0)} KB)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final s = siglaCtrl.text.trim();
                    final n = nomeCtrl.text.trim();
                    if (s.isEmpty || n.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha sigla e nome.'),
                        ),
                      );
                      return;
                    }
                    if (bandeiraBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Anexe a imagem da bandeira.'),
                        ),
                      );
                      return;
                    }
                    try {
                      final p = await criarPartidoComBandeira(
                        sigla: s,
                        nome: n,
                        bytes: bandeiraBytes!,
                        fileExt: ext,
                      );
                      ref.invalidate(partidosListProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop(p);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar partido'),
                ),
              ],
            );
          },
        );
      },
    );

    siglaCtrl.dispose();
    nomeCtrl.dispose();

    if (!mounted) {
      return;
    }
    if (criado != null) {
      setState(() => _partidoId = criado.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partido ${criado.sigla} cadastrado.')),
      );
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
          return const Center(
              child: Text('Faça login para editar seu perfil.'));
        }
        final email = profile?.email ?? currentUser.email ?? '';
        final role = profile?.role ?? 'votante';
        final isCandidato = role == 'candidato';
        final podeAlterarFotoPerfil = role == 'candidato' || role == 'assessor';
        final sig = '${profile?.id ?? ''}|$role';
        if (_prefillSignature != sig) {
          _prefillSignature = sig;
          _prefilled = false;
        }
        if (!_prefilled) {
          _prefilled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final nome = profile?.fullName ??
                currentUser.userMetadata?['full_name']?.toString() ??
                '';
            if (nome.isNotEmpty) _nomeController.text = nome;
            _phoneController.text = profile?.phone ?? '';
            setState(() => _partidoId = profile?.partidoId);
            if (_cargo == null && profile?.cargo != null) {
              setState(() => _cargo = profile?.cargo);
            }
            if (_dataNascimento == null && profile?.dataNascimento != null) {
              setState(() => _dataNascimento = profile?.dataNascimento);
            }
            if (_avatarUrl == null && profile?.avatarUrl != null) {
              setState(() => _avatarUrl = profile?.avatarUrl);
            }
            if (_sqCandidatoTse2022 == null &&
                profile?.sqCandidatoTse2022 != null) {
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
                    if (!podeAlterarFotoPerfil) ...[
                      const SizedBox(height: 12),
                      Text(
                        'A imagem de perfil não pode ser alterada neste tipo de conta.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (podeAlterarFotoPerfil) ...[
                      const SizedBox(height: 16),
                      _ImagemPerfilField(
                        avatarUrl: _avatarUrl,
                        uploading: _uploadingImage,
                        onPick: () => _pickAndUploadImage(theme),
                      ),
                    ],
                    if (isCandidato) ...[
                      const SizedBox(height: 16),
                      Consumer(
                        builder: (context, ref, _) {
                          final asyncPartidos = ref.watch(partidosListProvider);
                          return asyncPartidos.when(
                            data: (lista) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<String?>(
                                    value: _partidoIdValido(lista, _partidoId)
                                        ? _partidoId
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Partido',
                                      prefixIcon: Icon(Icons.flag_outlined),
                                      helperText:
                                          'Sem partido: bandeira em branco no menu até escolher partido ou foto de perfil.',
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Sem partido'),
                                      ),
                                      ...lista.map(
                                        (p) => DropdownMenuItem<String?>(
                                          value: p.id,
                                          child: Text(
                                            '${p.sigla} — ${p.nome}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _partidoId = v),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _abrirCadastroPartido(
                                        context, ref, theme),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Cadastrar partido e bandeira'),
                                  ),
                                ],
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            error: (e, _) => Text(
                              'Partidos: $e',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          );
                        },
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
                      _CandidatoTse2022Field(
                        value: _sqCandidatoTse2022,
                        onChanged: (v) =>
                            setState(() => _sqCandidatoTse2022 = v),
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
                        'Marcador no mapa',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nas cidades onde você tem presença cadastrada, o mapa mostra uma bandeirinha fixa na cidade (verde para apoiadores). O estilo é o mesmo para todos; não há personalização de cores ou iniciais.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Endereço (opcional)',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const _EnderecoApoiadorForm(),
                    ],
                    if (role == 'assessor') ...[
                      const SizedBox(height: 24),
                      Text(
                        'Endereço (opcional)',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const _EnderecoAssessorForm(),
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
        return kAmigosGilbertoLabel;
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
          value == null
              ? 'Toque para selecionar'
              : DateFormat('dd/MM/yyyy').format(value!),
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
                  ? Icon(Icons.person,
                      size: 40, color: theme.colorScheme.onSurfaceVariant)
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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        final selected = list.where((c) => c.sqCandidato == value).firstOrNull;
        return InkWell(
          onTap: () =>
              _showCandidato2022Picker(context, list, value, onChanged),
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
      loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Text(
        'Erro ao carregar candidatos 2022: $e. Confira se a tabela votacao_secao tem a coluna nm_votavel com os nomes (equivalente ao NM_VOTAVEL do CSV). Após importar, rode no SQL do Supabase: REFRESH MATERIALIZED VIEW candidatos_2022_mt;',
        style:
            theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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
  State<_Candidato2022SearchDialog> createState() =>
      _Candidato2022SearchDialogState();
}

class _Candidato2022SearchDialogState
    extends State<_Candidato2022SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
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
    return widget.list
        .where((c) => c.nmVotavel.toLowerCase().contains(q))
        .toList();
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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            const DropdownMenuItem<String?>(
                value: null, child: Text('Não selecionado')),
            ...list.map((s) => DropdownMenuItem<String?>(
                value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) =>
              ref.read(tseNmVotavelSelectedProvider.notifier).setSelected(v),
        );
      },
      loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _EnderecoApoiadorForm extends ConsumerWidget {
  const _EnderecoApoiadorForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meuApoiadorProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Erro: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      data: (ap) {
        if (ap == null) {
          return Text(
            'Cadastro de apoiador não encontrado.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          );
        }
        return _EnderecoApoiadorFormBody(apoiador: ap);
      },
    );
  }
}

class _EnderecoApoiadorFormBody extends ConsumerStatefulWidget {
  const _EnderecoApoiadorFormBody({required this.apoiador});

  final Apoiador apoiador;

  @override
  ConsumerState<_EnderecoApoiadorFormBody> createState() =>
      _EnderecoApoiadorFormBodyState();
}

class _EnderecoApoiadorFormBodyState
    extends ConsumerState<_EnderecoApoiadorFormBody> {
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.apoiador;
    _cep = TextEditingController(text: a.cep ?? '');
    _logradouro = TextEditingController(text: a.logradouro ?? '');
    _numero = TextEditingController(text: a.numero ?? '');
    _complemento = TextEditingController(text: a.complemento ?? '');
  }

  @override
  void didUpdateWidget(covariant _EnderecoApoiadorFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apoiador.id != widget.apoiador.id) {
      final a = widget.apoiador;
      _cep.text = a.cep ?? '';
      _logradouro.text = a.logradouro ?? '';
      _numero.text = a.numero ?? '';
      _complemento.text = a.complemento ?? '';
    }
  }

  @override
  void dispose() {
    _cep.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      await ref.read(atualizarApoiadorProvider)(
        widget.apoiador.id,
        AtualizarApoiadorParams(
          atualizarEndereco: true,
          cep: _cep.text.trim(),
          logradouro: _logradouro.text.trim(),
          numero: _numero.text.trim(),
          complemento: _complemento.text.trim(),
        ),
      );
      ref.invalidate(meuApoiadorProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Endereço salvo')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _cep,
          decoration: const InputDecoration(
              labelText: 'CEP', prefixIcon: Icon(Icons.pin_outlined)),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _logradouro,
          decoration: const InputDecoration(
              labelText: 'Rua / logradouro',
              prefixIcon: Icon(Icons.signpost_outlined)),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _numero,
          decoration: const InputDecoration(
              labelText: 'Número', prefixIcon: Icon(Icons.numbers_outlined)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _complemento,
          decoration: const InputDecoration(
              labelText: 'Complemento',
              prefixIcon: Icon(Icons.apartment_outlined)),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: _saving ? null : _salvar,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar endereço'),
        ),
        const SizedBox(height: 4),
        Text(
          'Independente do botão "Salvar perfil" acima.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EnderecoAssessorForm extends ConsumerWidget {
  const _EnderecoAssessorForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meuAssessorRegistroProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Erro: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      data: (a) {
        if (a == null) {
          return Text(
            'Registro de assessor não encontrado.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          );
        }
        return _EnderecoAssessorFormBody(assessor: a);
      },
    );
  }
}

class _EnderecoAssessorFormBody extends ConsumerStatefulWidget {
  const _EnderecoAssessorFormBody({required this.assessor});

  final Assessor assessor;

  @override
  ConsumerState<_EnderecoAssessorFormBody> createState() =>
      _EnderecoAssessorFormBodyState();
}

class _EnderecoAssessorFormBodyState
    extends ConsumerState<_EnderecoAssessorFormBody> {
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assessor;
    _cep = TextEditingController(text: a.cep ?? '');
    _logradouro = TextEditingController(text: a.logradouro ?? '');
    _numero = TextEditingController(text: a.numero ?? '');
    _complemento = TextEditingController(text: a.complemento ?? '');
  }

  @override
  void didUpdateWidget(covariant _EnderecoAssessorFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assessor.id != widget.assessor.id) {
      final a = widget.assessor;
      _cep.text = a.cep ?? '';
      _logradouro.text = a.logradouro ?? '';
      _numero.text = a.numero ?? '';
      _complemento.text = a.complemento ?? '';
    }
  }

  @override
  void dispose() {
    _cep.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      await ref.read(atualizarMeuAssessorEnderecoProvider)(
        AtualizarMeuAssessorEnderecoParams(
          cep: _cep.text.trim(),
          logradouro: _logradouro.text.trim(),
          numero: _numero.text.trim(),
          complemento: _complemento.text.trim(),
        ),
      );
      ref.invalidate(meuAssessorRegistroProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Endereço salvo')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _cep,
          decoration: const InputDecoration(
              labelText: 'CEP', prefixIcon: Icon(Icons.pin_outlined)),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _logradouro,
          decoration: const InputDecoration(
              labelText: 'Rua / logradouro',
              prefixIcon: Icon(Icons.signpost_outlined)),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _numero,
          decoration: const InputDecoration(
              labelText: 'Número', prefixIcon: Icon(Icons.numbers_outlined)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _complemento,
          decoration: const InputDecoration(
              labelText: 'Complemento',
              prefixIcon: Icon(Icons.apartment_outlined)),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: _saving ? null : _salvar,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar endereço'),
        ),
        const SizedBox(height: 4),
        Text(
          'Independente do botão "Salvar perfil" acima.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

