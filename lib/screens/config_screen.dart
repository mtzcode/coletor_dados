import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class ConfigScreen extends StatefulWidget {
  final String? fromScreen;
  
  const ConfigScreen({super.key, this.fromScreen});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _enderecoController = TextEditingController();
  final _portaController = TextEditingController();
  
  bool _isSyncing = false;
  bool _isConnected = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = Provider.of<ConfigProvider>(context, listen: false).config;
    _enderecoController.text = config.endereco;
    _portaController.text = config.porta;
  }

  @override
  void dispose() {
    _enderecoController.dispose();
    _portaController.dispose();
    super.dispose();
  }

  Future<void> _syncConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSyncing = true;
      _isConnected = false;
      _validationMessage = null;
    });

    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    
    try {
      // Salva a configuração temporariamente para teste
      final saveSuccess = await configProvider.saveConfig(
        endereco: _enderecoController.text.trim(),
        porta: _portaController.text.trim(),
      );

      if (!saveSuccess) {
        setState(() {
          _validationMessage = 'Erro ao salvar configuração temporária';
        });
        return;
      }

      // Testa conectividade
      final isConnected = await configProvider.testarConectividade();
      if (!isConnected) {
        setState(() {
          _validationMessage = 'Não foi possível conectar com o servidor. Verifique o endereço e porta.';
          _isConnected = false;
        });
        return;
      }

      // Valida licença
      final isValid = await configProvider.validarLicenca();
      
      setState(() {
        _isConnected = isValid;
        _validationMessage = isValid 
          ? 'Conexão estabelecida com sucesso! Licença válida ✓' 
          : 'Conectado, mas licença inválida ✗';
      });

      if (isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conexão testada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _validationMessage = 'Erro na sincronização: $e';
        _isConnected = false;
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _saveAndNavigate() async {
    if (!_formKey.currentState!.validate() || !_isConnected) return;

    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    
    final success = await configProvider.saveConfig(
      endereco: _enderecoController.text.trim(),
      porta: _portaController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navega baseado na origem
      if (mounted) {
        if (widget.fromScreen == 'home') {
          // Se veio da tela principal, volta para ela
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          // Se veio da tela de login ou splash, vai para login
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ConfigProvider>(
        builder: (context, configProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.key, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'Licença (gerada automaticamente)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              configProvider.config.licenca,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _enderecoController,
                    decoration: const InputDecoration(
                      labelText: 'Endereço (IP ou DDNS)',
                      prefixIcon: Icon(Icons.language),
                      border: OutlineInputBorder(),
                      hintText: 'Ex: 192.168.1.100',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, informe o endereço';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _portaController,
                    decoration: const InputDecoration(
                      labelText: 'Porta',
                      prefixIcon: Icon(Icons.settings_ethernet),
                      border: OutlineInputBorder(),
                      hintText: 'Ex: 8787',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, informe a porta';
                      }
                      final port = int.tryParse(value.trim());
                      if (port == null || port < 1 || port > 65535) {
                        return 'Porta deve ser um número entre 1 e 65535';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Indicador de status de conexão
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color: _isConnected ? Colors.green : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'Conectado' : 'Desconectado',
                        style: TextStyle(
                          color: _isConnected ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (_validationMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _validationMessage!.contains('✓') 
                          ? Colors.green[50] 
                          : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _validationMessage!.contains('✓') 
                            ? Colors.green 
                            : Colors.red,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _validationMessage!.contains('✓') 
                              ? Icons.check_circle 
                              : Icons.error,
                            color: _validationMessage!.contains('✓') 
                              ? Colors.green 
                              : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationMessage!,
                              style: TextStyle(
                                color: _validationMessage!.contains('✓') 
                                  ? Colors.green[800] 
                                  : Colors.red[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Botões
                  Column(
                    children: [
                      // Primeira linha: Voltar e Sincronizar
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (widget.fromScreen == 'home') {
                                  // Se veio da tela principal, volta para ela
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                                  );
                                } else {
                                  // Se veio da tela de login, apenas pop
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Voltar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSyncing ? null : _syncConfiguration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSyncing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Sincronizar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Segunda linha: Botão Salvar (só ativo se conectado)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isConnected ? _saveAndNavigate : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConnected ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Salvar e Continuar'),
                        ),
                      ),
                    ],
                  ),
                  if (configProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                configProvider.errorMessage!,
                                style: TextStyle(color: Colors.red[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}