import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nymbus_coletor/providers/config_provider.dart';
import 'package:nymbus_coletor/screens/etiqueta_screen.dart';
import 'package:nymbus_coletor/services/api_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EtiquetaScreen scanner flow', () {
    testWidgets(
      'Fluxo: abre scanner, retorna código, consulta, adiciona à lista e permanece na tela',
      (tester) async {
        // Configura API e MockClient
        ApiService.instance.configure('http://example.com/api');
        ApiService.instance.setClient(
          MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path.endsWith('/fv/produtos')) {
              return http.Response(
                '{"cod_barras":"123","cod_produto":"1","produto":"X","unidade":"UN","valor_venda1":5.0}',
                200,
              );
            }
            if (request.method == 'GET' &&
                request.url.path.endsWith('/etiquetas')) {
              return http.Response('[]', 200);
            }
            return http.Response('Not Found', 404);
          }),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ConfigProvider(),
            child: MaterialApp(
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/scanner':
                    // Simula scanner retornando código '123' imediatamente
                    return MaterialPageRoute<String>(
                      builder: (context) {
                        Future.microtask(
                          () => Navigator.of(context).pop('123'),
                        );
                        return const SizedBox();
                      },
                    );
                  default:
                    return MaterialPageRoute(
                      builder: (_) => const EtiquetaScreen(),
                    );
                }
              },
              home: const EtiquetaScreen(),
            ),
          ),
        );

        // Aciona scanner pelo Ã­cone da cÃ¢mera no campo de cÃ³digo
        await tester.tap(find.byIcon(Icons.camera_alt));
        await tester.pump();
        // Evita timeout de pumpAndSettle em animaÃ§Ãµes longas; usa pump temporizado
        await tester.pump(const Duration(milliseconds: 800));

        // Verifica que permanece na EtiquetaScreen
        expect(find.byType(EtiquetaScreen), findsOneWidget);

        // Verifica que produto foi adicionado Ã  lista
        expect(find.text('Etiquetas (1)'), findsOneWidget);
        expect(find.text('X'), findsWidgets);
        expect(
          find.textContaining('Enviar 1 Etiqueta(s) para Servidor'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tratamento de erro: ApiService lança exceção e SnackBar é exibido',
      (tester) async {
        ApiService.instance.configure('http://example.com/api');
        ApiService.instance.setClient(
          MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path.endsWith('/etiquetas')) {
              return http.Response('[]', 200);
            }
            return http.Response('Erro', 500);
          }),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ConfigProvider(),
            child: MaterialApp(
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/scanner':
                    return MaterialPageRoute<String>(
                      builder: (context) {
                        Future.microtask(
                          () => Navigator.of(context).pop('123'),
                        );
                        return const SizedBox();
                      },
                    );
                  default:
                    return MaterialPageRoute(
                      builder: (_) => const EtiquetaScreen(),
                    );
                }
              },
              home: const EtiquetaScreen(),
            ),
          ),
        );

        // Aciona scanner para iniciar pesquisa com erro
        await tester.tap(find.byIcon(Icons.camera_alt));
        await tester.pump();
        // Pump maior para garantir que o SnackBar apareÃ§a sem aguardar sua remoÃ§Ã£o
        await tester.pump(const Duration(milliseconds: 800));

        // SnackBar com erro deve estar visÃ­vel
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Erro ao pesquisar produto'),
          findsOneWidget,
        );

      },
    );
  });
}
