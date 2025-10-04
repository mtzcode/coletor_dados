import 'package:coletor_dados/models/app_config.dart';
import 'package:coletor_dados/models/inventario_item.dart';
import 'package:coletor_dados/models/produto.dart';
import 'package:coletor_dados/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService unit tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('save/load/clear Config com fallback de licença', () async {
      final cfg = AppConfig(
        endereco: 'localhost',
        porta: '8080',
        licenca: 'LIC123',
        isConfigured: true,
      );
      final saved = await StorageService.saveConfig(cfg);
      expect(saved, isTrue);

      final loaded = await StorageService.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.endereco, 'localhost');
      expect(loaded.porta, '8080');
      // Licença pode ser carregada do secure storage; em testes, usamos fallback
      expect(loaded.licenca.isNotEmpty, isTrue);

      final cleared = await StorageService.clearConfig();
      expect(cleared, isTrue);
      final has = await StorageService.hasConfig();
      expect(has, isFalse);
    });

    test('save/load/clear Etiquetas com Produto.toJson', () async {
      final produtos = [
        Produto(
          codBarras: '  789  \n ',
          codProduto: 'P1',
          produto: 'Nome',
          unidade: 'UN',
          valorVenda: 10.5,
          dataHoraRequisicao: DateTime.now(),
          numeroItem: 1,
        )..tipoEtiqueta = 'GONDOLA',
      ];

      final okSave = await StorageService.saveEtiquetas(produtos);
      expect(okSave, isTrue);

      final loaded = await StorageService.loadEtiquetas();
      expect(loaded.length, 1);
      expect(loaded.first.codBarras, '789'); // sanitizado ao salvar/ler
      expect(loaded.first.tipoEtiqueta, 'GONDOLA');

      final okClear = await StorageService.clearEtiquetas();
      expect(okClear, isTrue);
      final has = await StorageService.hasEtiquetas();
      expect(has, isFalse);
    });

    test('Inventario: save/load/clear e sanitização de barras', () async {
      final itens = [
        InventarioItem(
          item: 1,
          codigo: 100,
          barras: '  123  \n ',
          produto: 'Teste',
          unidade: 'UN',
          estoqueAtual: 5,
          novoEstoque: 7,
        ),
      ];

      final okSave = await StorageService.saveInventarioItens(itens);
      expect(okSave, isTrue);

      final loaded = await StorageService.loadInventarioItens();
      expect(loaded.length, 1);
      expect(loaded.first.barras, '123');

      final okClear = await StorageService.clearInventarioItens();
      expect(okClear, isTrue);
      final has = await StorageService.hasInventarioItens();
      expect(has, isFalse);
    });

    test('Entrada: save/load/clear e sanitização de barras', () async {
      final itens = [
        InventarioItem(
          item: 2,
          codigo: 200,
          barras: '  321  \t ',
          produto: 'Entrada',
          unidade: 'UN',
          estoqueAtual: 10,
          novoEstoque: 11,
        ),
      ];

      final okSave = await StorageService.saveEntradaItens(itens);
      expect(okSave, isTrue);

      final loaded = await StorageService.loadEntradaItens();
      expect(loaded.length, 1);
      expect(loaded.first.barras, '321');

      final okClear = await StorageService.clearEntradaItens();
      expect(okClear, isTrue);
      final has = await StorageService.hasEntradaItens();
      expect(has, isFalse);
    });
  });
}
