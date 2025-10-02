import 'package:flutter/material.dart';
import 'config_screen.dart';
import 'etiqueta_screen.dart';
import 'consulta_preco_screen.dart';
import 'inventario_screen.dart';
import 'entrada_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  void _abrirEtiqueta() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EtiquetaScreen(),
      ),
    );
  }

  void _abrirConsultaPreco() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConsultaPrecoScreen(),
      ),
    );
  }

  void _abrirInventario() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InventarioScreen(),
      ),
    );
  }

  void _abrirEntrada() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EntradaScreen(),
      ),
    );
  }

  void _irParaConfiguracoes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfigScreen(fromScreen: 'home'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coletor de Dados'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _irParaConfiguracoes,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sistema de Etiquetas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pesquise produtos por código de barras\ne imprima etiquetas facilmente',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _abrirEtiqueta,
                  icon: const Icon(Icons.label, size: 24),
                  label: const Text(
                    'Etiqueta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _abrirConsultaPreco,
                  icon: const Icon(Icons.search, size: 24),
                  label: const Text(
                    'Consulta Preço',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _abrirInventario,
                  icon: const Icon(Icons.inventory, size: 24),
                  label: const Text(
                    'Inventário',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _abrirEntrada,
                  icon: const Icon(Icons.input, size: 24),
                  label: const Text(
                    'Entrada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}