import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerService {
  static Future<String?> scanBarcode(BuildContext context) async {
    debugPrint('ScannerService: Iniciando scanner...');
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );
      debugPrint('ScannerService: Scanner retornou: $result');
      return result;
    } catch (e) {
      debugPrint('ScannerService: Erro durante escaneamento: $e');
      rethrow;
    }
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  // Evita múltiplos pops caso onDetect dispare várias vezes
  bool _isHandlingResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner de Código de Barras'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botão do flash
          IconButton(
            onPressed: () => controller.toggleTorch(),
            icon: const Icon(Icons.flash_on, color: Colors.white),
          ),
          // Botão para trocar câmera
          IconButton(
            onPressed: () => controller.switchCamera(),
            icon: const Icon(Icons.camera_rear, color: Colors.white),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: _foundBarcode,
      ),
    );
  }

  void _foundBarcode(BarcodeCapture capture) {
    if (_isHandlingResult) {
      debugPrint('BarcodeScannerScreen: Detecção ignorada (já processando resultado).');
      return;
    }

    final String code = capture.barcodes.first.rawValue ?? '';
    if (code.isEmpty) {
      debugPrint('BarcodeScannerScreen: Código vazio, ignorando detecção.');
      return;
    }

    _isHandlingResult = true;
    debugPrint('BarcodeScannerScreen: Código detectado: $code');

    // Para a câmera antes de fechar a tela para evitar erros de Surface/Buffer
    controller.stop();

    if (!mounted) {
      debugPrint('BarcodeScannerScreen: Widget não montado, abortando pop.');
      return;
    }

    debugPrint('BarcodeScannerScreen: Fechando scanner e retornando código...');
    Navigator.of(context).pop(code);
    debugPrint('BarcodeScannerScreen: Navigator.pop executado');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}