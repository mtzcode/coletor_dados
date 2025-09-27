class EtiquetaColetor {
  final int? etqIdx;
  final int? etqId;
  final int? loteId;
  final String? etqCodmat;     // cod_produto da tabela produto
  final int? etqQtd;
  final String? etqEan13;      // cod_barras da tabela produto
  final String? etqDthora;     // data e hora do envio (26/09/2025 20:36:53)
  final String? etqDesc;       // produto da tabela produto
  final String? etqPosicao;
  final String? etqVal;
  final String? etqUn;         // unidade da tabela produto
  final String? etqPreco;
  final String? layetqText;    // tipo da etiqueta (GONDOLA GRANDE, GONDOLA PEQUENA, etc.)
  final String? gr7Status;
  final String? gr7DataHora;

  EtiquetaColetor({
    this.etqIdx,
    this.etqId,
    this.loteId,
    this.etqCodmat,
    this.etqQtd,
    this.etqEan13,
    this.etqDthora,
    this.etqDesc,
    this.etqPosicao,
    this.etqVal,
    this.etqUn,
    this.etqPreco,
    this.layetqText,
    this.gr7Status,
    this.gr7DataHora,
  });

  // Construtor factory para criar a partir de um Produto
  factory EtiquetaColetor.fromProduto({
    required String codProduto,
    required String codBarras,
    required String nomeProduto,
    required String unidade,
    required String tipoEtiqueta,
    int quantidade = 1,
    String? preco,
  }) {
    final now = DateTime.now();
    final dataHoraFormatada = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    
    return EtiquetaColetor(
      etqCodmat: codProduto,
      etqQtd: quantidade,
      etqEan13: codBarras,
      etqDthora: dataHoraFormatada,
      etqDesc: nomeProduto,
      etqUn: unidade,
      etqPreco: preco,
      layetqText: tipoEtiqueta,
    );
  }

  // Converter para JSON para envio ao servidor
  Map<String, dynamic> toJson() {
    return {
      // Campos INTEGER
      'ETQ_IDX': etqIdx ?? 0,
      'ETQ_ID': etqId ?? 0,
      'LOTE_ID': loteId ?? 0,
      'ETQ_QTD': etqQtd ?? 1,
      'ETQ_POSICAO': etqPosicao ?? 0,
      
      // Campos VARCHAR (strings)
      'ETQ_CODMAT': etqCodmat ?? '',
      'ETQ_EAN13': etqEan13 ?? '',
      'ETQ_DTHORA': etqDthora ?? DateTime.now().toIso8601String(),
      'ETQ_DESC': etqDesc ?? '',
      'ETQ_VAL': etqVal?.toString() ?? '0',
      'ETQ_UN': etqUn ?? '',
      'ETQ_PRECO': etqPreco?.toString() ?? '0',
      'LAYETQ_TEXT': layetqText ?? '',
      'gr7_status': 'A', // Status ativo
      'gr7_data_hora': DateTime.now().toIso8601String(),
    };
  }

  // Criar a partir de JSON
  factory EtiquetaColetor.fromJson(Map<String, dynamic> json) {
    return EtiquetaColetor(
      etqIdx: json['ETQ_IDX'],
      etqId: json['ETQ_ID'],
      loteId: json['LOTE_ID'],
      etqCodmat: json['ETQ_CODMAT'],
      etqQtd: json['ETQ_QTD'],
      etqEan13: json['ETQ_EAN13'],
      etqDthora: json['ETQ_DTHORA'],
      etqDesc: json['ETQ_DESC'],
      etqPosicao: json['ETQ_POSICAO'],
      etqVal: json['ETQ_VAL'],
      etqUn: json['ETQ_UN'],
      etqPreco: json['ETQ_PRECO'],
      layetqText: json['LAYETQ_TEXT'],
      gr7Status: json['gr7_status'],
      gr7DataHora: json['gr7_data_hora'],
    );
  }

  @override
  String toString() {
    return 'EtiquetaColetor(etqCodmat: $etqCodmat, etqDesc: $etqDesc, etqQtd: $etqQtd, layetqText: $layetqText)';
  }
}