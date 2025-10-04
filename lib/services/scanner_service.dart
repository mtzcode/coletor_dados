import 'package:coletor_dados/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerService {
  static Future<String?> scanBarcode(BuildContext context) async {
    LoggerService.d('ScannerService: Iniciando scanner...');
    try {
      final result = await Navigator.of(context).pushNamed<String>('/scanner');
      LoggerService.d('ScannerService: Scanner retornou: $result');
      // Sanitiza o código antes de retornar
      final sanitized = (result ?? '')
          .replaceAll(RegExp(r'[\s\r\n\t]'), '')
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
      return result == null ? null : sanitized;
    } catch (e) {
      LoggerService.e('ScannerService: Erro durante escaneamento: $e');
      rethrow;
    }
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController();
  // Evita múltiplos pops caso onDetect dispare várias vezes
  bool _isHandlingResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

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
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _foundBarcode),
          if (_isHandlingResult)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processando código...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (_isHandlingResult) {
      controller.stop();
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.stop();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _foundBarcode(BarcodeCapture capture) {
    if (_isHandlingResult) {
      LoggerService.d(
        'BarcodeScannerScreen: Detecção ignorada (já processando resultado).',
      );
      return;
    }

    final String codeRaw = capture.barcodes.first.rawValue ?? '';
    final String code = codeRaw
        .replaceAll(RegExp(r'[\s\r\n\t]'), '')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
    if (code.isEmpty) {
      LoggerService.d(
        'BarcodeScannerScreen: Código vazio, ignorando detecção.',
      );
      return;
    }

    setState(() {
      _isHandlingResult = true;
    });
    LoggerService.d('BarcodeScannerScreen: Código detectado: $code');

    // Para a câmera antes de fechar a tela para evitar erros de Surface/Buffer
    controller.stop();

    if (!mounted) {
      LoggerService.d(
        'BarcodeScannerScreen: Widget não montado, abortando pop.',
      );
      return;
    }

    LoggerService.d(
      'BarcodeScannerScreen: Fechando scanner e retornando código...',
    );
    Navigator.of(context).pop(code);
    LoggerService.d('BarcodeScannerScreen: Navigator.pop executado');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }
}
