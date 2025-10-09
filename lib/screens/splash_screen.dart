import 'package:flutter/material.dart';
import 'package:nymbus_coletor/providers/config_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    // Inicializa o provider
    await configProvider.init();

    // Aguarda um pouco para mostrar a splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navega para a tela apropriada
    if (configProvider.isConfigured) {
      navigator.pushReplacementNamed('/login');
    } else {
      navigator.pushReplacementNamed('/config', arguments: 'splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Coletor de Dados',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'Inicializando...',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
