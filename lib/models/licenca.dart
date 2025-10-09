import 'package:nymbus_coletor/services/license_service.dart';

class Licenca {
  final String codigo;
  final String usuarioAparelho;
  final bool valida;

  Licenca({
    required this.codigo,
    required this.usuarioAparelho,
    required this.valida,
  });

  // Conversão para Map (para armazenamento)
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'usuarioAparelho': usuarioAparelho,
      'valida': valida,
    };
  }

  // Criação a partir de Map (para recuperação)
  factory Licenca.fromMap(Map<String, dynamic> map) {
    return Licenca(
      codigo: map['codigo'] ?? '',
      usuarioAparelho: map['usuarioAparelho'] ?? '',
      valida: map['valida'] ?? false,
    );
  }

  // Criação a partir de JSON da API
  factory Licenca.fromJson(Map<String, dynamic> json) {
    return Licenca(
      codigo: json['codigo'] ?? '',
      usuarioAparelho: json['usuario_aparelho'] ?? '',
      valida: json['valida'] ?? false,
    );
  }

  // Validação sistemática da licença
  List<String> validate() {
    final errors = <String>[];
    final cod = codigo.trim();
    if (cod.isEmpty) {
      errors.add('codigo vazio');
    } else if (!LicenseService.isValidLicenseFormat(cod)) {
      errors.add('código de licença inválido');
    }
    if (usuarioAparelho.trim().isEmpty) {
      errors.add('usuarioAparelho vazio');
    }
    return errors;
  }

  @override
  String toString() {
    return 'Licenca(codigo: $codigo, usuarioAparelho: $usuarioAparelho, valida: $valida)';
  }
}
