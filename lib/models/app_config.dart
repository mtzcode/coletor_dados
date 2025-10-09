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

  // Construtor para criar uma configuraÃ§Ã£o vazia
  AppConfig.empty()
    : endereco = '',
      porta = '',
      licenca = '',
      isConfigured = false;

  // MÃ©todo para criar uma cÃ³pia com modificaÃ§Ãµes
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

  // ConversÃ£o para Map (para armazenamento)
  Map<String, dynamic> toMap() {
    return {
      'endereco': endereco,
      'porta': porta,
      'licenca': licenca,
      'isConfigured': isConfigured,
    };
  }

  // CriaÃ§Ã£o a partir de Map (para recuperaÃ§Ã£o)
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
