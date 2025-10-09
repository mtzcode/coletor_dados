import 'package:flutter_test/flutter_test.dart';
import 'package:nymbus_coletor/models/produto.dart';

void main() {
  group('Produto.validate', () {
    test('retorna erros quando campos obrigatórios inválidos', () {
      final p = Produto(
        codBarras: '   \n \t ',
        codProduto: '',
        produto: '   ',
        unidade: '',
        valorVenda: -1,
        dataHoraRequisicao: DateTime.now(),
        numeroItem: 1,
      );
      final errors = p.validate();
      expect(errors, contains('codBarras vazio ou inválido'));
      expect(errors, contains('codProduto vazio'));
      expect(errors, contains('produto vazio'));
      expect(errors, contains('unidade vazia'));
      expect(errors, contains('valorVenda negativo'));
    });

    test('não retorna erros quando dados válidos', () {
      final p = Produto(
        codBarras: '  789  ',
        codProduto: 'P1',
        produto: 'Nome',
        unidade: 'UN',
        valorVenda: 10.0,
        dataHoraRequisicao: DateTime.now(),
        numeroItem: 1,
      );
      final errors = p.validate();
      expect(errors, isEmpty);
      // também verifica formatações auxiliares não lançam
      expect(p.precoFormatado, isNotEmpty);
      expect(p.numeroItemFormatado, isNotEmpty);
      expect(p.dataHoraFormatada, isNotEmpty);
    });
  });
}
