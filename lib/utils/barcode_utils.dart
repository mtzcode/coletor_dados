class BarcodeUtils {
  // Centralizador de sanitizaÃ§Ã£o de cÃ³digos de barras
  static String sanitize(String input) {
    var s = input.trim();
    s = s.replaceAll(RegExp(r'[\s\r\n\t]+'), '');
    s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
    return s;
  }
}
