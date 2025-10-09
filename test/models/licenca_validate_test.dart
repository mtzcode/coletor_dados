import 'package:flutter_test/flutter_test.dart';
import 'package:nymbus_coletor/models/licenca.dart';

void main() {
  group('Licenca.validate', () {
    test('retorna erros para código vazio e usuário vazio', () {
      final l = Licenca(codigo: '', usuarioAparelho: '', valida: false);
      final errors = l.validate();
      expect(errors, contains('codigo vazio'));
      expect(errors, contains('usuarioAparelho vazio'));
    });

    test('retorna erro para formato inválido (não 4 dígitos)', () {
      final l = Licenca(codigo: '12a4', usuarioAparelho: 'user', valida: true);
      final errors = l.validate();
      expect(errors, contains('código de licença inválido'));
    });

    test('não retorna erros para código válido de 4 dígitos e usuário presente', () {
      final l = Licenca(codigo: '1234', usuarioAparelho: 'user', valida: true);
      final errors = l.validate();
      expect(errors, isEmpty);
    });
  });
}
