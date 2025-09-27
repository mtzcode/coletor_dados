import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../models/produto.dart';
import '../models/inventario_item.dart';

class StorageService {
  static const String _configKey = 'app_config';
  static const String _etiquetasKey = 'etiquetas_pendentes';
  static const String _inventarioKey = 'inventario_itens';

  /// Salva a configuração no armazenamento local
  static Future<bool> saveConfig(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(config.toMap());
      return await prefs.setString(_configKey, configJson);
    } catch (e) {
      debugPrint('Erro ao salvar configuração: $e');
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
      return AppConfig.fromMap(configMap);
    } catch (e) {
      debugPrint('Erro ao carregar configuração: $e');
      return null;
    }
  }

  /// Remove a configuração do armazenamento local
  static Future<bool> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_configKey);
    } catch (e) {
      debugPrint('Erro ao limpar configuração: $e');
      return false;
    }
  }

  /// Verifica se existe uma configuração salva
  static Future<bool> hasConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_configKey);
    } catch (e) {
      debugPrint('Erro ao verificar configuração: $e');
      return false;
    }
  }

  /// Salva a lista de etiquetas pendentes no armazenamento local
  static Future<bool> saveEtiquetas(List<Produto> etiquetas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final etiquetasJson = jsonEncode(etiquetas.map((e) => e.toJson()).toList());
      return await prefs.setString(_etiquetasKey, etiquetasJson);
    } catch (e) {
      debugPrint('Erro ao salvar etiquetas: $e');
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
      return etiquetasList.map((json) {
        // Precisamos criar um fromJson que aceite dados serializados
        final data = json as Map<String, dynamic>;
        return Produto(
          codBarras: data['cod_barras'] ?? '',
          codProduto: data['cod_produto'] ?? '',
          produto: data['produto'] ?? '',
          unidade: data['unidade'] ?? '',
          valorVenda: (data['valor_venda'] as num?)?.toDouble() ?? 0.0,
          dataHoraRequisicao: DateTime.parse(data['data_hora_requisicao'] ?? DateTime.now().toIso8601String()),
          numeroItem: data['numero_item'] ?? 0,
          tipoEtiqueta: data['tipo_etiqueta'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Erro ao carregar etiquetas: $e');
      return [];
    }
  }

  /// Remove todas as etiquetas pendentes do armazenamento local
  static Future<bool> clearEtiquetas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_etiquetasKey);
    } catch (e) {
      debugPrint('Erro ao limpar etiquetas: $e');
      return false;
    }
  }

  /// Verifica se existem etiquetas pendentes salvas
  static Future<bool> hasEtiquetas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_etiquetasKey);
    } catch (e) {
      debugPrint('Erro ao verificar etiquetas: $e');
      return false;
    }
  }

  /// Salva a lista de itens de inventário no armazenamento local
  static Future<bool> saveInventarioItens(List<InventarioItem> itens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itensJson = jsonEncode(itens.map((item) => {
        'item': item.item,
        'codigo': item.codigo,
        'barras': item.barras,
        'produto': item.produto,
        'unidade': item.unidade,
        'estoqueAtual': item.estoqueAtual,
        'novoEstoque': item.novoEstoque,
        'dtCriacao': item.dtCriacao.toIso8601String(),
      }).toList());
      return await prefs.setString(_inventarioKey, itensJson);
    } catch (e) {
      debugPrint('Erro ao salvar itens de inventário: $e');
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
          barras: data['barras'] ?? '',
          produto: data['produto'] ?? '',
          unidade: data['unidade'] ?? '',
          estoqueAtual: (data['estoqueAtual'] as num?)?.toDouble() ?? 0.0,
          novoEstoque: (data['novoEstoque'] as num?)?.toDouble() ?? 0.0,
          dtCriacao: DateTime.parse(data['dtCriacao'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      debugPrint('Erro ao carregar itens de inventário: $e');
      return [];
    }
  }

  /// Remove todos os itens de inventário do armazenamento local
  static Future<bool> clearInventarioItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_inventarioKey);
    } catch (e) {
      debugPrint('Erro ao limpar itens de inventário: $e');
      return false;
    }
  }

  /// Verifica se existem itens de inventário salvos
  static Future<bool> hasInventarioItens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_inventarioKey);
    } catch (e) {
      debugPrint('Erro ao verificar itens de inventário: $e');
      return false;
    }
  }
}