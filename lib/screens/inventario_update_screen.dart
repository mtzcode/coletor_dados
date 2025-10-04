import 'package:coletor_dados/models/inventario_item.dart';
import 'package:coletor_dados/models/produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InventarioUpdateScreen extends StatefulWidget {
  final Produto produto;

  const InventarioUpdateScreen({super.key, required this.produto});

  @override
  State<InventarioUpdateScreen> createState() => _InventarioUpdateScreenState();
}

class _InventarioUpdateScreenState extends State<InventarioUpdateScreen> {
  final _quantidadeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Deixa o campo vazio para o usuário inserir a quantidade
    _quantidadeController.text = '';
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    super.dispose();
  }

  void _confirmarQuantidade() {
    if (_formKey.currentState!.validate()) {
      final novaQuantidade = double.tryParse(_quantidadeController.text) ?? 0.0;

      // Cria o item de inventário
      final inventarioItem = InventarioItem(
        item: widget.produto.numeroItem,
        codigo: int.tryParse(widget.produto.codProduto) ?? 0,
        barras: widget.produto.codBarras,
        produto: widget.produto.produto,
        unidade: widget.produto.unidade,
        estoqueAtual: widget.produto.qtdEstoque ?? 0.0,
        novoEstoque: novaQuantidade,
      );

      // Retorna o item para a tela anterior
      Navigator.pop(context, inventarioItem);
    }
  }

  void _cancelar() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atualizar Estoque'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmarQuantidade,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Informações do produto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Item ${widget.produto.numeroItem}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.produto.produto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Código: ${widget.produto.codProduto}'),
                  Text('Código de Barras: ${widget.produto.codBarras}'),
                  Text('Unidade: ${widget.produto.unidade}'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Estoque atual: ${widget.produto.qtdEstoqueFormatada}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Formulário de atualização
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova Quantidade',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _quantidadeController,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        hintText: '0',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite uma quantidade';
                        }
                        final quantidade = double.tryParse(value);
                        if (quantidade == null) {
                          return 'Digite um número válido';
                        }
                        if (quantidade < 0) {
                          return 'A quantidade não pode ser negativa';
                        }
                        return null;
                      },
                      autofocus: true,
                      onFieldSubmitted: (_) => _confirmarQuantidade(),
                    ),

                    const Spacer(),

                    // Botões de ação
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _cancelar,
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmarQuantidade,
                            icon: const Icon(Icons.check),
                            label: const Text('Confirmar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
