import 'package:coletor_dados/models/inventario_item.dart';
import 'package:coletor_dados/models/produto.dart';
import 'package:coletor_dados/providers/config_provider.dart';
import 'package:coletor_dados/services/api_service.dart';
import 'package:coletor_dados/services/feedback_service.dart';
import 'package:coletor_dados/services/logger_service.dart';
import 'package:coletor_dados/services/scanner_service.dart';
import 'package:coletor_dados/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EntradaScreen extends StatefulWidget {
  const EntradaScreen({super.key});

  @override
  State<EntradaScreen> createState() => _EntradaScreenState();
}

class _EntradaScreenState extends State<EntradaScreen> {
  final _codigoController = TextEditingController();

  bool _isSearching = false;

  // Lista de itens de entrada (com quantidade já definida)
  final List<InventarioItem> _itensEntrada = [];
  int _contadorItens = 1;

  // Função para formatar números (mostra inteiro se não tem casas decimais)
  String _formatarQuantidade(double quantidade) {
    if (quantidade == quantidade.toInt()) {
      return quantidade.toInt().toString();
    }
    return quantidade.toString();
  }

  @override
  void initState() {
    super.initState();
    _carregarItensEntrada();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _carregarItensEntrada() async {
    try {
      final itensSalvos = await StorageService.loadEntradaItens();
      if (itensSalvos.isNotEmpty) {
        setState(() {
          _itensEntrada.addAll(itensSalvos);
          // Atualiza o contador para o próximo item
          _contadorItens = _itensEntrada.length + 1;
        });
      }
    } catch (e) {
      LoggerService.e('Erro ao carregar itens de entrada: $e');
    }
  }

  Future<void> _salvarItensEntrada() async {
    try {
      await StorageService.saveEntradaItens(_itensEntrada);
    } catch (e) {
      LoggerService.e('Erro ao salvar itens de entrada: $e');
    }
  }

  Future<void> _abrirScanner() async {
    try {
      final codigo = await ScannerService.scanBarcode(context);
      if (!mounted) return;
      if (codigo != null && codigo.isNotEmpty) {
        _codigoController.text = codigo;
        _pesquisarProduto();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erro ao abrir scanner: $e');
      }
    }
  }

  Future<void> _pesquisarProduto() async {
    final codigo = _codigoController.text.trim();

    if (codigo.isEmpty) {
      _showMessage('Digite um código para pesquisar');
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final configProvider = Provider.of<ConfigProvider>(
        context,
        listen: false,
      );
      // Removido: final navigator = Navigator.of(context);

      // Configura a API se necessário
      if (configProvider.config.endereco.isNotEmpty &&
          configProvider.config.porta.isNotEmpty) {
        final baseUrl =
            'http://${configProvider.config.endereco}:${configProvider.config.porta}/api';
        ApiService.instance.configure(baseUrl);
      }

      final produto = await ApiService.instance.buscarProdutoFV(codigo);

      if (produto != null) {
        if (!mounted) return;
        // Limpa o campo de código
        _codigoController.clear();

        // Cria o produto e abre automaticamente a tela de quantidade
        final novoProduto = Produto.fromJson(produto, _contadorItens);
        _abrirTelaQuantidade(novoProduto);
      } else {
        if (mounted) {
          _showMessage('Produto não encontrado');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erro ao pesquisar produto: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _abrirTelaQuantidade(Produto produto) async {
    final navigator = Navigator.of(context);
    final resultado = await navigator.pushNamed<InventarioItem>(
      '/inventario-update',
      arguments: produto,
    );

    if (!mounted) return;
    if (resultado != null) {
      setState(() {
        _itensEntrada.add(resultado);
        _contadorItens++;
      });
      // Salva automaticamente os itens
      await _salvarItensEntrada();
      _showMessage('Item adicionado à entrada!');
    }
  }

  void _removerItem(int index) async {
    setState(() {
      _itensEntrada.removeAt(index);
    });
    // Salva automaticamente os itens
    await _salvarItensEntrada();
    _showMessage('Item removido da entrada');
  }

  void _editarItem(int index) {
    final item = _itensEntrada[index];
    // Cria um produto temporário para edição
    final produto = Produto(
      codProduto: item.codigo.toString(),
      codBarras: item.barras,
      produto: item.produto,
      unidade: item.unidade,
      valorVenda: 0.0,
      dataHoraRequisicao: DateTime.now(),
      numeroItem: item.item,
      dataAtualizacao: '',
      qtdEstoque: item.estoqueAtual,
    );

    _abrirEdicaoItem(produto, index);
  }

  void _abrirEdicaoItem(Produto produto, int index) async {
    final navigator = Navigator.of(context);
    final resultado = await navigator.pushNamed<InventarioItem>(
      '/inventario-update',
      arguments: produto,
    );

    if (!mounted) return;
    if (resultado != null) {
      setState(() {
        _itensEntrada[index] = resultado;
      });
      // Salva automaticamente os itens
      await _salvarItensEntrada();
      _showMessage('Item atualizado!');
    }
  }

  Future<void> _enviarEntrada() async {
    if (_itensEntrada.isEmpty) {
      _showMessage('Adicione pelo menos um item à entrada');
      return;
    }

    try {
      final navigator = Navigator.of(context);
      await ApiService.instance.enviarEntrada(_itensEntrada);
      if (!mounted) return;
      _showMessage('Entrada enviada com sucesso!');
      setState(() {
        _itensEntrada.clear();
      });
      await StorageService.clearEntradaItens();
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (mounted) {
        _showMessage('Erro ao enviar entrada: $e');
      }
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
        title: const Text('Entrada'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Campo de pesquisa
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
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
                    labelText: 'Código do produto',
                    hintText: 'Digite o código de barras',
                    border: const OutlineInputBorder(),
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _abrirScanner,
                      tooltip: 'Escanear código de barras',
                    ),
                  ),
                  onSubmitted: (_) => _pesquisarProduto(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _pesquisarProduto,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isSearching ? 'Pesquisando...' : 'Pesquisar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de itens da entrada
          Expanded(
            child: _itensEntrada.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.input, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum item na entrada',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pesquise produtos para adicionar à entrada',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _itensEntrada.length,
                    itemBuilder: (context, index) {
                      final item = _itensEntrada[index];
                      return _buildItemCard(item, index);
                    },
                  ),
          ),

          // Botão de enviar entrada
          if (_itensEntrada.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviarEntrada,
                  icon: const Icon(Icons.send),
                  label: Text('Enviar Entrada (${_itensEntrada.length} itens)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventarioItem item, int index) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Item ${item.item.toString().padLeft(3, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.barras,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.dtCriacaoFormatada,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () => _editarItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removerItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Segunda linha: Nome do produto
            Text(
              item.produto,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Terceira linha: Estoque atual e novo estoque
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Atual: ${_formatarQuantidade(item.estoqueAtual)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Novo: ${_formatarQuantidade(item.novoEstoque)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.unidade,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
