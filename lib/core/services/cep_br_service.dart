import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de consulta de CEP (BrasilAPI ou ViaCEP).
class CepBrResult {
  const CepBrResult({
    required this.logradouro,
    this.complemento,
    this.bairro,
    required this.localidade,
    required this.uf,
    required this.cep,
  });

  final String logradouro;
  final String? complemento;
  final String? bairro;
  final String localidade;
  final String uf;
  final String cep;
}

/// Busca endereço por CEP (8 dígitos). Tenta [BrasilAPI](https://brasilapi.com.br) e depois ViaCEP.
Future<CepBrResult?> fetchCepBr(String cepDigits) async {
  final clean = cepDigits.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.length != 8) return null;

  CepBrResult? fromBrasilApi(Map<String, dynamic> j) {
    final street = (j['street'] as String?)?.trim() ?? '';
    final city = (j['city'] as String?)?.trim() ?? '';
    final uf = (j['state'] as String?)?.trim() ?? '';
    if (city.isEmpty && street.isEmpty) return null;
    // Sem cidade na BrasilAPI: tentar ViaCEP (evita localidade vazia e perda de vínculo com MT).
    if (city.isEmpty) return null;
    return CepBrResult(
      logradouro: street,
      complemento: null,
      bairro: (j['neighborhood'] as String?)?.trim(),
      localidade: city,
      uf: uf,
      cep: (j['cep'] as String?)?.replaceAll(RegExp(r'[^\d]'), '') ?? clean,
    );
  }

  CepBrResult? fromViaCep(Map<String, dynamic> j) {
    if (j['erro'] == true) return null;
    final loc = (j['localidade'] as String?)?.trim() ?? '';
    final log = (j['logradouro'] as String?)?.trim() ?? '';
    if (loc.isEmpty && log.isEmpty) return null;
    return CepBrResult(
      logradouro: log,
      complemento: (j['complemento'] as String?)?.trim(),
      bairro: (j['bairro'] as String?)?.trim(),
      localidade: loc,
      uf: (j['uf'] as String?)?.trim() ?? '',
      cep: (j['cep'] as String?)?.replaceAll(RegExp(r'[^\d]'), '') ?? clean,
    );
  }

  try {
    final r = await http
        .get(Uri.parse('https://brasilapi.com.br/api/cep/v1/$clean'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final out = fromBrasilApi(j);
      if (out != null) return out;
    }
  } catch (_) {}

  try {
    final r = await http
        .get(Uri.parse('https://viacep.com.br/ws/$clean/json/'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return fromViaCep(j);
    }
  } catch (_) {}

  return null;
}
