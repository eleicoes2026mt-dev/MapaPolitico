import '../../models/apoiador.dart';
import '../../models/municipio.dart';
import '../../features/mapa/data/mt_municipios_coords.dart';

/// Se o CEP for de MT, retorna a chave normalizada do município quando constar na lista oficial.
String? chaveMunicipioMtApartirCepLocalidade(String? localidade, String? uf) {
  if (localidade == null || localidade.trim().isEmpty) return null;
  if ((uf ?? '').trim().toUpperCase() != 'MT') return null;
  final key = normalizarNomeMunicipioMT(localidade.trim());
  if (key.isEmpty) return null;
  if (listCidadesMTNomesNormalizados.contains(key)) return key;
  return null;
}

/// Resolve [municipio_id] a partir do nome da cidade (tabela `municipios`).
String? municipioIdParaNomeCidade(String? cidadeNome, List<Municipio> municipios) {
  if (cidadeNome == null || cidadeNome.trim().isEmpty) return null;
  final key = normalizarNomeMunicipioMT(cidadeNome.trim());
  for (final m in municipios) {
    if (normalizarNomeMunicipioMT(m.nome.trim()) == key) return m.id;
    if (normalizarNomeMunicipioMT(m.nomeNormalizado.trim()) == key) return m.id;
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
