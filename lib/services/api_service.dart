import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logger_service.dart';
import '../models/etiqueta_coletor.dart';
import '../models/inventario_item.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static ApiService get instance => _instance;

  String? _baseUrl;
  bool get isConfigured => _baseUrl != null;

  // Sem headers customizados para evitar preflight OPTIONS

  /// Configura a URL base da API
  void configure(String baseUrl) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }

  /// Testa a conectividade com a API
  Future<bool> testarConectividade([String? licenca]) async {
    if (!isConfigured) return false;
    
    try {
      // Usa a licença fornecida ou uma fictícia para testar conectividade
      final licencaTeste = licenca ?? '0000';
      final url = Uri.parse('$_baseUrl/licenca/$licencaTeste');
      
      LoggerService.d('Testando conectividade com: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );
      
      LoggerService.d('Resposta recebida - Status: ${response.statusCode}, Body: ${response.body}');
      
      // Se o servidor responder (mesmo que seja erro 404 ou outro), significa que está conectado
      return response.statusCode < 500;
    } catch (e) {
      LoggerService.e('Erro de conectividade detalhado: $e');
      LoggerService.d('Tipo do erro: ${e.runtimeType}');
      
      // Verifica se é um erro de CORS
      if (e.toString().contains('Failed to fetch')) {
        LoggerService.w('POSSÍVEL ERRO DE CORS: O navegador está bloqueando a requisição');
        LoggerService.w('Verifique se o servidor da API tem CORS configurado para: ${Uri.base.origin}');
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
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      LoggerService.d('Validação - Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body.toLowerCase().trim();
        final isValid = responseBody == 'ok';
        LoggerService.i('Licença ${isValid ? 'VÁLIDA' : 'INVÁLIDA'} - Resposta: "$responseBody"');
        return isValid;
      } else if (response.statusCode == 404) {
        LoggerService.i('Licença não encontrada (404)');
        return false; // Licença não encontrada
      } else {
        LoggerService.e('Erro do servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro detalhado na validação: $e');
      LoggerService.d('Tipo do erro: ${e.runtimeType}');
      
      if (e.toString().contains('Failed to fetch')) {
        LoggerService.w('ERRO DE CORS: Configure o servidor para aceitar requisições de: ${Uri.base.origin}');
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
      // Primeiro tenta busca direta por código de barras (mais eficiente)
      final urlDireta = Uri.parse('$_baseUrl/produtos/$codigoBarras');
      
      LoggerService.d('Tentando busca direta com: $urlDireta');
      LoggerService.d('Código de barras procurado: "$codigoBarras"');
      
      final responseDireta = await http.get(urlDireta).timeout(
        const Duration(seconds: 10),
      );

      LoggerService.d('Busca direta - Status: ${responseDireta.statusCode}');

      if (responseDireta.statusCode == 200) {
        LoggerService.d('Produto encontrado via busca direta!');
        final data = jsonDecode(responseDireta.body);
        if (data is Map<String, dynamic>) {
          LoggerService.d('Produto encontrado: ${data['produto']}');
          return data;
        } else if (data is List && data.isNotEmpty) {
          LoggerService.d('Lista retornada, pegando primeiro item: ${data[0]['produto']}');
          return data[0] as Map<String, dynamic>;
        }
      } else if (responseDireta.statusCode == 404) {
        LoggerService.d('Produto não encontrado via busca direta, tentando busca geral...');
      } else {
        LoggerService.e('Erro na busca direta: ${responseDireta.statusCode}, tentando busca geral...');
      }

      // Se busca direta falhou, usa busca geral (fallback)
      LoggerService.d('Iniciando busca geral como fallback...');
      final url = Uri.parse('$_baseUrl/produtos');
      
      LoggerService.d('Buscando todos os produtos com: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 30),
      );

      LoggerService.d('Busca geral - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        LoggerService.d('Tamanho da resposta: ${response.body.length} caracteres');
        
        try {
          LoggerService.d('Iniciando decodificação JSON...');
          final data = jsonDecode(response.body);
          LoggerService.d('JSON decodificado com sucesso. Tipo: ${data.runtimeType}');
          
          if (data is List) {
            LoggerService.d('Total de produtos recebidos: ${data.length}');
            
            // Busca otimizada - para na primeira ocorrência
            Map<String, dynamic>? produto;
            int itemsProcessados = 0;
            
            LoggerService.d('Iniciando busca otimizada...');
            for (var item in data) {
              itemsProcessados++;
              
              // Validação básica
              if (item == null || item is! Map<String, dynamic>) {
                continue;
              }
              
              try {
                final codBarras = item['cod_barras'];
                if (codBarras == null) continue;
                
                final codBarrasStr = codBarras.toString().trim();
                final codigoBarrasStr = codigoBarras.trim();
                
                if (codBarrasStr == codigoBarrasStr) {
                  produto = item;
                  LoggerService.d('PRODUTO ENCONTRADO no item $itemsProcessados!');
                  LoggerService.d('Produto: ${produto['produto']}');
                  break;
                }
              } catch (e) {
                // Ignora erros em itens individuais
                continue;
              }
              
              // Log de progresso a cada 1000 itens para acompanhar a busca
              if (itemsProcessados % 1000 == 0) {
                LoggerService.d('Processados $itemsProcessados itens...');
              }
            }
            
            LoggerService.d('Busca concluída. Items processados: $itemsProcessados');
            
            if (produto != null) {
              return produto;
            } else {
              LoggerService.i('Produto com código "$codigoBarras" não encontrado');
              return null;
            }
          } else if (data is Map<String, dynamic>) {
            LoggerService.d('Resposta é um Map, retornando diretamente');
            return data;
          } else {
            LoggerService.w('Resposta da API não é um Map nem List: ${data.runtimeType}');
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
        LoggerService.e('Erro do servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.e('Erro detalhado na busca do produto: $e');
      
      // Tratamento específico para diferentes tipos de erro
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
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      LoggerService.d('Busca etiquetas - Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [data as Map<String, dynamic>];
        }
      } else {
        LoggerService.e('Erro do servidor: ${response.statusCode} - ${response.body}');
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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // Header mínimo necessário para POST
        body: jsonEncode(dados),
      ).timeout(const Duration(seconds: 30));

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
      // Formato JSON baseado na análise do Wireshark
      final itens = etiquetas.map((etiqueta) => {
        'codigo': int.tryParse(etiqueta.etqCodmat ?? '0') ?? 0,
        'barras': etiqueta.etqEan13 ?? '',
        'produto': etiqueta.etqDesc ?? '',
        'un': etiqueta.etqUn ?? '',
        'qtd': etiqueta.etqQtd ?? 1,
        'dt_criacao': etiqueta.etqDthora ?? DateTime.now().toString(),
        'danfe_etq': etiqueta.layetqText ?? '',
      }).toList();

      final requestBody = {
        'coleta': 'ETIQUETA',
        'imei': 7829, // IMEI fixo conforme Wireshark
        'itens': itens,
      };
      
      final url = Uri.parse('$_baseUrl/coletor');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/3.0 (compatible; IndyLibrary)',
          'Connection': 'keep-alive',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
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
      LoggerService.d('Código de barras procurado: "$codigoBarras"');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 30),
      );

      LoggerService.d('Busca FV - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        LoggerService.d('Tamanho da resposta: ${response.body.length} caracteres');
        
        try {
          LoggerService.d('Iniciando decodificação JSON...');
          final data = jsonDecode(response.body);
          LoggerService.d('JSON decodificado com sucesso. Tipo: ${data.runtimeType}');
          
          if (data is List) {
            LoggerService.d('Total de produtos recebidos: ${data.length}');
            
            // Busca otimizada - para na primeira ocorrência
            Map<String, dynamic>? produto;
            int itemsProcessados = 0;
            
            LoggerService.d('Iniciando busca otimizada...');
            for (var item in data) {
              itemsProcessados++;
              
              // Validação básica
              if (item == null || item is! Map<String, dynamic>) {
                continue;
              }
              
              try {
                final codBarras = item['cod_barras'];
                if (codBarras == null) continue;
                
                final codBarrasStr = codBarras.toString().trim();
                final codigoBarrasStr = codigoBarras.trim();
                
                if (codBarrasStr == codigoBarrasStr) {
                  produto = item;
                  LoggerService.d('PRODUTO ENCONTRADO no item $itemsProcessados!');
                  LoggerService.d('Produto: ${produto['produto']}');
                  break;
                }
              } catch (e) {
                // Ignora erros em itens individuais
                continue;
              }
              
              // Log de progresso a cada 1000 itens para acompanhar a busca
              if (itemsProcessados % 1000 == 0) {
                LoggerService.d('Processados $itemsProcessados itens...');
              }
            }
            
            if (produto != null) {
              LoggerService.i('Produto encontrado com sucesso!');
              return produto;
            } else {
              LoggerService.i('Produto não encontrado na lista de ${data.length} itens');
              return null;
            }
          } else if (data is Map<String, dynamic>) {
            LoggerService.d('Resposta única recebida');
            return data;
          } else {
            LoggerService.w('Formato de resposta inesperado: ${data.runtimeType}');
            return null;
          }
        } catch (e) {
          LoggerService.e('Erro ao decodificar JSON: $e');
          throw Exception('Erro ao processar resposta da API: $e');
        }
      } else {
        LoggerService.e('Erro HTTP: ${response.statusCode}');
        LoggerService.e('Corpo da resposta: ${response.body}');
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
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
      
      final inventarioRequest = InventarioRequest(
        coleta: 'INVENTARIO',
        imei: 7829,
        itens: itens,
      );

      final url = Uri.parse('$_baseUrl/coletor');
      LoggerService.d('URL do inventário: $url');

      final body = jsonEncode(inventarioRequest.toJson());
      LoggerService.d('Corpo da requisição: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      LoggerService.d('Status da resposta: ${response.statusCode}');
      LoggerService.d('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.i('Inventário enviado com sucesso!');
      } else {
        LoggerService.e('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
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
      
      final entradaRequest = InventarioRequest(
        coleta: 'ENTRADA',
        imei: 7829,
        itens: itens,
      );

      final url = Uri.parse('$_baseUrl/coletor');
      LoggerService.d('URL da entrada: $url');

      final body = jsonEncode(entradaRequest.toJson());
      LoggerService.d('Corpo da requisição: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      LoggerService.d('Status da resposta: ${response.statusCode}');
      LoggerService.d('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.i('Entrada enviada com sucesso!');
      } else {
        LoggerService.e('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      LoggerService.e('Erro ao enviar entrada: $e');
      throw Exception('Erro ao enviar entrada: $e');
    }
  }
}