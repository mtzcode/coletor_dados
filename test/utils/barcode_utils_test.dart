import 'package:flutter_test/flutter_test.dart';
import 'package:nymbus_coletor/utils/barcode_utils.dart';

void main() {
  group('BarcodeUtils.sanitize', () {
    test('remove espaÃ§os em volta e no meio', () {
      expect(BarcodeUtils.sanitize('  123  '), '123');
      expect(BarcodeUtils.sanitize('  A B C 1 2 3  '), 'ABC123');
    });

    test('remove tabs e quebras de linha', () {
      expect(BarcodeUtils.sanitize('12\t3\n4'), '1234');
      expect(BarcodeUtils.sanitize('\n\t  7 8 9 \r'), '789');
    });

    test('remove caracteres de controle ASCII (0-31 e 127)', () {
      const input = '12\x003\x7F4\x1F';
      expect(BarcodeUtils.sanitize(input), '1234');
    });

    test('mantÃ©m alfanumÃ©ricos comuns', () {
      expect(BarcodeUtils.sanitize('ABC123'), 'ABC123');
      expect(BarcodeUtils.sanitize('xyz987'), 'xyz987');
    });
  });
}
