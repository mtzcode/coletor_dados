import 'package:coletor_dados/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:coletor_dados/services/feedback_service.dart';

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

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController();
  // Evita múltiplos pops caso onDetect dispare várias vezes
  bool _isHandlingResult = false;
  // Estado do flash para refletir no ícone e tooltip
  bool _torchOn = false;

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
            onPressed: () async {
              try {
                await controller.toggleTorch();
                setState(() {
                  _torchOn = !_torchOn;
                });
              } catch (e) {
                _showMessage('Não foi possível alternar o flash.');
                LoggerService.e(
                  'BarcodeScannerScreen: Erro ao alternar flash: $e',
                );
              }
            },
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            tooltip: _torchOn ? 'Desligar flash' : 'Ligar flash',
          ),
          // Botão para trocar câmera
          IconButton(
            onPressed: () async {
              try {
                await controller.switchCamera();
              } catch (e) {
                _showMessage('Não foi possível trocar a câmera.');
                LoggerService.e(
                  'BarcodeScannerScreen: Erro ao trocar câmera: $e',
                );
              }
            },
            icon: const Icon(Icons.camera_rear, color: Colors.white),
          ),
          // Botão cancelar
          IconButton(
            onPressed: () {
              _isHandlingResult = true;
              controller.stop();
              if (mounted) {
                Navigator.of(context).pop(null);
              }
            },
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cancelar',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _foundBarcode),

          // Moldura de orientação
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  height: MediaQuery.of(context).size.width * 0.45,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aponte o código para dentro da moldura',
                  style: TextStyle(
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),

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

  void _showMessage(String message) {
    if (!mounted) return;
    FeedbackService.showSnack(
      context,
      message,
      type: FeedbackService.classifyMessage(message),
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

    // Feedback háptico antes de fechar
    HapticFeedback.selectionClick();

    // Para a câmera enquanto processa
    controller.stop();

    try {
      if (!mounted) {
        LoggerService.d(
          'BarcodeScannerScreen: Widget não montado, abortando pop.',
        );
        // Retoma leitura se ainda estiver na tela
        setState(() {
          _isHandlingResult = false;
        });
        controller.start();
        return;
      }

      LoggerService.d(
        'BarcodeScannerScreen: Fechando scanner e retornando código...',
      );
      Navigator.of(context).pop(code);
      LoggerService.d('BarcodeScannerScreen: Navigator.pop executado');
    } catch (e) {
      LoggerService.e('BarcodeScannerScreen: Erro ao processar código: $e');
      _showMessage('Erro ao processar código. Tente novamente.');
      // Retomar leitura
      if (mounted) {
        setState(() {
          _isHandlingResult = false;
        });
        controller.start();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }
}
