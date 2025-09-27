import 'package:intl/intl.dart';

class InventarioItem {
  final int item;
  final int codigo;
  final String barras;
  final String produto;
  final String unidade;
  final double estoqueAtual;
  final double novoEstoque;
  final DateTime dtCriacao;

  InventarioItem({
    required this.item,
    required this.codigo,
    required this.barras,
    required this.produto,
    required this.unidade,
    required this.estoqueAtual,
    required this.novoEstoque,
    DateTime? dtCriacao,
  }) : dtCriacao = dtCriacao ?? DateTime.now();

  // Formatação da data/hora para exibição
  String get dtCriacaoFormatada {
    return DateFormat('dd/MM HH:mm').format(dtCriacao);
  }

  // Conversão para JSON para envio à API
  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'barras': barras,
      'produto': produto,
      'un': unidade,
      'qtd': novoEstoque,
      'dt_criacao': DateFormat('dd/MM/yyyy HH:mm:ss').format(dtCriacao),
      'danfe_etq': '',
    };
  }

  // Criação a partir de JSON (se necessário)
  factory InventarioItem.fromJson(Map<String, dynamic> json, int itemNumber) {
    return InventarioItem(
      item: itemNumber,
      codigo: json['codigo'] ?? 0,
      barras: json['barras'] ?? '',
      produto: json['produto'] ?? '',
      unidade: json['un'] ?? '',
      estoqueAtual: (json['estoque_atual'] ?? 0.0).toDouble(),
      novoEstoque: (json['qtd'] ?? 0.0).toDouble(),
      dtCriacao: json['dt_criacao'] != null 
          ? DateTime.tryParse(json['dt_criacao']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Método copyWith para criar cópias com modificações
  InventarioItem copyWith({
    int? item,
    int? codigo,
    String? barras,
    String? produto,
    String? unidade,
    double? estoqueAtual,
    double? novoEstoque,
    DateTime? dtCriacao,
  }) {
    return InventarioItem(
      item: item ?? this.item,
      codigo: codigo ?? this.codigo,
      barras: barras ?? this.barras,
      produto: produto ?? this.produto,
      unidade: unidade ?? this.unidade,
      estoqueAtual: estoqueAtual ?? this.estoqueAtual,
      novoEstoque: novoEstoque ?? this.novoEstoque,
      dtCriacao: dtCriacao ?? this.dtCriacao,
    );
  }

  @override
  String toString() {
    return 'InventarioItem(item: $item, codigo: $codigo, barras: $barras, produto: $produto, unidade: $unidade, estoqueAtual: $estoqueAtual, novoEstoque: $novoEstoque, dtCriacao: $dtCriacao)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventarioItem &&
        other.item == item &&
        other.codigo == codigo &&
        other.barras == barras &&
        other.produto == produto &&
        other.unidade == unidade &&
        other.estoqueAtual == estoqueAtual &&
        other.novoEstoque == novoEstoque &&
        other.dtCriacao == dtCriacao;
  }

  @override
  int get hashCode {
    return Object.hash(
      item,
      codigo,
      barras,
      produto,
      unidade,
      estoqueAtual,
      novoEstoque,
      dtCriacao,
    );
  }
}

class InventarioRequest {
  final String coleta;
  final int imei;
  final List<InventarioItem> itens;

  InventarioRequest({
    this.coleta = 'INVENTARIO',
    this.imei = 7829,
    required this.itens,
  });

  Map<String, dynamic> toJson() {
    return {
      'coleta': coleta,
      'imei': imei,
      'itens': itens.map((item) => item.toJson()).toList(),
    };
  }

  factory InventarioRequest.fromJson(Map<String, dynamic> json) {
    return InventarioRequest(
      coleta: json['coleta'] ?? 'INVENTARIO',
      imei: json['imei'] ?? 7829,
      itens: (json['itens'] as List<dynamic>?)
          ?.asMap()
          .entries
          .map((entry) => InventarioItem.fromJson(entry.value, entry.key + 1))
          .toList() ?? [],
    );
  }
}