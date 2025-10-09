import 'package:flutter_test/flutter_test.dart';
import 'package:nymbus_coletor/models/inventario_item.dart';

void main() {
  group('InventarioItem.validate', () {
    test('retorna erros quando campos obrigatórios inválidos', () {
      final item = InventarioItem(
        item: 0,
        codigo: -1,
        barras: '   \n \t ',
        produto: '   ',
        unidade: '',
        estoqueAtual: 5,
        novoEstoque: -2,
      );
      final errors = item.validate();
      expect(errors, contains('barras vazio ou inválido'));
      expect(errors, contains('item inválido'));
      expect(errors, contains('código inválido'));
      expect(errors, contains('produto vazio'));
      expect(errors, contains('unidade vazia'));
      expect(errors, contains('novoEstoque negativo'));
    });

    test('não retorna erros quando dados válidos', () {
      final item = InventarioItem(
        item: 1,
        codigo: 100,
        barras: '  123  ',
        produto: 'Teste',
        unidade: 'UN',
        estoqueAtual: 5,
        novoEstoque: 7,
      );
      final errors = item.validate();
      expect(errors, isEmpty);
      // getters auxiliares
      expect(item.dtCriacaoFormatada, isNotEmpty);
      expect(item.toString(), contains('InventarioItem'));
    });
  });
}
