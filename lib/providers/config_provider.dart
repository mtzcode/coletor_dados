import 'package:flutter/foundation.dart';
import 'package:nymbus_coletor/models/app_config.dart';
import 'package:nymbus_coletor/services/api_service.dart';

import 'package:nymbus_coletor/services/storage_service.dart';

class ConfigProvider extends ChangeNotifier {
  AppConfig _config = AppConfig.empty();
  bool _isLoading = false;
  String? _errorMessage;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _config.isConfigured;

  /// Inicializa o provider carregando a configuração salva
  Future<void> init() async {
    _setLoading(true);
    try {
      final savedConfig = await StorageService.loadConfig();
      // Usa configuração salva ou começa vazia
      _config = savedConfig ?? AppConfig.empty();

      // Licença persistente: carrega do secure storage ou cria e persiste se não existir
      final persistentLicense = await StorageService.loadOrCreateLicense();
      _config = _config.copyWith(licenca: persistentLicense);

      // Configura a API se os dados estão disponíveis
      if (_config.endereco.isNotEmpty && _config.porta.isNotEmpty) {
        final baseUrl = 'http://${_config.endereco}:${_config.porta}/api';
        ApiService.instance.configure(baseUrl);
      }
      _clearError();
    } catch (e) {
      _setError('Erro ao carregar configuração: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Salva a configuração
  Future<bool> saveConfig({
    required String endereco,
    required String porta,
    String? licenca,
  }) async {
    _setLoading(true);
    try {
      final newConfig = AppConfig(
        endereco: endereco,
        porta: porta,
        licenca: licenca ?? _config.licenca,
        isConfigured: true,
      );

      final success = await StorageService.saveConfig(newConfig);
      if (success) {
        _config = newConfig;
        // Configura a API
        final baseUrl = 'http://$endereco:$porta/api';
        ApiService.instance.configure(baseUrl);
        _clearError();
        notifyListeners();
        return true;
      } else {
        _setError('Erro ao salvar configuração');
        return false;
      }
    } catch (e) {
      _setError('Erro ao salvar configuração: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Testa a conectividade com o servidor
  Future<bool> testarConectividade() async {
    _setLoading(true);
    try {
      // Passa a licença real para o teste de conectividade
      final isConnected = await ApiService.instance.testarConectividade(
        _config.licenca,
      );
      if (!isConnected) {
        _setError(
          'Não foi possível conectar com o servidor. Verifique o endereço e porta.',
        );
      } else {
        _clearError();
      }
      return isConnected;
    } catch (e) {
      _setError('Erro ao testar conectividade: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Valida a licenÃ§a com o servidor
  Future<bool> validarLicenca() async {
    if (_config.licenca.isEmpty) {
      _setError('Licença não definida');
      return false;
    }

    _setLoading(true);
    try {
      final isValid = await ApiService.instance.validarLicencaSimples(
        _config.licenca,
      );
      if (!isValid) {
        _setError('Licença inválida');
      } else {
        _clearError();
      }
      return isValid;
    } catch (e) {
      _setError('Erro ao validar licença: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sincroniza configuraÃ§Ã£o (testa conectividade e valida licenÃ§a)
  Future<bool> sincronizar() async {
    _setLoading(true);
    try {
      // Primeiro testa conectividade com a licença real
      final isConnected = await ApiService.instance.testarConectividade(
        _config.licenca,
      );
      if (!isConnected) {
        _setError(
          'Não foi possível conectar com o servidor. Verifique o endereço e porta.',
        );
        return false;
      }

      // Valida a licença (API retorna apenas OK se válida)
      final isValid = await ApiService.instance.validarLicencaSimples(
        _config.licenca,
      );
      if (!isValid) {
        _setError('Licença inválida');
        return false;
      }

      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Erro na sincronização: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Limpa a configuraÃ§Ã£o
  Future<void> clearConfig() async {
    await StorageService.clearConfig();
    _config = AppConfig.empty();
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
