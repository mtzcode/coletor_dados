import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class LoggerService {
  LoggerService._();

  static bool _debugEnabled = !kReleaseMode;

  /// Habilita ou desabilita logs de debug (útil para troubleshooting em release)
  static void enableDebug(bool enabled) {
    _debugEnabled = enabled;
  }

  static void d(String message) {
    if (_debugEnabled) _print('DEBUG', message);
  }

  static void i(String message) {
    _print('INFO', message);
  }

  static void w(String message) {
    _print('WARN', message);
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    _print('ERROR', buffer.toString());
  }

  static void _print(String level, String message) {
    final redacted = _redactMessage(message);
    debugPrint('[$level] $redacted');
  }

  // ===== Utilitários de mascaramento/redação de dados sensíveis =====
  static String maskLicense(String license) {
    final s = license.trim();
    if (s.isEmpty) return '';
    final visible = s.length >= 2 ? s.substring(s.length - 2) : s;
    final masked = '*' * (s.length - visible.length);
    return masked + visible;
  }

  static String maskBarcode(String barcode) {
    final s = barcode.trim();
    if (s.isEmpty) return '';
    final visible = s.length >= 4 ? s.substring(s.length - 4) : s;
    final masked = '*' * (s.length - visible.length);
    return masked + visible;
  }

  static String redactUrl(String url) {
    var s = url;
    // Mascara caminhos do tipo /licenca/<digits>
    s = s.replaceAllMapped(
      RegExp(r'(/licenca/)(\\d+)', caseSensitive: false),
      (m) {
        final digits = m.group(2)!;
        final masked = maskLicense(digits);
        return '${m.group(1)}$masked';
      },
    );
    // Mascara query params como ?license= ou ?licenca=
    s = s.replaceAllMapped(
      RegExp(r'([?&](?:license|licenca)=)([^&]+)', caseSensitive: false),
      (m) {
        final value = m.group(2)!;
        final masked = maskLicense(value);
        return '${m.group(1)}$masked';
      },
    );
    // Mascara tokens em query (?token=, ?access_token=, ?api_key=)
    s = s.replaceAllMapped(
      RegExp(r'([?&](?:token|access_token|api_key)=)([^&]+)', caseSensitive: false),
      (m) => '${m.group(1)}***',
    );
    return s;
  }

  static String _redactMessage(String message) {
    var s = message;
    // Redação de URLs
    s = s.replaceAllMapped(
      RegExp(r'(https?://[^\\s]+)', caseSensitive: false),
      (m) => redactUrl(m.group(0)!),
    );

    // Redação de cabeçalho Authorization: Bearer <token>
    s = s.replaceAllMapped(
      RegExp(r'(Authorization\\s*:\\s*Bearer\\s+)([A-Za-z0-9._-]+)', caseSensitive: false),
      (m) => '${m.group(1)}***',
    );

    // Se a mensagem sugere conteúdo de código de barras, mascarar sequências numéricas longas
    final mentionsBarcode = RegExp(r'(?i)(c[oó]digo(?:\\s*de\\s*barras)?|cod_barras|barcode|ean)').hasMatch(s);
    if (mentionsBarcode) {
      s = s.replaceAllMapped(RegExp(r'(\\d{8,})'), (m) => maskBarcode(m.group(1)!));
    }

    // Se a mensagem sugere licença, mascarar sequências curtas numéricas
    final mentionsLicense = RegExp(r'(?i)(licenca|license)').hasMatch(s);
    if (mentionsLicense) {
      s = s.replaceAllMapped(RegExp(r'(\\b\\d{3,}\\b)'), (m) => maskLicense(m.group(1)!));
    }

    return s;
  }
}
