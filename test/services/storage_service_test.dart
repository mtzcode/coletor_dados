import 'package:flutter_test/flutter_test.dart';
import 'package:nymbus_coletor/models/app_config.dart';
import 'package:nymbus_coletor/models/inventario_item.dart';
import 'package:nymbus_coletor/models/produto.dart';
import 'package:nymbus_coletor/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Adapters de teste para controlar o comportamento do secure storage
class FailingSecureStorageAdapter implements SecureStorageAdapter {
  @override
  Future<void> write({required String key, required String? value}) async {
    throw Exception('write failed');
  }

  @override
  Future<String?> read({required String key}) async {
    throw Exception('read failed');
  }

  @override
  Future<void> delete({required String key}) async {
    throw Exception('delete failed');
  }
}

class MemorySecureStorageAdapter implements SecureStorageAdapter {
  final Map<String, String?> _mem = {};

  @override
  Future<void> write({required String key, required String? value}) async {
    _mem[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _mem[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _mem.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService unit tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Resetar telemetria antes de cada teste
      StorageService.resetSecureTelemetry();
      // Garantir adapter padrÃ£o
      StorageService.setSecureStorageAdapter(DefaultSecureStorageAdapter());
    });

    test('save/load/clear Config com secure storage/fallback e telemetria', () async {
      final cfg = AppConfig(
        endereco: 'localhost',
        porta: '8080',
        // Usar licenÃ§a vÃ¡lida (4 dÃ­gitos) para acionar tentativa de gravaÃ§Ã£o no secure storage
        licenca: '1234',
        isConfigured: true,
      );
      final saved = await StorageService.saveConfig(cfg);
      expect(saved, isTrue);

      // ApÃ³s tentativa de gravaÃ§Ã£o no secure storage, deve existir exatamente 1 operaÃ§Ã£o de write (sucesso ou falha)
      final telAfterWrite = StorageService.getSecureTelemetry();
      expect((telAfterWrite['write_success'] ?? 0) + (telAfterWrite['write_failure'] ?? 0), 1);

      final loaded = await StorageService.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.endereco, 'localhost');
      expect(loaded.porta, '8080');
      // LicenÃ§a deve ser carregada (via secure storage OU fallback)
      expect(loaded.licenca, '1234');

      // ApÃ³s tentativa de leitura no secure storage, deve existir exatamente 1 operaÃ§Ã£o de read (sucesso ou falha)
      final telAfterRead = StorageService.getSecureTelemetry();
      expect((telAfterRead['read_success'] ?? 0) + (telAfterRead['read_failure'] ?? 0), 1);

      final cleared = await StorageService.clearConfig();
      expect(cleared, isTrue);

      // ApÃ³s tentativa de delete no secure storage, deve existir exatamente 1 operaÃ§Ã£o de delete (sucesso ou falha)
      final telAfterDelete = StorageService.getSecureTelemetry();
      expect((telAfterDelete['delete_success'] ?? 0) + (telAfterDelete['delete_failure'] ?? 0), 1);

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

    test('Inventario: save/load/clear e sanitizaÃ§Ã£o de barras', () async {
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

    test('Entrada: save/load/clear e sanitizaÃ§Ã£o de barras', () async {
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

  group('StorageService secure storage com adapter mock', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetSecureTelemetry();
    });

    tearDown(() async {
      // Restaurar adapter padrÃ£o ao final
      StorageService.setSecureStorageAdapter(DefaultSecureStorageAdapter());
    });

    test('GravaÃ§Ã£o falha no secure storage: usa fallback e telemetria registra falhas', () async {
      StorageService.setSecureStorageAdapter(FailingSecureStorageAdapter());

      final cfg = AppConfig(
        endereco: 'localhost',
        porta: '8080',
        licenca: '9999',
        isConfigured: true,
      );

      final saved = await StorageService.saveConfig(cfg);
      expect(saved, isTrue);

      final telWrite = StorageService.getSecureTelemetry();
      expect(telWrite['write_failure'], 1);
      expect(telWrite['write_success'], 0);

      final loaded = await StorageService.loadConfig();
      expect(loaded, isNotNull);
      // Como o read falha e estamos em modo nÃ£o-release, deve carregar via fallback
      expect(loaded!.licenca, '9999');

      final telRead = StorageService.getSecureTelemetry();
      expect(telRead['read_failure'], 1);
      expect(telRead['read_success'], 0);

      final cleared = await StorageService.clearConfig();
      expect(cleared, isTrue);

      final telDelete = StorageService.getSecureTelemetry();
      expect(telDelete['delete_failure'], 1);
      expect(telDelete['delete_success'], 0);

      final has = await StorageService.hasConfig();
      expect(has, isFalse);
    });

    test('Sucesso completo com MemorySecureStorageAdapter (write/read/delete)', () async {
      StorageService.setSecureStorageAdapter(MemorySecureStorageAdapter());

      final cfg = AppConfig(
        endereco: 'srv',
        porta: '9090',
        licenca: '4321',
        isConfigured: true,
      );

      final saved = await StorageService.saveConfig(cfg);
      expect(saved, isTrue);
      var tel = StorageService.getSecureTelemetry();
      expect(tel['write_success'], 1);
      expect(tel['write_failure'], 0);

      final loaded = await StorageService.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.licenca, '4321');
      tel = StorageService.getSecureTelemetry();
      expect(tel['read_success'], 1);
      expect(tel['read_failure'], 0);

      final cleared = await StorageService.clearConfig();
      expect(cleared, isTrue);
      tel = StorageService.getSecureTelemetry();
      expect(tel['delete_success'], 1);
      expect(tel['delete_failure'], 0);

      final has = await StorageService.hasConfig();
      expect(has, isFalse);
    });
  });
}
