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
  'ACORIZAL': const LatLng(-15.1944, -56.3639),
  'AGUA BOA': const LatLng(-14.0506, -52.1597),
  'ALTA FLORESTA': const LatLng(-9.8756, -56.0861),
  'ALTO ARAGUAIA': const LatLng(-17.3147, -53.2181),
  'ALTO BOA VISTA': const LatLng(-11.6733, -51.3883),
  'ALTO GARÇAS': const LatLng(-16.9461, -53.5278),
  'ALTO PARAGUAI': const LatLng(-14.5139, -56.4778),
  'ALTO TAQUARI': const LatLng(-17.8242, -53.2792),
  'APIACAS': const LatLng(-9.5397, -57.4589),
  'ARAGUAIANA': const LatLng(-15.7292, -51.8342),
  'ARAGUAINHA': const LatLng(-15.7296, -52.2011),
  'ARAPUTANGA': const LatLng(-15.4692, -58.3419),
  'ARENAPOLIS': const LatLng(-14.4342, -56.8422),
  'ARIPUANA': const LatLng(-9.1667, -60.6333),
  'BARAO DE MELGACO': const LatLng(-16.1944, -55.9669),
  'BARRA DO BUGRES': const LatLng(-15.0728, -57.1878),
  'BARRA DO GARCAS': const LatLng(-15.8900, -52.2569),
  'BOM JESUS DO ARAGUAIA': const LatLng(-12.1706, -51.5031),
  'BOA ESPERANCA DO NORTE': const LatLng(-12.2894, -55.6153),
  'BRASNORTE': const LatLng(-12.5500, -51.8000),
  'CACERES': const LatLng(-16.0714, -57.6819),
  'CAMPINAPOLIS': const LatLng(-14.5056, -52.8933),
  'CAMPO NOVO DO PARECIS': const LatLng(-13.6772, -57.8911),
  'CAMPO VERDE': const LatLng(-15.5453, -55.1625),
  'CAMPOS DE JULIO': const LatLng(-13.7222, -59.2667),
  'CANABRAVA DO NORTE': const LatLng(-11.0333, -51.8500),
  'CANARANA': const LatLng(-13.5519, -52.2706),
  'CARLINDA': const LatLng(-9.9500, -55.8333),
  'CASTANHEIRA': const LatLng(-11.1250, -58.6083),
  'CHAPADA DOS GUIMARAES': const LatLng(-15.4642, -55.7497),
  'CLAUDIA': const LatLng(-11.5075, -54.5553),
  'COCALINHO': const LatLng(-14.3903, -51.0000),
  'COLIDER': const LatLng(-10.8133, -55.4606),
  'COLNIZA': const LatLng(-9.4167, -59.0333),
  'COMODORO': const LatLng(-13.6614, -59.7856),
  'CONFRESA': const LatLng(-10.6436, -51.5694),
  'CONQUISTA D\'OESTE': const LatLng(-14.5381, -59.5453),
  'COTRIGUACU': const LatLng(-9.8833, -58.5667),
  'CUIABA': const LatLng(-15.6014, -56.0979),
  'CURVELANDIA': const LatLng(-15.6083, -57.0958),
  'DENISE': const LatLng(-14.7383, -57.0583),
  'DIAMANTINO': const LatLng(-14.4069, -56.4367),
  'DOM AQUINO': const LatLng(-15.8097, -54.9211),
  'FELIZ NATAL': const LatLng(-12.3850, -54.9228),
  'FIGUEIROPOLIS D\'OESTE': const LatLng(-15.4439, -58.7389),
  'GAUCHA DO NORTE': const LatLng(-13.2442, -53.0808),
  'GENERAL CARNEIRO': const LatLng(-15.7094, -52.7572),
  'GLORIA D\'OESTE': const LatLng(-15.7686, -58.3108),
  'GUARANTA DO NORTE': const LatLng(-9.7856, -54.9092),
  'GUIRATINGA': const LatLng(-16.3458, -53.7581),
  'INDIAVAI': const LatLng(-15.4911, -58.5803),
  'IPIRANGA DO NORTE': const LatLng(-12.2417, -56.1536),
  'ITANHANGÁ': const LatLng(-12.2258, -56.6464),
  'ITAUBA': const LatLng(-11.0614, -55.2764),
  'ITIQUIRA': const LatLng(-17.2136, -54.1422),
  'JACIARA': const LatLng(-15.9653, -54.9522),
  'JANGADA': const LatLng(-15.2358, -56.4917),
  'JAURU': const LatLng(-15.3342, -58.8722),
  'JUARA': const LatLng(-11.2639, -57.5244),
  'JUINA': const LatLng(-11.3778, -58.7406),
  'JURUENA': const LatLng(-10.3172, -58.3592),
  'JUSCIMEIRA': const LatLng(-16.0553, -54.8819),
  'LAMBARI D\'OESTE': const LatLng(-15.3189, -58.0042),
  'LUCAS DO RIO VERDE': const LatLng(-13.0581, -55.9142),
  'LUCIARA': const LatLng(-11.2219, -50.6664),
  'MARCELANDIA': const LatLng(-11.0464, -54.4378),
  'MATUPA': const LatLng(-10.2833, -54.9333),
  'MIRASSOL D\'OESTE': const LatLng(-15.6758, -58.0953),
  'NOBRES': const LatLng(-14.7192, -56.3283),
  'NORTELANDIA': const LatLng(-14.4542, -56.8028),
  'NOSSA SENHORA DO LIVRAMENTO': const LatLng(-15.7769, -56.3431),
  'NOVA BANDEIRANTES': const LatLng(-9.8167, -57.8667),
  'NOVA BRASILANDIA': const LatLng(-14.9611, -54.9689),
  'NOVA CANAA DO NORTE': const LatLng(-10.5581, -55.9531),
  'NOVA GUARITA': const LatLng(-10.3142, -55.3261),
  'NOVA LACERDA': const LatLng(-14.4728, -59.6003),
  'NOVA MARILANDIA': const LatLng(-14.3628, -56.9706),
  'NOVA MARINGA': const LatLng(-13.0136, -57.0908),
  'NOVA MONTE VERDE': const LatLng(-9.9833, -57.4667),
  'NOVA MUTUM': const LatLng(-13.8386, -56.0839),
  'NOVA NAZARE': const LatLng(-13.9886, -51.2036),
  'NOVA OLIMPIA': const LatLng(-14.7972, -57.2883),
  'NOVA SANTA HELENA': const LatLng(-10.8167, -55.1667),
  'NOVA UBIRATA': const LatLng(-12.9833, -55.2556),
  'NOVA XAVANTINA': const LatLng(-14.6761, -52.3550),
  'NOVO HORIZONTE DO NORTE': const LatLng(-11.4083, -57.1658),
  'NOVO MUNDO': const LatLng(-9.9561, -55.2003),
  'NOVO SANTO ANTONIO': const LatLng(-12.2883, -50.9672),
  'NOVO SAO JOAQUIM': const LatLng(-14.9053, -53.0192),
  'PARANAITA': const LatLng(-9.6642, -56.4731),
  'PARANATINGA': const LatLng(-14.4267, -54.0528),
  'PEDRA PRETA': const LatLng(-16.6242, -54.4728),
  'PEIXOTO DE AZEVEDO': const LatLng(-10.2231, -54.9794),
  'PLANALTO DA SERRA': const LatLng(-14.6653, -54.7814),
  'POCONE': const LatLng(-16.2567, -56.6228),
  'PONTAL DO ARAGUAIA': const LatLng(-16.0139, -52.8378),
  'PONTE BRANCA': const LatLng(-16.8064, -52.8347),
  'PONTES E LACERDA': const LatLng(-15.2261, -59.3433),
  'PORTO ALEGRE DO NORTE': const LatLng(-10.8761, -51.6356),
  'PORTO DOS GAUCHOS': const LatLng(-11.5333, -57.4167),
  'PORTO ESPERIDIAO': const LatLng(-15.8572, -58.4719),
  'PORTO ESTRELA': const LatLng(-15.3231, -57.2206),
  'POXOREO': const LatLng(-15.8372, -54.3892),
  'PRIMAVERA DO LESTE': const LatLng(-15.5628, -54.3011),
  'QUERENCIA': const LatLng(-12.6092, -52.1822),
  'RESERVA DO CABACAL': const LatLng(-15.0753, -58.4678),
  'RIBEIRAO CASCALHEIRA': const LatLng(-12.9367, -51.8244),
  'RIBEIRAOZINHO': const LatLng(-16.4856, -52.6922),
  'RIO BRANCO': const LatLng(-15.2483, -58.2472),
  'RONDOLANDIA': const LatLng(-10.8386, -61.4697),
  'RONDONOPOLIS': const LatLng(-16.4677, -54.6362),
  'ROSARIO OESTE': const LatLng(-14.8361, -56.4275),
  'SALTO DO CEU': const LatLng(-15.1303, -58.1317),
  'SANTA CARMEM': const LatLng(-11.9500, -55.2833),
  'SANTA CRUZ DO XINGU': const LatLng(-10.1531, -52.3953),
  'SANTA RITA DO TRIVELATO': const LatLng(-13.8144, -55.2692),
  'SANTA TEREZINHA': const LatLng(-10.4703, -50.5142),
  'SANTO AFONSO': const LatLng(-14.4942, -57.0061),
  'SANTO ANTONIO DO LESTE': const LatLng(-15.8667, -53.7833),
  'SANTO ANTONIO DO LEVERGER': const LatLng(-15.8631, -56.0786),
  'SAO FELIX DO ARAGUAIA': const LatLng(-11.6150, -50.6706),
  'SAO JOSE DO POVO': const LatLng(-16.4542, -54.2486),
  'SAO JOSE DO RIO CLARO': const LatLng(-13.4911, -56.7214),
  'SAO JOSE DO XINGU': const LatLng(-10.7983, -52.7386),
  'SAO JOSE DOS QUATRO MARCOS': const LatLng(-15.6278, -58.1772),
  'SAO PEDRO DA CIPA': const LatLng(-16.0008, -54.9206),
  'SAPEZAL': const LatLng(-12.9833, -58.7667),
  'SERRA NOVA DOURADA': const LatLng(-12.0894, -51.4025),
  'SINOP': const LatLng(-11.8642, -55.5094),
  'SORRISO': const LatLng(-12.5422, -55.7211),
  'TABAPORA': const LatLng(-11.3008, -56.8311),
  'TANGARA DA SERRA': const LatLng(-14.6229, -57.4933),
  'TAPURAH': const LatLng(-12.5333, -56.5167),
  'TERRA NOVA DO NORTE': const LatLng(-10.5167, -55.2333),
  'TESOURO': const LatLng(-16.0806, -53.5592),
  'TORIXOREU': const LatLng(-16.2006, -52.5569),
  'UNIAO DO SUL': const LatLng(-11.5306, -54.3614),
  'VALE DE SAO DOMINGOS': const LatLng(-15.2933, -59.0681),
  'VARZEA GRANDE': const LatLng(-15.6467, -56.1325),
  'VERA': const LatLng(-12.3167, -55.3167),
  'VILA RICA': const LatLng(-10.0136, -51.1186),
  'VILA BELA DA SANTISSIMA TRINDADE': const LatLng(-15.0089, -59.9508),
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
  return upper
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
