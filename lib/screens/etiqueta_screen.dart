import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../services/api_service.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';
import '../services/feedback_service.dart';
import '../services/logger_service.dart';
import '../models/produto.dart';
import '../models/etiqueta_coletor.dart';

class EtiquetaScreen extends StatefulWidget {
  final Produto? produtoParaAdicionar;
  
  const EtiquetaScreen({super.key, this.produtoParaAdicionar});

  @override
  State<EtiquetaScreen> createState() => _EtiquetaScreenState();
}

class _EtiquetaScreenState extends State<EtiquetaScreen> {
  final _codigoController = TextEditingController();
  
  bool _isSearching = false;
  bool _isPrinting = false;
  bool _isLoadingEtiquetas = false;
  
  // Lista de produtos pesquisados
  final List<Produto> _produtosPesquisados = [];
  List<TipoEtiqueta> _tiposEtiquetas = [];
  TipoEtiqueta? _tipoEtiquetaGlobal; // Tipo de etiqueta global
  int _contadorItens = 1;

  @override
  void initState() {
    super.initState();
    _carregarTiposEtiquetas();
    _carregarEtiquetasSalvas();
    _adicionarProdutoSeNecessario();
  }

  void _adicionarProdutoSeNecessario() {
    if (widget.produtoParaAdicionar != null) {
      // Aguarda um frame para garantir que a tela foi construída
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          // Atualiza o número do item baseado na lista atual
          final novoProduto = Produto.fromJson(widget.produtoParaAdicionar!.toJson(), _contadorItens);
          _produtosPesquisados.add(novoProduto);
          _contadorItens++;
        });
        // Salva automaticamente
        _salvarEtiquetas();
        _showMessage('Produto adicionado à lista de etiquetas!');
      });
    }
  }

  @override
  void dispose() {
    // Salva as etiquetas antes de fechar a tela
    _salvarEtiquetas();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _carregarTiposEtiquetas() async {
    setState(() {
      _isLoadingEtiquetas = true;
    });

    try {
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      
      // Configura a API se necessário
      if (configProvider.config.endereco.isNotEmpty && configProvider.config.porta.isNotEmpty) {
        final baseUrl = 'http://${configProvider.config.endereco}:${configProvider.config.porta}/api';
        ApiService.instance.configure(baseUrl);
      }

      final etiquetas = await ApiService.instance.buscarTiposEtiquetas();
      
      if (mounted) {
        setState(() {
          _tiposEtiquetas = etiquetas.map((e) => TipoEtiqueta.fromJson(e)).toList();
          if (_tiposEtiquetas.isNotEmpty) {
            // Procura por "Gondola Grande" como padrão
            _tipoEtiquetaGlobal = _tiposEtiquetas.firstWhere(
              (tipo) => tipo.nome.toLowerCase().contains('gondola') && tipo.nome.toLowerCase().contains('grande'),
              orElse: () => _tiposEtiquetas.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erro ao carregar tipos de etiquetas: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEtiquetas = false;
        });
      }
    }
  }

  Future<void> _carregarEtiquetasSalvas() async {
    try {
      final etiquetasSalvas = await StorageService.loadEtiquetas();
      if (mounted && etiquetasSalvas.isNotEmpty) {
        setState(() {
          _produtosPesquisados.addAll(etiquetasSalvas);
          // Atualiza o contador para o próximo item
          if (etiquetasSalvas.isNotEmpty) {
            _contadorItens = etiquetasSalvas.map((e) => e.numeroItem).reduce((a, b) => a > b ? a : b) + 1;
          }
        });
      }
    } catch (e) {
      LoggerService.e('Erro ao carregar etiquetas salvas: $e');
    }
  }

  Future<void> _salvarEtiquetas() async {
    try {
      await StorageService.saveEtiquetas(_produtosPesquisados);
    } catch (e) {
      LoggerService.e('Erro ao salvar etiquetas: $e');
    }
  }

  Future<void> _abrirScanner() async {
    try {
      LoggerService.d('EtiquetaScreen: Iniciando scanner...');
      final codigo = await ScannerService.scanBarcode(context);
      if (!mounted) return;
      LoggerService.d('EtiquetaScreen: Scanner retornou código: $codigo');
      
      if (codigo != null && codigo.isNotEmpty) {
        LoggerService.d('EtiquetaScreen: Código válido recebido, definindo no controller...');
        _codigoController.text = codigo;
        LoggerService.d('EtiquetaScreen: Iniciando pesquisa do produto...');
        await _pesquisarProduto();
        LoggerService.d('EtiquetaScreen: Pesquisa do produto concluída');
      } else {
        LoggerService.d('EtiquetaScreen: Código vazio ou nulo recebido do scanner');
      }
    } catch (e) {
      LoggerService.e('EtiquetaScreen: Erro no scanner: $e');
      if (mounted) {
        _showMessage('Erro ao abrir scanner: $e');
      }
    }
  }

  Future<void> _pesquisarProduto() async {
    LoggerService.d('EtiquetaScreen: Iniciando _pesquisarProduto...');
    
    if (_codigoController.text.trim().isEmpty) {
      LoggerService.d('EtiquetaScreen: Código vazio, abortando pesquisa');
      _showMessage('Por favor, digite um código de barras');
      return;
    }

    LoggerService.d('EtiquetaScreen: Código para pesquisa: ${_codigoController.text.trim()}');
    
    setState(() {
      _isSearching = true;
    });

    try {
      LoggerService.d('EtiquetaScreen: Obtendo configuração...');
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      
      // Configura a API se necessário
      if (configProvider.config.endereco.isNotEmpty && configProvider.config.porta.isNotEmpty) {
        final baseUrl = 'http://${configProvider.config.endereco}:${configProvider.config.porta}/api';
        LoggerService.d('EtiquetaScreen: Configurando API com baseUrl: $baseUrl');
        ApiService.instance.configure(baseUrl);
      }

      // Busca o produto na API
      LoggerService.d('EtiquetaScreen: Iniciando busca na API...');
      final produtoData = await ApiService.instance.buscarProdutoFV(_codigoController.text.trim());
      LoggerService.d('EtiquetaScreen: Busca na API concluída. Produto encontrado: ${produtoData != null}');
      
      if (produtoData != null) {
        LoggerService.d('EtiquetaScreen: Verificando se widget ainda está montado...');
        if (mounted) {
          LoggerService.d('EtiquetaScreen: Widget montado, processando produto...');
          final novoProduto = Produto.fromJson(produtoData, _contadorItens);
          
          // Define o tipo de etiqueta global se disponível
          if (_tipoEtiquetaGlobal != null) {
            novoProduto.tipoEtiqueta = _tipoEtiquetaGlobal!.nome;
          }
          
          LoggerService.d('EtiquetaScreen: Adicionando produto à lista...');
          setState(() {
            _produtosPesquisados.add(novoProduto);
            _contadorItens++;
          });
          
          // Salva automaticamente as etiquetas
          LoggerService.d('EtiquetaScreen: Salvando etiquetas...');
          await _salvarEtiquetas();
          
          // Limpa o campo de código para próxima pesquisa
          LoggerService.d('EtiquetaScreen: Limpando campo de código...');
          _codigoController.clear();
          LoggerService.d('EtiquetaScreen: Exibindo mensagem de sucesso...');
          _showMessage('Produto adicionado à lista!');
          LoggerService.d('EtiquetaScreen: Processo concluído com sucesso!');
        } else {
          LoggerService.d('EtiquetaScreen: Widget não está mais montado, abortando processamento');
        }
      } else {
        LoggerService.d('EtiquetaScreen: Produto não encontrado na API');
        if (mounted) {
          _showMessage('Produto não encontrado');
        }
      }
    } catch (e, st) {
      LoggerService.e('EtiquetaScreen: Erro durante pesquisa: $e\nStack: $st');
      if (mounted) {
        _showMessage('Erro ao pesquisar produto: $e');
      }
    } finally {
      LoggerService.d('EtiquetaScreen: Finalizando pesquisa...');
      if (mounted) {
        LoggerService.d('EtiquetaScreen: Widget montado, definindo _isSearching = false');
        setState(() {
          _isSearching = false;
        });
      } else {
        LoggerService.d('EtiquetaScreen: Widget não montado, não atualizando estado');
      }
      LoggerService.d('EtiquetaScreen: _pesquisarProduto finalizada');
    }
  }

  Future<void> _enviarParaServidor() async {
    if (_produtosPesquisados.isEmpty) {
      _showMessage('Adicione produtos à lista primeiro');
      return;
    }

    if (_tipoEtiquetaGlobal == null) {
      _showMessage('Selecione um tipo de etiqueta');
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      
      // Configura a API se necessário
      if (configProvider.config.endereco.isNotEmpty && configProvider.config.porta.isNotEmpty) {
        final baseUrl = 'http://${configProvider.config.endereco}:${configProvider.config.porta}/api';
        ApiService.instance.configure(baseUrl);
      }

      // Converte produtos para o formato da tabela ts_arq_etq
      final etiquetas = _produtosPesquisados.map((produto) {
        return EtiquetaColetor.fromProduto(
          codProduto: produto.codProduto,
          codBarras: produto.codBarras,
          nomeProduto: produto.produto,
          unidade: produto.unidade,
          tipoEtiqueta: _tipoEtiquetaGlobal!.nome,
          quantidade: 1,
          preco: produto.valorVenda.toString(),
        );
      }).toList();

      // Envia para a API do coletor
      LoggerService.d('EtiquetaScreen: Enviando ${etiquetas.length} etiqueta(s) para API do coletor...');
      final sucesso = await ApiService.instance.enviarEtiquetasColetor(etiquetas);

      if (mounted) {
        if (sucesso) {
          LoggerService.d('EtiquetaScreen: Envio de etiquetas concluído com sucesso');
          _showMessage('${_produtosPesquisados.length} etiqueta(s) enviada(s) para o servidor!');
          _limparLista();
        } else {
          LoggerService.e('EtiquetaScreen: Falha ao enviar etiquetas para o servidor');
          _showMessage('Erro ao enviar etiquetas para o servidor');
        }
      }
    } catch (e) {
      LoggerService.e('EtiquetaScreen: Erro ao enviar etiquetas: $e');
      if (mounted) {
        _showMessage('Erro ao enviar etiquetas: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  void _removerProduto(int index) {
    setState(() {
      _produtosPesquisados.removeAt(index);
    });
    // Salva automaticamente após remover
    _salvarEtiquetas();
    _showMessage('Produto removido da lista');
  }

  void _limparLista() {
    setState(() {
      _produtosPesquisados.clear();
      _contadorItens = 1;
    });
    // Limpa também as etiquetas salvas
    StorageService.clearEtiquetas();
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
        title: Text('Etiquetas (${_produtosPesquisados.length})'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_produtosPesquisados.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _limparLista,
              tooltip: 'Limpar lista',
            ),
        ],
      ),
      body: Column(
        children: [
          // Seção de configuração e pesquisa
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Seleção de tipo de etiqueta global
                if (_isLoadingEtiquetas)
                  const Center(child: CircularProgressIndicator())
                else if (_tiposEtiquetas.isNotEmpty)
                  DropdownButtonFormField<TipoEtiqueta>(
                    initialValue: _tipoEtiquetaGlobal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Etiqueta (Global)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _tiposEtiquetas.map((tipo) {
                      return DropdownMenuItem<TipoEtiqueta>(
                        value: tipo,
                        child: Text(
                          tipo.nome,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (TipoEtiqueta? novoTipo) {
                      setState(() {
                        _tipoEtiquetaGlobal = novoTipo;
                      });
                    },
                  ),
                
                const SizedBox(height: 16),
                
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
                
                // Campo de pesquisa
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoController,
                        decoration: InputDecoration(
                          labelText: 'Código de Barras',
                          border: const OutlineInputBorder(),
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _abrirScanner,
                            tooltip: 'Escanear código de barras',
                          ),
                          hintText: 'Digite ou escaneie o código',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.text,
                        onSubmitted: (_) => _pesquisarProduto(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSearching ? null : _pesquisarProduto,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isSearching ? 'Buscando...' : 'Adicionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Lista de produtos
          Expanded(
            child: _produtosPesquisados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum produto adicionado',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Digite um código de barras e clique em "Adicionar"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _produtosPesquisados.length,
                    itemBuilder: (context, index) {
                      final produto = _produtosPesquisados[index];
                      return _buildProdutoCard(produto, index);
                    },
                  ),
          ),
          
          // Botão de envio para servidor
          if (_produtosPesquisados.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _isPrinting ? null : _enviarParaServidor,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isPrinting 
                        ? 'Enviando...' 
                        : 'Enviar ${_produtosPesquisados.length} Etiqueta(s) para Servidor',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProdutoCard(Produto produto, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primeira linha: Número do item + Código de barras + Data/hora
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    produto.numeroItemFormatado,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    produto.codBarras,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  produto.dataHoraFormatada,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removerProduto(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Segunda linha: Nome do produto
            Text(
              produto.produto,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Terceira linha: Preço + Tipo de etiqueta
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    produto.precoFormatado,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      produto.tipoEtiqueta ?? _tipoEtiquetaGlobal?.nome ?? 'Sem tipo',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}