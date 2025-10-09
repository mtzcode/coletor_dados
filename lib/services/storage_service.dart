import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nymbus_coletor/models/app_config.dart';
import 'package:nymbus_coletor/models/inventario_item.dart';
import 'package:nymbus_coletor/models/produto.dart';
import 'package:nymbus_coletor/services/license_service.dart';
import 'package:nymbus_coletor/services/logger_service.dart';
import 'package:nymbus_coletor/utils/barcode_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Adaptador para permitir mock do secure storage em testes
abstract class SecureStorageAdapter {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class DefaultSecureStorageAdapter implements SecureStorageAdapter {
  final FlutterSecureStorage _inner = const FlutterSecureStorage();
  @override
  Future<void> write({required String key, required String? value}) {
    return _inner.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _inner.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _inner.delete(key: key);
  }
}

class StorageService {
  static String _sanitizeBarcode(String input) {
    return BarcodeUtils.sanitize(input);
  }

  /// Util público para sanitização de códigos de barras (centralizado)
  static String sanitizeBarcode(String input) => _sanitizeBarcode(input);

  static const String _configKey = 'app_config';
  static const String _etiquetasKey = 'etiquetas_pendentes';
  static const String _inventarioKey = 'inventario_itens';
  static const String _entradaKey = 'entrada_itens';

  // Secure storage keys and adapter
  static const String _secureLicenseKey = 'secure_license';
  static const String _fallbackLicenseKey = 'license_fallback';
  static SecureStorageAdapter _secure = DefaultSecureStorageAdapter();

  // Permite injeção de mock em testes
  static void setSecureStorageAdapter(SecureStorageAdapter adapter) {
    _secure = adapter;
  }

  // Telemetria de falhas/sucessos do secure storage
  static int _secureWriteSuccesses = 0;
  static int _secureWriteFailures = 0;
  static int _secureReadSuccesses = 0;
  static int _secureReadFailures = 0;
  static int _secureDeleteSuccesses = 0;
  static int _secureDeleteFailures = 0;

  /// Snapshot da telemetria do secure storage
  static Map<String, int> getSecureTelemetry() => {
        'write_success': _secureWriteSuccesses,
        'write_failure': _secureWriteFailures,
        'read_success': _secureReadSuccesses,
        'read_failure': _secureReadFailures,
        'delete_success': _secureDeleteSuccesses,
        'delete_failure': _secureDeleteFailures,
      };

  /// Reseta contadores de telemetria (útil em testes)
  static void resetSecureTelemetry() {
    _secureWriteSuccesses = 0;
    _secureWriteFailures = 0;
    _secureReadSuccesses = 0;
    _secureReadFailures = 0;
    _secureDeleteSuccesses = 0;
    _secureDeleteFailures = 0;
  }

  /// Salva a configuração no armazenamento local
  static Future<bool> saveConfig(AppConfig config) async {
    try {
      // salva licença em secure storage (somente se formato válido)
      final lic = config.licenca.trim();
      if (LicenseService.isValidLicenseFormat(lic)) {
        try {
          await _secure.write(key: _secureLicenseKey, value: lic);
          _secureWriteSuccesses++;
          LoggerService.i('SecureStorage.write {"key":"$_secureLicenseKey","status":"success"}');
        } catch (e) {
          _secureWriteFailures++;
          LoggerService.w('SecureStorage.write {"key":"$_secureLicenseKey","status":"failure","error":"$e"}');
          if (!kReleaseMode) {
            final prefsFallback = await SharedPreferences.getInstance();
            await prefsFallback.setString(
              _fallbackLicenseKey,
              base64Encode(utf8.encode(lic)),
            );
            LoggerService.i('Fallback de licença aplicado (não-release).');
          } else {
            LoggerService.e('Fallback de licença desativado em release.');
          }
        }
      } else {
        LoggerService.w('Licença inválida, não será persistida no secure storage nem fallback.');
      }

      final prefs = await SharedPreferences.getInstance();
      // persiste sem a licença (dados não sensíveis)
      final configJson = jsonEncode({
        'endereco': config.endereco,
        'porta': config.porta,
        'isConfigured': config.isConfigured,
      });
      return await prefs.setString(_configKey, configJson);
    } catch (e) {
      LoggerService.e('Erro ao salvar configuração: $e');
      return false;
    }
  }

  /// Carrega a configuração do armazenamento local
  static Future<AppConfig?> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson == null) return null;

      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      var cfg = AppConfig.fromMap(configMap);
      try {
        final lic = await _secure.read(key: _secureLicenseKey);
        _secureReadSuccesses++;
        LoggerService.i('SecureStorage.read {"key":"$_secureLicenseKey","status":"success","hasValue":${lic != null}}');
        if (lic != null && lic.isNotEmpty && LicenseService.isValidLicenseFormat(lic.trim())) {
          cfg = cfg.copyWith(licenca: lic.trim());
        } else {
          if (!kReleaseMode) {
            final b64 = prefs.getString(_fallbackLicenseKey);
            if (b64 != null) {
              String decoded;
              try {
                decoded = utf8.decode(base64Decode(b64));
              } catch (_) {
                decoded = b64;
              }
              if (LicenseService.isValidLicenseFormat(decoded.trim())) {
                cfg = cfg.copyWith(licenca: decoded.trim());
                LoggerService.i('Licença carregada via fallback (não-release).');
              } else {
                LoggerService.w('Licença inválida encontrada no fallback, ignorada.');
              }
            }
          } else {
            LoggerService.w('Fallback de licença não disponível em release.');
          }
        }
      } catch (e) {
        _secureReadFailures++;
        LoggerService.w('SecureStorage.read {"key":"$_secureLicenseKey","status":"failure","error":"$e"}');
        if (!kReleaseMode) {
          final b64 = prefs.getString(_fallbackLicenseKey);
          if (b64 != null) {
            try {
              cfg = cfg.copyWith(licenca: utf8.decode(base64Decode(b64)));
            } catch (_) {
              cfg = cfg.copyWith(licenca: b64);
            }
            LoggerService.i('Licença carregada via fallback (não-release).');
          }
        } else {
          LoggerService.w('Fallback de licença não disponível em release.');
        }
      }
      return cfg;
    } catch (e) {
      LoggerService.e('Erro ao carregar configuração: $e');
      return null;
    }
  }

  /// Remove a configuração do armazenamento local
  static Future<bool> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await _secure.delete(key: _secureLicenseKey);
        _secureDeleteSuccesses++;
        LoggerService.i('SecureStorage.delete {"key":"$_secureLicenseKey","status":"success"}');
      } catch (e) {
        _secureDeleteFailures++;
        LoggerService.w('SecureStorage.delete {"key":"$_secureLicenseKey","status":"failure","error":"$e"}');
      }
      await prefs.remove(_fallbackLicenseKey);
      return await prefs.remove(_configKey);
    } catch (e) {
      LoggerService.e('Erro ao limpar configuração: $e');
      return false;
    }
  }

  /// Verifica se existe uma configuração salva
  static Future<bool> hasConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_configKey);
    } catch (e) {
      LoggerService.e('Erro ao verificar configuração: $e');
      return false;
    }
  }

  /// Salva a lista de etiquetas pendentes no armazenamento local
  static Future<bool> saveEtiquetas(List<Produto> etiquetas) async {
    try {
      // Apenas etiquetas com código de barras sanitizado e codProduto válido
      final validas = etiquetas.where((e) {
        final cb = sanitizeBarcode(e.codBarras);
        return cb.isNotEmpty && e.codProduto.trim().isNotEmpty;
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      final etiquetasJson = jsonEncode(
        validas.map((e) => e.toJson()).toList(),
      );
      return await prefs.setString(_etiquetasKey, etiquetasJson);
    } catch (e) {
      LoggerService.e('Erro ao salvar etiquetas: $e');
      return false;
    }
  }

  /// Carrega a lista de etiquetas pendentes do armazenamento local
  static Future<List<Produto>> loadEtiquetas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final etiquetasJson = prefs.getString(_etiquetasKey);

      if (etiquetasJson == null) return [];

      final etiquetasList = jsonDecode(etiquetasJson) as List<dynamic>;
      return etiquetasList
          .asMap()
          .entries
          .map((entry) {
            final data = entry.value as Map<String, dynamic>;
            final p = Produto.fromJson(
              data,
              (data['numero_item'] as int?) ?? entry.key + 1,
            );
            return p;
          })
          .where((p) => p.validate().isEmpty)
          .toList();
    } catch (e) {
      LoggerService.e('Erro ao carregar etiquetas: $e');
      return [];
    }
  }

  /// Remove todas as etiquetas pendentes do armazenamento local
  static Future<bool> clearEtiquetas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_etiquetasKey);
    } catch (e) {
      LoggerService.e('Erro ao limpar etiquetas: $e');
      return false;
    }
  }

  /// Verifica se existem etiquetas pendentes salvas
  static Future<bool> hasEtiquetas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_etiquetasKey);
    } catch (e) {
      LoggerService.e('Erro ao verificar etiquetas: $e');
      return false;
    }
  }

  /// Salva a lista de itens de inventário no armazenamento local
  static Future<bool> saveInventarioItens(List<InventarioItem> itens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final validos = itens.where((item) => item.validate().isEmpty).toList();
      final itensJson = jsonEncode(
        validos
            .map(
              (item) => {
                'item': item.item,
                'codigo': item.codigo,
                'barras': BarcodeUtils.sanitize(item.barras),
                'produto': item.produto,
                'unidade': item.unidade,
                'estoqueAtual': item.estoqueAtual,
                'novoEstoque': item.novoEstoque,
                'dtCriacao': item.dtCriacao.toIso8601String(),
              },
            )
            .toList(),
      );
      return await prefs.setString(_inventarioKey, itensJson);
    } catch (e) {
      LoggerService.e('Erro ao salvar itens de inventário: $e');
      return false;
    }
  }

  /// Carrega a lista de itens de inventário do armazenamento local
  static Future<List<InventarioItem>> loadInventarioItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itensJson = prefs.getString(_inventarioKey);

      if (itensJson == null) return [];

      final itensList = jsonDecode(itensJson) as List<dynamic>;
      return itensList.map((json) {
        final data = json as Map<String, dynamic>;
        return InventarioItem(
          item: data['item'] ?? 0,
          codigo: data['codigo'] ?? 0,
          barras: BarcodeUtils.sanitize(data['barras'] ?? ''),
          produto: data['produto'] ?? '',
          unidade: data['unidade'] ?? '',
          estoqueAtual: (data['estoqueAtual'] as num?)?.toDouble() ?? 0.0,
          novoEstoque: (data['novoEstoque'] as num?)?.toDouble() ?? 0.0,
          dtCriacao: DateTime.parse(
            data['dtCriacao'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      LoggerService.e('Erro ao carregar itens de inventário: $e');
      return [];
    }
  }

  /// Remove todos os itens de inventário do armazenamento local
  static Future<bool> clearInventarioItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_inventarioKey);
    } catch (e) {
      LoggerService.e('Erro ao limpar itens de inventário: $e');
      return false;
    }
  }

  /// Verifica se existem itens de inventário salvos
  static Future<bool> hasInventarioItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_inventarioKey);
    } catch (e) {
      LoggerService.e('Erro ao verificar itens de inventário: $e');
      return false;
    }
  }

  /// Salva a lista de itens de entrada no armazenamento local
  static Future<bool> saveEntradaItens(List<InventarioItem> itens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final validos = itens.where((item) => item.validate().isEmpty).toList();
      final itensJson = jsonEncode(
        validos
            .map(
              (item) => {
                'item': item.item,
                'codigo': item.codigo,
                'barras': BarcodeUtils.sanitize(item.barras),
                'produto': item.produto,
                'unidade': item.unidade,
                'estoqueAtual': item.estoqueAtual,
                'novoEstoque': item.novoEstoque,
                'dtCriacao': item.dtCriacao.toIso8601String(),
              },
            )
            .toList(),
      );
      return await prefs.setString(_entradaKey, itensJson);
    } catch (e) {
      LoggerService.e('Erro ao salvar itens de entrada: $e');
      return false;
    }
  }

  /// Carrega a lista de itens de entrada do armazenamento local
  static Future<List<InventarioItem>> loadEntradaItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itensJson = prefs.getString(_entradaKey);

      if (itensJson == null) return [];

      final itensList = jsonDecode(itensJson) as List<dynamic>;
      return itensList.map((json) {
        final data = json as Map<String, dynamic>;
        return InventarioItem(
          item: data['item'] ?? 0,
          codigo: data['codigo'] ?? 0,
          barras: BarcodeUtils.sanitize(data['barras'] ?? ''),
          produto: data['produto'] ?? '',
          unidade: data['unidade'] ?? '',
          estoqueAtual: (data['estoqueAtual'] as num?)?.toDouble() ?? 0.0,
          novoEstoque: (data['novoEstoque'] as num?)?.toDouble() ?? 0.0,
          dtCriacao: DateTime.parse(
            data['dtCriacao'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      LoggerService.e('Erro ao carregar itens de entrada: $e');
      return [];
    }
  }

  /// Remove todos os itens de entrada do armazenamento local
  static Future<bool> clearEntradaItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_entradaKey);
    } catch (e) {
      LoggerService.e('Erro ao limpar itens de entrada: $e');
      return false;
    }
  }

  /// Verifica se existem itens de entrada salvos
  static Future<bool> hasEntradaItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_entradaKey);
    } catch (e) {
      LoggerService.e('Erro ao verificar itens de entrada: $e');
      return false;
    }
  }

  /// Carrega a licença persistente do secure storage; se não existir, cria uma nova e persiste.
  static Future<String> loadOrCreateLicense() async {
    String? lic;
    // Tenta ler do secure storage
    try {
      lic = await _secure.read(key: _secureLicenseKey);
      _secureReadSuccesses++;
      LoggerService.i('SecureStorage.read {"key":"$_secureLicenseKey","status":"success","hasValue":${lic != null}}');
      if (lic != null && lic.isNotEmpty && LicenseService.isValidLicenseFormat(lic.trim())) {
        return lic.trim();
      }
    } catch (e) {
      _secureReadFailures++;
      LoggerService.w('SecureStorage.read {"key":"$_secureLicenseKey","status":"failure","error":"$e"}');
    }

    // Fallback em não-release
    if (!kReleaseMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final b64 = prefs.getString(_fallbackLicenseKey);
        if (b64 != null) {
          String decoded;
          try {
            decoded = utf8.decode(base64Decode(b64));
          } catch (_) {
            decoded = b64;
          }
          if (LicenseService.isValidLicenseFormat(decoded.trim())) {
            return decoded.trim();
          }
        }
      } catch (e) {
        LoggerService.w('Falha ao ler fallback de licença: $e');
      }
    }

    // Não há licença válida: gera nova e persiste
    final newLic = LicenseService.generateLicense();
    try {
      await _secure.write(key: _secureLicenseKey, value: newLic);
      _secureWriteSuccesses++;
      LoggerService.i('SecureStorage.write {"key":"$_secureLicenseKey","status":"success"}');
    } catch (e) {
      _secureWriteFailures++;
      LoggerService.w('SecureStorage.write {"key":"$_secureLicenseKey","status":"failure","error":"$e"}');
      if (!kReleaseMode) {
        try {
          final prefsFallback = await SharedPreferences.getInstance();
          await prefsFallback.setString(
            _fallbackLicenseKey,
            base64Encode(utf8.encode(newLic)),
          );
          LoggerService.i('Fallback de licença aplicado (não-release).');
        } catch (err) {
          LoggerService.w('Falha ao persistir fallback de licença: $err');
        }
      } else {
        LoggerService.e('Fallback de licença desativado em release.');
      }
    }
    return newLic;
  }
}
