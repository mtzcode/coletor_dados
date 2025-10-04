import 'dart:math';

class LicenseService {
  /// Gera uma licença de 4 dígitos
  static String generateLicense() {
    final random = Random();
    return (1000 + random.nextInt(9000))
        .toString(); // Gera número de 4 dígitos (1000-9999)
  }

  /// Valida se o formato da licença está correto (4 dígitos)
  static bool isValidLicenseFormat(String license) {
    if (license.length != 4) return false;
    return int.tryParse(license) != null;
  }

  /// Gera uma nova licença garantindo que seja diferente da atual
  static String generateNewLicense(String? currentLicense) {
    String newLicense;
    do {
      newLicense = generateLicense();
    } while (newLicense == currentLicense);
    return newLicense;
  }
}
