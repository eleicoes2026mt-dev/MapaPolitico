import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dados retornados pela API Brasil (GET /api/cnpj/v1/{cnpj}).
class DadosCnpjBrasilApi {
  const DadosCnpjBrasilApi({
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.situacaoCadastral,
    required this.municipio,
    required this.uf,
    this.logradouro,
    this.numero,
    this.bairro,
    this.cep,
    this.complemento,
  });

  final String razaoSocial;
  final String nomeFantasia;
  final String situacaoCadastral;
  final String municipio;
  final String uf;
  final String? logradouro;
  final String? numero;
  final String? bairro;
  final String? cep;
  final String? complemento;

  String get enderecoCompleto {
    final parts = <String>[];
    if (logradouro != null && logradouro!.isNotEmpty) parts.add(logradouro!);
    if (numero != null && numero!.isNotEmpty) parts.add('nº $numero');
    if (bairro != null && bairro!.isNotEmpty) parts.add(bairro!);
    if (municipio.isNotEmpty) parts.add('$municipio/$uf');
    if (cep != null && cep!.isNotEmpty) parts.add('CEP $cep');
    return parts.join(', ');
  }

  static Future<DadosCnpjBrasilApi> buscar(String cnpj) async {
    final digits = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 14) throw Exception('CNPJ deve ter 14 dígitos.');
    final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$digits');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      if (response.statusCode == 404) throw Exception('CNPJ não encontrado.');
      throw Exception('Erro ao consultar CNPJ: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final razao = json['razao_social'] as String? ?? '';
    final fantasia = json['nome_fantasia'] as String? ?? '';
    final situacao = json['descricao_situacao_cadastral'] as String? ?? '';
    final municipio = (json['municipio'] as String? ?? '').trim();
    final uf = json['uf'] as String? ?? '';
    final logradouro = json['logradouro'] as String?;
    final numero = json['numero'] as String?;
    final bairro = json['bairro'] as String?;
    final cep = json['cep'] as String?;
    final complemento = json['complemento'] as String?;
    return DadosCnpjBrasilApi(
      razaoSocial: razao,
      nomeFantasia: fantasia,
      situacaoCadastral: situacao,
      municipio: municipio,
      uf: uf,
      logradouro: logradouro,
      numero: numero,
      bairro: bairro,
      cep: cep,
      complemento: complemento,
    );
  }
}
