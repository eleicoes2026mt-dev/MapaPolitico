import '../../../../core/geo/lat_lng.dart';

/// Normaliza nome do município para busca (remove acentos, maiúsculas).
String _norm(String s) {
  const withAccent = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const noAccent = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  var r = s.trim().toUpperCase();
  for (var i = 0; i < withAccent.length; i++) {
    r = r.replaceAll(withAccent[i], noAccent[i]);
  }
  return r;
}

/// Normalização pública (mesma lógica de getCoordsMunicipioMT) para agrupar cidades.
String normalizarNomeMunicipioMT(String s) => _norm(s);

/// Coordenadas aproximadas (centro/sede) de municípios de MT.
final _coords = <String, LatLng>{
  'ACORIZAL': LatLng(-15.1944, -56.3639),
  'AGUA BOA': LatLng(-14.0506, -52.1597),
  'ALTA FLORESTA': LatLng(-9.8756, -56.0861),
  'ALTO ARAGUAIA': LatLng(-17.3147, -53.2181),
  'ALTO BOA VISTA': LatLng(-11.6733, -51.3883),
  'ALTO GARÇAS': LatLng(-16.9461, -53.5278),
  'ALTO PARAGUAI': LatLng(-14.5139, -56.4778),
  'ALTO TAQUARI': LatLng(-17.8242, -53.2792),
  'APIACAS': LatLng(-9.5397, -57.4589),
  'ARAGUAIANA': LatLng(-15.7292, -51.8342),
  'ARAGUAINHA': LatLng(-15.7296, -52.2011),
  'ARAPUTANGA': LatLng(-15.4692, -58.3419),
  'ARENAPOLIS': LatLng(-14.4342, -56.8422),
  'ARIPUANA': LatLng(-9.1667, -60.6333),
  'BARAO DE MELGACO': LatLng(-16.1944, -55.9669),
  'BARRA DO BUGRES': LatLng(-15.0728, -57.1878),
  'BARRA DO GARCAS': LatLng(-15.8900, -52.2569),
  'BOM JESUS DO ARAGUAIA': LatLng(-12.1706, -51.5031),
  'BOA ESPERANCA DO NORTE': LatLng(-12.2894, -55.6153),
  'BRASNORTE': LatLng(-12.5500, -51.8000),
  'CACERES': LatLng(-16.0714, -57.6819),
  'CAMPINAPOLIS': LatLng(-14.5056, -52.8933),
  'CAMPO NOVO DO PARECIS': LatLng(-13.6772, -57.8911),
  'CAMPO VERDE': LatLng(-15.5453, -55.1625),
  'CAMPOS DE JULIO': LatLng(-13.7222, -59.2667),
  'CANABRAVA DO NORTE': LatLng(-11.0333, -51.8500),
  'CANARANA': LatLng(-13.5519, -52.2706),
  'CARLINDA': LatLng(-9.9500, -55.8333),
  'CASTANHEIRA': LatLng(-11.1250, -58.6083),
  'CHAPADA DOS GUIMARAES': LatLng(-15.4642, -55.7497),
  'CLAUDIA': LatLng(-11.5075, -54.5553),
  'COCALINHO': LatLng(-14.3903, -51.0000),
  'COLIDER': LatLng(-10.8133, -55.4606),
  'COLNIZA': LatLng(-9.4167, -59.0333),
  'COMODORO': LatLng(-13.6614, -59.7856),
  'CONFRESA': LatLng(-10.6436, -51.5694),
  'CONQUISTA D\'OESTE': LatLng(-14.5381, -59.5453),
  'COTRIGUACU': LatLng(-9.8833, -58.5667),
  'CUIABA': LatLng(-15.6014, -56.0979),
  'CURVELANDIA': LatLng(-15.6083, -57.0958),
  'DENISE': LatLng(-14.7383, -57.0583),
  'DIAMANTINO': LatLng(-14.4069, -56.4367),
  'DOM AQUINO': LatLng(-15.8097, -54.9211),
  'FELIZ NATAL': LatLng(-12.3850, -54.9228),
  'FIGUEIROPOLIS D\'OESTE': LatLng(-15.4439, -58.7389),
  'GAUCHA DO NORTE': LatLng(-13.2442, -53.0808),
  'GENERAL CARNEIRO': LatLng(-15.7094, -52.7572),
  'GLORIA D\'OESTE': LatLng(-15.7686, -58.3108),
  'GUARANTA DO NORTE': LatLng(-9.7856, -54.9092),
  'GUIRATINGA': LatLng(-16.3458, -53.7581),
  'INDIAVAI': LatLng(-15.4911, -58.5803),
  'IPIRANGA DO NORTE': LatLng(-12.2417, -56.1536),
  'ITANHANGÁ': LatLng(-12.2258, -56.6464),
  'ITAUBA': LatLng(-11.0614, -55.2764),
  'ITIQUIRA': LatLng(-17.2136, -54.1422),
  'JACIARA': LatLng(-15.9653, -54.9522),
  'JANGADA': LatLng(-15.2358, -56.4917),
  'JAURU': LatLng(-15.3342, -58.8722),
  'JUARA': LatLng(-11.2639, -57.5244),
  'JUINA': LatLng(-11.3778, -58.7406),
  'JURUENA': LatLng(-10.3172, -58.3592),
  'JUSCIMEIRA': LatLng(-16.0553, -54.8819),
  'LAMBARI D\'OESTE': LatLng(-15.3189, -58.0042),
  'LUCAS DO RIO VERDE': LatLng(-13.0581, -55.9142),
  'LUCIARA': LatLng(-11.2219, -50.6664),
  'MARCELANDIA': LatLng(-11.0464, -54.4378),
  'MATUPA': LatLng(-10.2833, -54.9333),
  'MIRASSOL D\'OESTE': LatLng(-15.6758, -58.0953),
  'NOBRES': LatLng(-14.7192, -56.3283),
  'NORTELANDIA': LatLng(-14.4542, -56.8028),
  'NOSSA SENHORA DO LIVRAMENTO': LatLng(-15.7769, -56.3431),
  'NOVA BANDEIRANTES': LatLng(-9.8167, -57.8667),
  'NOVA BRASILANDIA': LatLng(-14.9611, -54.9689),
  'NOVA CANAA DO NORTE': LatLng(-10.5581, -55.9531),
  'NOVA GUARITA': LatLng(-10.3142, -55.3261),
  'NOVA LACERDA': LatLng(-14.4728, -59.6003),
  'NOVA MARILANDIA': LatLng(-14.3628, -56.9706),
  'NOVA MARINGA': LatLng(-13.0136, -57.0908),
  'NOVA MONTE VERDE': LatLng(-9.9833, -57.4667),
  'NOVA MUTUM': LatLng(-13.8386, -56.0839),
  'NOVA NAZARE': LatLng(-13.9886, -51.2036),
  'NOVA OLIMPIA': LatLng(-14.7972, -57.2883),
  'NOVA SANTA HELENA': LatLng(-10.8167, -55.1667),
  'NOVA UBIRATA': LatLng(-12.9833, -55.2556),
  'NOVA XAVANTINA': LatLng(-14.6761, -52.3550),
  'NOVO HORIZONTE DO NORTE': LatLng(-11.4083, -57.1658),
  'NOVO MUNDO': LatLng(-9.9561, -55.2003),
  'NOVO SANTO ANTONIO': LatLng(-12.2883, -50.9672),
  'NOVO SAO JOAQUIM': LatLng(-14.9053, -53.0192),
  'PARANAITA': LatLng(-9.6642, -56.4731),
  'PARANATINGA': LatLng(-14.4267, -54.0528),
  'PEDRA PRETA': LatLng(-16.6242, -54.4728),
  'PEIXOTO DE AZEVEDO': LatLng(-10.2231, -54.9794),
  'PLANALTO DA SERRA': LatLng(-14.6653, -54.7814),
  'POCONE': LatLng(-16.2567, -56.6228),
  'PONTAL DO ARAGUAIA': LatLng(-16.0139, -52.8378),
  'PONTE BRANCA': LatLng(-16.8064, -52.8347),
  'PONTES E LACERDA': LatLng(-15.2261, -59.3433),
  'PORTO ALEGRE DO NORTE': LatLng(-10.8761, -51.6356),
  'PORTO DOS GAUCHOS': LatLng(-11.5333, -57.4167),
  'PORTO ESPERIDIAO': LatLng(-15.8572, -58.4719),
  'PORTO ESTRELA': LatLng(-15.3231, -57.2206),
  'POXOREO': LatLng(-15.8372, -54.3892),
  'PRIMAVERA DO LESTE': LatLng(-15.5628, -54.3011),
  'QUERENCIA': LatLng(-12.6092, -52.1822),
  'RESERVA DO CABACAL': LatLng(-15.0753, -58.4678),
  'RIBEIRAO CASCALHEIRA': LatLng(-12.9367, -51.8244),
  'RIBEIRAOZINHO': LatLng(-16.4856, -52.6922),
  'RIO BRANCO': LatLng(-15.2483, -58.2472),
  'RONDOLANDIA': LatLng(-10.8386, -61.4697),
  'RONDONOPOLIS': LatLng(-16.4677, -54.6362),
  'ROSARIO OESTE': LatLng(-14.8361, -56.4275),
  'SALTO DO CEU': LatLng(-15.1303, -58.1317),
  'SANTA CARMEM': LatLng(-11.9500, -55.2833),
  'SANTA CRUZ DO XINGU': LatLng(-10.1531, -52.3953),
  'SANTA RITA DO TRIVELATO': LatLng(-13.8144, -55.2692),
  'SANTA TEREZINHA': LatLng(-10.4703, -50.5142),
  'SANTO AFONSO': LatLng(-14.4942, -57.0061),
  'SANTO ANTONIO DO LESTE': LatLng(-15.8667, -53.7833),
  'SANTO ANTONIO DO LEVERGER': LatLng(-15.8631, -56.0786),
  'SAO FELIX DO ARAGUAIA': LatLng(-11.6150, -50.6706),
  'SAO JOSE DO POVO': LatLng(-16.4542, -54.2486),
  'SAO JOSE DO RIO CLARO': LatLng(-13.4911, -56.7214),
  'SAO JOSE DO XINGU': LatLng(-10.7983, -52.7386),
  'SAO JOSE DOS QUATRO MARCOS': LatLng(-15.6278, -58.1772),
  'SAO PEDRO DA CIPA': LatLng(-16.0008, -54.9206),
  'SAPEZAL': LatLng(-12.9833, -58.7667),
  'SERRA NOVA DOURADA': LatLng(-12.0894, -51.4025),
  'SINOP': LatLng(-11.8642, -55.5094),
  'SORRISO': LatLng(-12.5422, -55.7211),
  'TABAPORA': LatLng(-11.3008, -56.8311),
  'TANGARA DA SERRA': LatLng(-14.6229, -57.4933),
  'TAPURAH': LatLng(-12.5333, -56.5167),
  'TERRA NOVA DO NORTE': LatLng(-10.5167, -55.2333),
  'TESOURO': LatLng(-16.0806, -53.5592),
  'TORIXOREU': LatLng(-16.2006, -52.5569),
  'UNIAO DO SUL': LatLng(-11.5306, -54.3614),
  'VALE DE SAO DOMINGOS': LatLng(-15.2933, -59.0681),
  'VARZEA GRANDE': LatLng(-15.6467, -56.1325),
  'VERA': LatLng(-12.3167, -55.3167),
  'VILA RICA': LatLng(-10.0136, -51.1186),
  'VILA BELA DA SANTISSIMA TRINDADE': LatLng(-15.0089, -59.9508),
};

LatLng? getCoordsMunicipioMT(String nomeMunicipio) {
  return _coords[_norm(nomeMunicipio)];
}

/// Lista de nomes normalizados (uppercase, sem acento) dos municípios de MT, ordenada.
List<String> get listCidadesMTNomesNormalizados {
  final keys = _coords.keys.toList();
  keys.sort();
  return keys;
}

/// Converte nome normalizado para exibição (ex.: VARZEA GRANDE -> Várzea Grande).
String displayNomeCidadeMT(String nomeNormalizado) {
  const map = {
    'AGUA BOA': 'Água Boa',
    'ALTO GARÇAS': 'Alto Garças',
    'ARAGUAIANA': 'Araguaiana',
    'BARRA DO GARCAS': 'Barra do Garças',
    'CACERES': 'Cáceres',
    'CAMPO NOVO DO PARECIS': 'Campo Novo do Parecis',
    'CONFRESA': 'Confresa',
    'CUIABA': 'Cuiabá',
    'CURVELANDIA': 'Curvelândia',
    'FIGUEIROPOLIS D\'OESTE': 'Figueirópolis D\'Oeste',
    'GUARANTA DO NORTE': 'Guarantã do Norte',
    'JACIARA': 'Jaciara',
    'MIRASSOL D\'OESTE': 'Mirassol D\'Oeste',
    'NOSSA SENHORA DO LIVRAMENTO': 'Nossa Senhora do Livramento',
    'POCONE': 'Poconé',
    'SAO JOSE DOS QUATRO MARCOS': 'São José dos Quatro Marcos',
    'VARZEA GRANDE': 'Várzea Grande',
  };
  final upper = nomeNormalizado.trim().toUpperCase();
  if (map.containsKey(upper)) return map[upper]!;
  return upper.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
}
