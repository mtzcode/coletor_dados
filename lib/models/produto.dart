class Produto {
  final String codBarras;
  final String codProduto;
  final String produto;
  final String unidade;
  final double valorVenda;
  final DateTime dataHoraRequisicao;
  final int numeroItem;
  final String? dataAtualizacao;
  final double? qtdEstoque;
  String? tipoEtiqueta;

  Produto({
    required this.codBarras,
    required this.codProduto,
    required this.produto,
    required this.unidade,
    required this.valorVenda,
    required this.dataHoraRequisicao,
    required this.numeroItem,
    this.dataAtualizacao,
    this.qtdEstoque,
    this.tipoEtiqueta,
  });

  factory Produto.fromJson(Map<String, dynamic> json, int numeroItem) {
    // Função auxiliar para converter valores para double de forma segura
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    // Função auxiliar para converter valores para string de forma segura
    String parseString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    return Produto(
      codBarras: parseString(json['cod_barras']),
      codProduto: parseString(json['cod_produto']),
      produto: parseString(json['produto']),
      unidade: parseString(json['unidade']),
      valorVenda: parseDouble(json['valor_venda1']),
      dataHoraRequisicao: DateTime.now(),
      numeroItem: numeroItem,
      dataAtualizacao: json['data_atualizacao']?.toString(),
      qtdEstoque: parseDouble(json['qtd_estoque']),
      tipoEtiqueta: json['tipo_etiqueta']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_barras': codBarras,
      'cod_produto': codProduto,
      'produto': produto,
      'unidade': unidade,
      'valor_venda1': valorVenda,
      'data_hora_requisicao': dataHoraRequisicao.toIso8601String(),
      'numero_item': numeroItem,
      'data_atualizacao': dataAtualizacao,
      'qtd_estoque': qtdEstoque,
      'tipo_etiqueta': tipoEtiqueta,
    };
  }

  String get precoFormatado {
    return 'R\$ ${valorVenda.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String get dataHoraFormatada {
    return '${dataHoraRequisicao.day.toString().padLeft(2, '0')}/'
           '${dataHoraRequisicao.month.toString().padLeft(2, '0')}/'
           '${dataHoraRequisicao.year} '
           '${dataHoraRequisicao.hour.toString().padLeft(2, '0')}:'
           '${dataHoraRequisicao.minute.toString().padLeft(2, '0')}';
  }

  String get numeroItemFormatado {
    return 'Item ${numeroItem.toString().padLeft(3, '0')}';
  }

  String get dataAtualizacaoFormatada {
    if (dataAtualizacao == null || dataAtualizacao!.isEmpty) {
      return 'N/A';
    }
    try {
      final DateTime dateTime = DateTime.parse(dataAtualizacao!);
      return '${dateTime.day.toString().padLeft(2, '0')}/'
             '${dateTime.month.toString().padLeft(2, '0')}/'
             '${dateTime.year}';
    } catch (e) {
      return dataAtualizacao!;
    }
  }

  String get qtdEstoqueFormatada {
    if (qtdEstoque == null) {
      return 'N/A';
    }
    return qtdEstoque!.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class TipoEtiqueta {
  final String id;
  final String nome;
  final String descricao;

  TipoEtiqueta({
    required this.id,
    required this.nome,
    required this.descricao,
  });

  factory TipoEtiqueta.fromJson(Map<String, dynamic> json) {
    return TipoEtiqueta(
      id: json['codigo']?.toString() ?? '',      // API usa 'codigo'
      nome: json['etiqueta'] ?? '',              // API usa 'etiqueta'
      descricao: json['arquivo'] ?? '',          // API usa 'arquivo'
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': id,        // Mapeando de volta para o formato da API
      'etiqueta': nome,
      'arquivo': descricao,
    };
  }

  @override
  String toString() => nome;
}