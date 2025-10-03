import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/scanner_service.dart';
import '../models/produto.dart';
import 'etiqueta_screen.dart';
import '../services/feedback_service.dart';

class ConsultaPrecoScreen extends StatefulWidget {
  const ConsultaPrecoScreen({super.key});

  @override
  State<ConsultaPrecoScreen> createState() => _ConsultaPrecoScreenState();
}

class _ConsultaPrecoScreenState extends State<ConsultaPrecoScreen> {
  final TextEditingController _codigoController = TextEditingController();
  bool _isSearching = false;
  Produto? _produtoEncontrado;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _abrirScanner() async {
    try {
      final codigo = await ScannerService.scanBarcode(context);
      if (!mounted) return;
      if (codigo != null && codigo.isNotEmpty) {
        _codigoController.text = codigo;
        _consultarProduto();
      }
    } catch (e) {
      _showMessage('Erro ao abrir scanner: $e');
    }
  }

  Future<void> _consultarProduto() async {
    if (_codigoController.text.trim().isEmpty) {
      _showMessage('Digite um código para pesquisar');
      return;
    }

    setState(() {
      _isSearching = true;
      _produtoEncontrado = null;
    });

    try {
      final produtoData = await ApiService.instance.buscarProdutoFV(_codigoController.text.trim());
      
      if (produtoData != null) {
        if (mounted) {
          setState(() {
            _produtoEncontrado = Produto.fromJson(produtoData, 1);
          });
          // Limpa o campo após pesquisa bem-sucedida
          _codigoController.clear();
        }
      } else {
        if (mounted) {
          _showMessage('Produto não encontrado');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erro ao consultar produto: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _enviarParaEtiqueta() {
    if (_produtoEncontrado != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EtiquetaScreen(produtoParaAdicionar: _produtoEncontrado),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    FeedbackService.showSnack(
      context,
      message,
      type: FeedbackService.classifyMessage(message),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta de Preço'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campo de pesquisa
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Texto de orientação
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: const Text(
                        'Digite o código ou use a câmera para escanear',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextField(
                      controller: _codigoController,
                      decoration: InputDecoration(
                        labelText: 'Código do Produto',
                        hintText: 'Digite o código ou código de barras',
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: _abrirScanner,
                          tooltip: 'Escanear código de barras',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _consultarProduto(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSearching ? null : _consultarProduto,
                        icon: _isSearching 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                        label: Text(_isSearching ? 'Consultando...' : 'Consultar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Resultado da consulta
            if (_produtoEncontrado != null) ...[
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informações do Produto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildInfoRow('Código do Produto', _produtoEncontrado!.codProduto),
                                _buildInfoRow('Código de Barras', _produtoEncontrado!.codBarras),
                                _buildInfoRow('Produto', _produtoEncontrado!.produto),
                                _buildInfoRow('Unidade', _produtoEncontrado!.unidade),
                                _buildInfoRow('Valor de Venda', _produtoEncontrado!.precoFormatado),
                                _buildInfoRow('Qtd. Estoque', _produtoEncontrado!.qtdEstoqueFormatada),
                                _buildInfoRow('Data Atualização', _produtoEncontrado!.dataAtualizacaoFormatada),
                                _buildInfoRow('Data/Hora Consulta', _produtoEncontrado!.dataHoraFormatada),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Botão enviar para etiqueta
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _enviarParaEtiqueta,
                            icon: const Icon(Icons.label),
                            label: const Text('Enviar para Etiqueta'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (!_isSearching) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Digite um código para consultar',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}