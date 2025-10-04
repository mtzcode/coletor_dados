import 'dart:async';
import 'dart:convert';

import 'package:coletor_dados/models/etiqueta_coletor.dart';
import 'package:coletor_dados/models/inventario_item.dart';
import 'package:coletor_dados/services/logger_service.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static ApiService get instance => _instance;

  String? _baseUrl;
  bool get isConfigured => _baseUrl != null;

  // Cliente HTTP injetável para facilitar testes
  http.Client _client = http.Client();
  void setClient(http.Client client) {
    _client = client;
  }

  // Timeouts centralizados
  static const Duration _timeoutShort = Duration(seconds: 8);
  static const Duration _timeoutMedium = Duration(seconds: 15);
  static const Duration _timeoutLong = Duration(seconds: 30);

  // Retry/backoff
  static const int _maxRetries = 3;
  static const Duration _baseBackoff = Duration(milliseconds: 600);

  // Handler global para não autorizado (401/403)
  void Function()? _onUnauthorized;
  void setUnauthorizedHandler(void Function() handler) {
    _onUnauthorized = handler;
  }

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  void _handleUnauthorized() {
    LoggerService.w(
      'Resposta 401/403 recebida. Disparando redirecionamento para Login.',
    );
    try {
      _onUnauthorized?.call();
    } catch (e, st) {
      LoggerService.e('Erro ao executar handler de não autorizado', e, st);
    }
  }

  bool _shouldRetryError(Object e) {
    final s = e.toString();
    return e is TimeoutException ||
        e is http.ClientException ||
        s.contains('Failed host lookup') ||
        s.contains('Network') ||
        s.contains('SocketException') ||
        s.contains('Failed to fetch');
  }

  Duration _backoffDelay(int attempt) {
    final ms = _baseBackoff.inMilliseconds * (1 << (attempt - 1));
    return Duration(milliseconds: ms);
  }

  Future<http.Response> _get(
    Uri url, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await _client
            .get(url, headers: headers)
            .timeout(timeout ?? _timeoutMedium);
        if (response.statusCode == 401 || response.statusCode == 403) {
          _handleUnauthorized();
        }
        return response;
      } catch (e) {
        attempt++;
        if (attempt > _maxRetries || !_shouldRetryError(e)) {
          rethrow;
        }
        final delay = _backoffDelay(attempt);
        LoggerService.w(
          'Falha na requisição GET (tentativa $attempt). Retentando em ${delay.inMilliseconds}ms...',
        );
        await Future.delayed(delay);
      }
    }
  }

  Future<http.Response> _post(
    Uri url, {
    Duration? timeout,
    Map<String, String>? headers,
    Object? body,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await _client
            .post(url, headers: headers, body: body)
            .timeout(timeout ?? _timeoutMedium);
        if (response.statusCode == 401 || response.statusCode == 403) {
          _handleUnauthorized();
        }
        return response;
      } catch (e) {
        attempt++;
        if (attempt > _maxRetries || !_shouldRetryError(e)) {
          rethrow;
        }
        final delay = _backoffDelay(attempt);
        LoggerService.w(
          'Falha na requisição POST (tentativa $attempt). Retentando em ${delay.inMilliseconds}ms...',
        );
        await Future.delayed(delay);
      }
    }
  }

  /// Configura a URL base da API
  void configure(String baseUrl) {
    _baseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  /// Testa a conectividade com a API
  Future<bool> testarConectividade([String? licenca]) async {
    if (!isConfigured) return false;
    try {
      final licencaTeste = licenca ?? '0000';
      final url = Uri.parse('$_baseUrl/licenca/$licencaTeste');
      LoggerService.d('Testando conectividade com: $url');
      final response = await _get(url, timeout: _timeoutShort);
      LoggerService.d(
        'Resposta recebida - Status: ${response.statusCode}, Body length: ${response.body.length}',
      );
      return response.statusCode < 500;
    } catch (e) {
      LoggerService.e('Erro de conectividade detalhado: $e');
      LoggerService.d('Tipo do erro: ${e.runtimeType}');
      if (e.toString().contains('Failed to fetch')) {
        LoggerService.w(
          'POSSÍVEL ERRO DE CORS: O navegador está bloqueando a requisição',
        );
        LoggerService.w(
          'Verifique se o servidor da API tem CORS configurado para: ${Uri.base.origin}',
        );
      }
      return false;
    }
  }

  /// Valida uma licença através da API
  Future<bool> validarLicenca(String licenca) async {
    if (!isConfigured) {
      throw Exception('API não configurada');
    }
    try {
      final url = Uri.parse('$_baseUrl/licenca/$licenca');
      LoggerService.d('Validando licença com: $url');
      final response = await _get(url, timeout: _timeoutMedium);
      LoggerService.d('Validação - Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final responseBody = response.body.toLowerCase().trim();
        final isValid = responseBody == 'ok';
        LoggerService.i('Licença ${isValid ? 'VÁLIDA' : 'INVÁLIDA'}');
        return isValid;
      } else if (response.statusCode == 404) {
        LoggerService.i('Licença não encontrada (404)');
        return false;
      } else {
        LoggerService.e('Erro do servidor: ${response.statusCode}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro detalhado na validação: $e');
      LoggerService.d('Tipo do erro: ${e.runtimeType}');
      if (e.toString().contains('Failed to fetch')) {
        LoggerService.w(
          'ERRO DE CORS: Configure o servidor para aceitar requisições de: ${Uri.base.origin}',
        );
      }
      throw Exception('Erro ao validar licença: $e');
    }
  }

  /// Método simplificado para validação de licença
  Future<bool> validarLicencaSimples(String licenca) async {
    try {
      return await validarLicenca(licenca);
    } catch (e) {
      LoggerService.e('Erro na validação: $e');
      return false;
    }
  }

  /// Busca dados do produto por código de barras
  Future<Map<String, dynamic>?> buscarProduto(String codigoBarras) async {
    if (!isConfigured) {
      throw Exception('API não configurada');
    }
    try {
      final codigoSan = (codigoBarras)
          .replaceAll(RegExp(r'[\s\r\n\t]'), '')
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
      final urlDireta = Uri.parse('$_baseUrl/produtos/$codigoSan');
      LoggerService.d('Tentando busca direta com: $urlDireta');
      LoggerService.d('Código de barras procurado: "$codigoSan"');
      final responseDireta = await _get(urlDireta, timeout: _timeoutShort);
      LoggerService.d('Busca direta - Status: ${responseDireta.statusCode}');
      if (responseDireta.statusCode == 200) {
        final data = jsonDecode(responseDireta.body);
        if (data is Map<String, dynamic>) {
          LoggerService.d('Produto encontrado via busca direta');
          return data;
        } else if (data is List && data.isNotEmpty) {
          LoggerService.d('Lista retornada, pegando primeiro item');
          return data[0] as Map<String, dynamic>;
        }
      } else if (responseDireta.statusCode == 404) {
        LoggerService.d(
          'Produto não encontrado via busca direta, tentando busca geral...',
        );
      } else {
        LoggerService.e(
          'Erro na busca direta: ${responseDireta.statusCode}, tentando busca geral...',
        );
      }
      LoggerService.d('Iniciando busca geral como fallback...');
      final url = Uri.parse('$_baseUrl/produtos');
      LoggerService.d('Buscando todos os produtos com: $url');
      final response = await _get(url, timeout: _timeoutLong);
      LoggerService.d('Busca geral - Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        LoggerService.d(
          'Tamanho da resposta: ${response.body.length} caracteres',
        );
        try {
          LoggerService.d('Iniciando decodificação JSON...');
          final data = jsonDecode(response.body);
          LoggerService.d(
            'JSON decodificado com sucesso. Tipo: ${data.runtimeType}',
          );
          if (data is List) {
            LoggerService.d('Total de produtos recebidos: ${data.length}');
            Map<String, dynamic>? produto;
            int itemsProcessados = 0;
            LoggerService.d('Iniciando busca otimizada...');
            for (var item in data) {
              itemsProcessados++;
              if (item == null || item is! Map<String, dynamic>) {
                continue;
              }
              try {
                final codBarras = item['cod_barras'];
                if (codBarras == null) continue;
                final codBarrasStr = (codBarras.toString())
                    .replaceAll(RegExp(r'[\s\r\n\t]'), '')
                    .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
                final codigoBarrasStr = (codigoBarras)
                    .replaceAll(RegExp(r'[\s\r\n\t]'), '')
                    .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
                if (codBarrasStr == codigoBarrasStr) {
                  produto = item;
                  LoggerService.d(
                    'PRODUTO ENCONTRADO no item $itemsProcessados!',
                  );
                  break;
                }
              } catch (_) {
                continue;
              }
              if (itemsProcessados % 1000 == 0) {
                LoggerService.d('Processados $itemsProcessados itens...');
              }
            }
            LoggerService.d(
              'Busca concluída. Items processados: $itemsProcessados',
            );
            if (produto != null) {
              return produto;
            } else {
              LoggerService.i(
                'Produto com código "$codigoBarras" não encontrado',
              );
              return null;
            }
          } else if (data is Map<String, dynamic>) {
            LoggerService.d('Resposta é um Map, retornando diretamente');
            return data;
          } else {
            LoggerService.w(
              'Resposta da API não é um Map nem List: ${data.runtimeType}',
            );
            throw Exception('Formato de resposta inválido');
          }
        } catch (e) {
          LoggerService.e('Erro na decodificação JSON: $e');
          if (e is FormatException) {
            throw Exception('Erro de formato na resposta da API');
          } else {
            rethrow;
          }
        }
      } else if (response.statusCode == 404) {
        LoggerService.i('Produto não encontrado (404)');
        return null;
      } else {
        LoggerService.e('Erro do servidor: ${response.statusCode}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro detalhado na busca do produto: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Timeout na busca do produto. Tente novamente.');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Erro no formato dos dados da API.');
      } else {
        throw Exception('Erro ao buscar produto: $e');
      }
    }
  }

  /// Busca tipos de etiquetas disponíveis
  Future<List<Map<String, dynamic>>> buscarTiposEtiquetas() async {
    if (!isConfigured) {
      throw Exception('API não configurada');
    }
    try {
      final url = Uri.parse('$_baseUrl/etiquetas');
      LoggerService.d('Buscando tipos de etiquetas com: $url');
      final response = await _get(url, timeout: _timeoutMedium);
      LoggerService.d('Busca etiquetas - Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [data as Map<String, dynamic>];
        }
      } else {
        LoggerService.e('Erro do servidor: ${response.statusCode}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro detalhado na busca de etiquetas: $e');
      throw Exception('Erro ao buscar tipos de etiquetas: $e');
    }
  }

  /// Envia dados coletados para a API
  Future<bool> enviarDados(Map<String, dynamic> dados) async {
    if (!isConfigured) {
      throw Exception('API não configurada');
    }
    try {
      final url = Uri.parse('$_baseUrl/dados');
      final response = await _post(
        url,
        headers: _jsonHeaders,
        body: jsonEncode(dados),
        timeout: _timeoutLong,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      throw Exception('Erro ao enviar dados: $e');
    }
  }

  /// Envia etiquetas para o coletor (tabela ts_arq_etq)
  Future<bool> enviarEtiquetasColetor(List<EtiquetaColetor> etiquetas) async {
    if (!isConfigured) {
      throw Exception('API não configurada');
    }
    try {
      final itens = etiquetas
          .map(
            (etiqueta) => {
              'codigo': int.tryParse(etiqueta.etqCodmat ?? '0') ?? 0,
              'barras': (etiqueta.etqEan13 ?? '')
                  .replaceAll(RegExp(r'[\s\r\n\t]'), '')
                  .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ''),
              'produto': etiqueta.etqDesc ?? '',
              'un': etiqueta.etqUn ?? '',
              'qtd': etiqueta.etqQtd ?? 1,
              'dt_criacao': etiqueta.etqDthora ?? DateTime.now().toString(),
              'danfe_etq': etiqueta.layetqText ?? '',
            },
          )
          .toList();

      final requestBody = {'coleta': 'ETIQUETA', 'imei': 7829, 'itens': itens};
      final url = Uri.parse('$_baseUrl/coletor');
      final response = await _post(
        url,
        headers: {
          ..._jsonHeaders,
          'User-Agent': 'Mozilla/3.0 (compatible; IndyLibrary)',
          'Connection': 'keep-alive',
        },
        body: jsonEncode(requestBody),
        timeout: _timeoutLong,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw Exception('Erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao enviar etiquetas para o coletor: $e');
    }
  }

  /// Busca dados do produto por código de barras usando a API /api/fv/produtos
  Future<Map<String, dynamic>?> buscarProdutoFV(String codigoBarras) async {
    if (!isConfigured) {
      throw Exception('API não configurada');
    }
    try {
      final url = Uri.parse('$_baseUrl/fv/produtos');
      LoggerService.d('Buscando produto FV com: $url');
      final codigoSan = (codigoBarras)
          .replaceAll(RegExp(r'[\s\r\n\t]'), '')
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
      LoggerService.d('Código de barras procurado: "$codigoSan"');
      final response = await _get(url, timeout: _timeoutLong);
      LoggerService.d('Busca FV - Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        LoggerService.d(
          'Tamanho da resposta: ${response.body.length} caracteres',
        );
        try {
          LoggerService.d('Iniciando decodificação JSON...');
          final data = jsonDecode(response.body);
          LoggerService.d(
            'JSON decodificado com sucesso. Tipo: ${data.runtimeType}',
          );
          if (data is List) {
            LoggerService.d('Total de produtos recebidos: ${data.length}');
            Map<String, dynamic>? produto;
            int itemsProcessados = 0;
            LoggerService.d('Iniciando busca otimizada...');
            for (var item in data) {
              itemsProcessados++;
              if (item == null || item is! Map<String, dynamic>) {
                continue;
              }
              try {
                final codBarras = item['cod_barras'];
                if (codBarras == null) continue;
                final codBarrasStr = (codBarras.toString())
                    .replaceAll(RegExp(r'[\s\r\n\t]'), '')
                    .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
                final codigoBarrasStr = (codigoBarras)
                    .replaceAll(RegExp(r'[\s\r\n\t]'), '')
                    .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
                if (codBarrasStr == codigoBarrasStr) {
                  produto = item;
                  LoggerService.d(
                    'PRODUTO ENCONTRADO no item $itemsProcessados!',
                  );
                  break;
                }
              } catch (_) {
                continue;
              }
              if (itemsProcessados % 1000 == 0) {
                LoggerService.d('Processados $itemsProcessados itens...');
              }
            }
            if (produto != null) {
              LoggerService.i('Produto encontrado com sucesso!');
              return produto;
            } else {
              LoggerService.i(
                'Produto não encontrado na lista de ${data.length} itens',
              );
              return null;
            }
          } else if (data is Map<String, dynamic>) {
            LoggerService.d('Resposta única recebida');
            return data;
          } else {
            LoggerService.w(
              'Formato de resposta inesperado: ${data.runtimeType}',
            );
            return null;
          }
        } catch (e) {
          LoggerService.e('Erro ao decodificar JSON: $e');
          throw Exception('Erro ao processar resposta da API: $e');
        }
      } else {
        LoggerService.e('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro na busca do produto FV: $e');
      throw Exception('Erro ao buscar produto: $e');
    }
  }

  Future<void> enviarInventario(List<InventarioItem> itens) async {
    if (_baseUrl?.isEmpty ?? true) {
      throw Exception('URL base não configurada');
    }
    try {
      LoggerService.d('Enviando inventário com ${itens.length} itens...');
      final inventarioRequest = InventarioRequest(itens: itens);
      final url = Uri.parse('$_baseUrl/coletor');
      LoggerService.d('URL do inventário: $url');
      final body = jsonEncode(inventarioRequest.toJson());
      // Evita logar corpo completo
      LoggerService.d('Tamanho do corpo da requisição: ${body.length}');
      final response = await _post(
        url,
        headers: _jsonHeaders,
        body: body,
        timeout: _timeoutLong,
      );
      LoggerService.d('Status da resposta: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.i('Inventário enviado com sucesso!');
      } else {
        LoggerService.e('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro ao enviar inventário: $e');
      throw Exception('Erro ao enviar inventário: $e');
    }
  }

  Future<void> enviarEntrada(List<InventarioItem> itens) async {
    if (_baseUrl?.isEmpty ?? true) {
      throw Exception('URL base não configurada');
    }
    try {
      LoggerService.d('Enviando entrada com ${itens.length} itens...');
      final entradaRequest = InventarioRequest(coleta: 'ENTRADA', itens: itens);
      final url = Uri.parse('$_baseUrl/coletor');
      LoggerService.d('URL da entrada: $url');
      final body = jsonEncode(entradaRequest.toJson());
      // Evita logar corpo completo
      LoggerService.d('Tamanho do corpo da requisição: ${body.length}');
      final response = await _post(
        url,
        headers: _jsonHeaders,
        body: body,
        timeout: _timeoutLong,
      );
      LoggerService.d('Status da resposta: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.i('Entrada enviada com sucesso!');
      } else {
        LoggerService.e('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro ao enviar entrada: $e');
      throw Exception('Erro ao enviar entrada: $e');
    }
  }
}
