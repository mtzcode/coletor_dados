import 'package:flutter/material.dart';

enum FeedbackType { info, success, error, warning }

class FeedbackService {
  static void showSnack(
    BuildContext context,
    String message, {
    FeedbackType type = FeedbackType.info,
    Duration? duration,
  }) {
    final color = _colorFor(type);
    final snack = SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(seconds: 3),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  static Future<void> showErrorDialog(
    BuildContext context, {
    String title = 'Erro',
    required String message,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Heurística simples para classificar a mensagem e aplicar cor adequada
  static FeedbackType classifyMessage(String message) {
    final m = message.toLowerCase();
    if (m.contains('erro') ||
        m.contains('não encontrado') ||
        m.contains('inexistente') ||
        m.contains('falha')) {
      return FeedbackType.error;
    }
    if (m.contains('sucesso') ||
        m.contains('adicionado') ||
        m.contains('removido') ||
        m.contains('atualizado') ||
        m.contains('enviado')) {
      return FeedbackType.success;
    }
    if (m.contains('atenção') ||
        m.contains('aviso') ||
        m.contains('selecione') ||
        m.contains('adicione')) {
      return FeedbackType.warning;
    }
    return FeedbackType.info;
  }

  static Color _colorFor(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return Colors.green.shade600;
      case FeedbackType.error:
        return Colors.red.shade700;
      case FeedbackType.warning:
        return Colors.orange.shade700;
      case FeedbackType.info:
        return Colors.blueGrey.shade600;
    }
  }

  // Alerta didático para orientar o usuário a validar a conexão
  static Future<void> showConfigRequiredDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conexão não validada'),
        content: const Text(
          'Para usar esta função, valide a conexão nas Configurações:\n\n'
          '1) Informe o endereço e a porta do servidor\n'
          '2) Toque em Sincronizar e valide sua licença\n\n'
          'Você pode fazer isso agora tocando no botão abaixo.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              final navigator = Navigator.of(context);
              navigator.pushNamed('/config', arguments: 'home');
            },
            icon: const Icon(Icons.settings),
            label: const Text('Ir para Configurações'),
          ),
        ],
      ),
    );
  }
}
