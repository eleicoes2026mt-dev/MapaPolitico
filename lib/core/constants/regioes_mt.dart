import 'package:flutter/material.dart';

/// Região geográfica intermediária de MT (IBGE), alinhada ao mapa e às abas Estratégia.
class RegiaoMT {
  const RegiaoMT({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.cor,
    this.ordem = 0,
  });

  final String id;
  final String nome;
  final String descricao;
  final Color cor;
  final int ordem;
}

/// As 5 regiões intermediárias de Mato Grosso (CD_RGINT), na ordem do mapa.
/// Usado em: Mapa Regional, Metas e Responsáveis.
const List<RegiaoMT> regioesIntermediariasMT = [
  RegiaoMT(
    id: '5101',
    nome: 'Cuiabá',
    descricao: 'Centro-Sul - 30 municípios',
    cor: Colors.blue,
    ordem: 1,
  ),
  RegiaoMT(
    id: '5102',
    nome: 'Cáceres',
    descricao: 'Sudoeste/Oeste - 41 municípios',
    cor: Colors.green,
    ordem: 2,
  ),
  RegiaoMT(
    id: '5103',
    nome: 'Sinop',
    descricao: 'Norte - 43 municípios',
    cor: Colors.orange,
    ordem: 3,
  ),
  RegiaoMT(
    id: '5104',
    nome: 'Barra do Garças',
    descricao: 'Leste - 30 municípios',
    cor: Colors.purple,
    ordem: 4,
  ),
  RegiaoMT(
    id: '5105',
    nome: 'Rondonópolis',
    descricao: 'Sudeste - 18 municípios',
    cor: Colors.red,
    ordem: 5,
  ),
];
