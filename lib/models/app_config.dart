class AppConfig {
  final String endereco;
  final String porta;
  final String licenca;
  final bool isConfigured;

  AppConfig({
    required this.endereco,
    required this.porta,
    required this.licenca,
    this.isConfigured = false,
  });

  // Construtor para criar uma configuração vazia
  AppConfig.empty()
    : endereco = '',
      porta = '',
      licenca = '',
      isConfigured = false;

  // Método para criar uma cópia com modificações
  AppConfig copyWith({
    String? endereco,
    String? porta,
    String? licenca,
    bool? isConfigured,
  }) {
    return AppConfig(
      endereco: endereco ?? this.endereco,
      porta: porta ?? this.porta,
      licenca: licenca ?? this.licenca,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  // Conversão para Map (para armazenamento)
  Map<String, dynamic> toMap() {
    return {
      'endereco': endereco,
      'porta': porta,
      'licenca': licenca,
      'isConfigured': isConfigured,
    };
  }

  // Criação a partir de Map (para recuperação)
  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      endereco: map['endereco'] ?? '',
      porta: map['porta'] ?? '',
      licenca: map['licenca'] ?? '',
      isConfigured: map['isConfigured'] ?? false,
    );
  }

  @override
  String toString() {
    return 'AppConfig(endereco: $endereco, porta: $porta, licenca: $licenca, isConfigured: $isConfigured)';
  }
}
