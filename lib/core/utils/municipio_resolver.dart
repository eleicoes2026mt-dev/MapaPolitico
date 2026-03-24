import '../../models/apoiador.dart';
import '../../models/municipio.dart';
import '../../features/mapa/data/mt_municipios_coords.dart';

/// Resolve [municipio_id] a partir do nome da cidade (tabela `municipios`).
String? municipioIdParaNomeCidade(String? cidadeNome, List<Municipio> municipios) {
  if (cidadeNome == null || cidadeNome.trim().isEmpty) return null;
  final key = normalizarNomeMunicipioMT(cidadeNome);
  for (final m in municipios) {
    if (normalizarNomeMunicipioMT(m.nome) == key) return m.id;
    if (normalizarNomeMunicipioMT(m.nomeNormalizado) == key) return m.id;
  }
  return null;
}

/// Usa `municipio_id` quando válido na lista; senão tenta casar `cidade_nome` com um município.
/// Cobre cadastros antigos que só tinham texto de cidade (sem UUID).
String? municipioIdResolvidoParaApoiador(Apoiador? ap, List<Municipio> municipios) {
  if (ap == null) return null;
  final id = ap.municipioId?.trim();
  if (id != null && id.isNotEmpty && municipios.any((m) => m.id == id)) {
    return id;
  }
  return municipioIdParaNomeCidade(ap.cidadeNome, municipios);
}
