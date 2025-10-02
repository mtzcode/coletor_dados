import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
      
      debugPrint('Testando conectividade com: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );
      
      debugPrint('Resposta recebida - Status: ${response.statusCode}, Body: ${response.body}');
      
      // Se o servidor responder (mesmo que seja erro 404 ou outro), significa que está conectado
      return response.statusCode < 500;
    } catch (e) {
      debugPrint('Erro de conectividade detalhado: $e');
      debugPrint('Tipo do erro: ${e.runtimeType}');
      
      // Verifica se é um erro de CORS
      if (e.toString().contains('Failed to fetch')) {
        debugPrint('POSSÍVEL ERRO DE CORS: O navegador está bloqueando a requisição');
        debugPrint('Verifique se o servidor da API tem CORS configurado para: ${Uri.base.origin}');
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
      
      debugPrint('Validando licença com: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      debugPrint('Validação - Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body.toLowerCase().trim();
        final isValid = responseBody == 'ok';
        debugPrint('Licença ${isValid ? 'VÁLIDA' : 'INVÁLIDA'} - Resposta: "$responseBody"');
        return isValid;
      } else if (response.statusCode == 404) {
        debugPrint('Licença não encontrada (404)');
        return false; // Licença não encontrada
      } else {
        debugPrint('Erro do servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erro detalhado na validação: $e');
      debugPrint('Tipo do erro: ${e.runtimeType}');
      
      if (e.toString().contains('Failed to fetch')) {
        debugPrint('ERRO DE CORS: Configure o servidor para aceitar requisições de: ${Uri.base.origin}');
      }
      
      throw Exception('Erro ao validar licença: $e');
    }
  }

  /// Método simplificado para validação de licença
  Future<bool> validarLicencaSimples(String licenca) async {
    try {
      return await validarLicenca(licenca);
    } catch (e) {
      debugPrint('Erro na validação: $e');
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
      
      debugPrint('Tentando busca direta com: $urlDireta');
      debugPrint('Código de barras procurado: "$codigoBarras"');
      
      final responseDireta = await http.get(urlDireta).timeout(
        const Duration(seconds: 10),
      );

      debugPrint('Busca direta - Status: ${responseDireta.statusCode}');

      if (responseDireta.statusCode == 200) {
        debugPrint('Produto encontrado via busca direta!');
        final data = jsonDecode(responseDireta.body);
        if (data is Map<String, dynamic>) {
          debugPrint('Produto encontrado: ${data['produto']}');
          return data;
        } else if (data is List && data.isNotEmpty) {
          debugPrint('Lista retornada, pegando primeiro item: ${data[0]['produto']}');
          return data[0] as Map<String, dynamic>;
        }
      } else if (responseDireta.statusCode == 404) {
        debugPrint('Produto não encontrado via busca direta, tentando busca geral...');
      } else {
        debugPrint('Erro na busca direta: ${responseDireta.statusCode}, tentando busca geral...');
      }

      // Se busca direta falhou, usa busca geral (fallback)
      debugPrint('Iniciando busca geral como fallback...');
      final url = Uri.parse('$_baseUrl/produtos');
      
      debugPrint('Buscando todos os produtos com: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 30),
      );

      debugPrint('Busca geral - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Tamanho da resposta: ${response.body.length} caracteres');
        
        try {
          debugPrint('Iniciando decodificação JSON...');
          final data = jsonDecode(response.body);
          debugPrint('JSON decodificado com sucesso. Tipo: ${data.runtimeType}');
          
          if (data is List) {
            debugPrint('Total de produtos recebidos: ${data.length}');
            
            // Busca otimizada - para na primeira ocorrência
            Map<String, dynamic>? produto;
            int itemsProcessados = 0;
            
            debugPrint('Iniciando busca otimizada...');
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
                  debugPrint('PRODUTO ENCONTRADO no item $itemsProcessados!');
                  debugPrint('Produto: ${produto['produto']}');
                  break;
                }
              } catch (e) {
                // Ignora erros em itens individuais
                continue;
              }
              
              // Log de progresso a cada 1000 itens para acompanhar a busca
              if (itemsProcessados % 1000 == 0) {
                debugPrint('Processados $itemsProcessados itens...');
              }
            }
            
            debugPrint('Busca concluída. Items processados: $itemsProcessados');
            
            if (produto != null) {
              return produto;
            } else {
              debugPrint('Produto com código "$codigoBarras" não encontrado');
              return null;
            }
          } else if (data is Map<String, dynamic>) {
            debugPrint('Resposta é um Map, retornando diretamente');
            return data;
          } else {
            debugPrint('Resposta da API não é um Map nem List: ${data.runtimeType}');
            throw Exception('Formato de resposta inválido');
          }
        } catch (e) {
          debugPrint('Erro na decodificação JSON: $e');
          if (e is FormatException) {
            throw Exception('Erro de formato na resposta da API');
          } else {
            rethrow;
          }
        }
      } else if (response.statusCode == 404) {
        debugPrint('Produto não encontrado (404)');
        return null;
      } else {
        debugPrint('Erro do servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erro detalhado na busca do produto: $e');
      
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
      
      debugPrint('Buscando tipos de etiquetas com: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      debugPrint('Busca etiquetas - Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [data as Map<String, dynamic>];
        }
      } else {
        debugPrint('Erro do servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erro detalhado na busca de etiquetas: $e');
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
      
      debugPrint('Buscando produto FV com: $url');
      debugPrint('Código de barras procurado: "$codigoBarras"');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 30),
      );

      debugPrint('Busca FV - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Tamanho da resposta: ${response.body.length} caracteres');
        
        try {
          debugPrint('Iniciando decodificação JSON...');
          final data = jsonDecode(response.body);
          debugPrint('JSON decodificado com sucesso. Tipo: ${data.runtimeType}');
          
          if (data is List) {
            debugPrint('Total de produtos recebidos: ${data.length}');
            
            // Busca otimizada - para na primeira ocorrência
            Map<String, dynamic>? produto;
            int itemsProcessados = 0;
            
            debugPrint('Iniciando busca otimizada...');
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
                  debugPrint('PRODUTO ENCONTRADO no item $itemsProcessados!');
                  debugPrint('Produto: ${produto['produto']}');
                  break;
                }
              } catch (e) {
                // Ignora erros em itens individuais
                continue;
              }
              
              // Log de progresso a cada 1000 itens para acompanhar a busca
              if (itemsProcessados % 1000 == 0) {
                debugPrint('Processados $itemsProcessados itens...');
              }
            }
            
            if (produto != null) {
              debugPrint('Produto encontrado com sucesso!');
              return produto;
            } else {
              debugPrint('Produto não encontrado na lista de ${data.length} itens');
              return null;
            }
          } else if (data is Map<String, dynamic>) {
            debugPrint('Resposta única recebida');
            return data;
          } else {
            debugPrint('Formato de resposta inesperado: ${data.runtimeType}');
            return null;
          }
        } catch (e) {
          debugPrint('Erro ao decodificar JSON: $e');
          throw Exception('Erro ao processar resposta da API: $e');
        }
      } else {
        debugPrint('Erro HTTP: ${response.statusCode}');
        debugPrint('Corpo da resposta: ${response.body}');
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro na busca do produto FV: $e');
      throw Exception('Erro ao buscar produto: $e');
    }
  }

  Future<void> enviarInventario(List<InventarioItem> itens) async {
    if (_baseUrl?.isEmpty ?? true) {
      throw Exception('URL base não configurada');
    }

    try {
      debugPrint('Enviando inventário com ${itens.length} itens...');
      
      final inventarioRequest = InventarioRequest(
        coleta: 'INVENTARIO',
        imei: 7829,
        itens: itens,
      );

      final url = Uri.parse('$_baseUrl/coletor');
      debugPrint('URL do inventário: $url');

      final body = jsonEncode(inventarioRequest.toJson());
      debugPrint('Corpo da requisição: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      debugPrint('Status da resposta: ${response.statusCode}');
      debugPrint('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Inventário enviado com sucesso!');
      } else {
        debugPrint('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro ao enviar inventário: $e');
      throw Exception('Erro ao enviar inventário: $e');
    }
  }

  Future<void> enviarEntrada(List<InventarioItem> itens) async {
    if (_baseUrl?.isEmpty ?? true) {
      throw Exception('URL base não configurada');
    }

    try {
      debugPrint('Enviando entrada com ${itens.length} itens...');
      
      final entradaRequest = InventarioRequest(
        coleta: 'ENTRADA',
        imei: 7829,
        itens: itens,
      );

      final url = Uri.parse('$_baseUrl/coletor');
      debugPrint('URL da entrada: $url');

      final body = jsonEncode(entradaRequest.toJson());
      debugPrint('Corpo da requisição: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      debugPrint('Status da resposta: ${response.statusCode}');
      debugPrint('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Entrada enviada com sucesso!');
      } else {
        debugPrint('Erro HTTP: ${response.statusCode}');
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro ao enviar entrada: $e');
      throw Exception('Erro ao enviar entrada: $e');
    }
  }
}