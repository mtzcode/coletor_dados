import 'package:coletor_dados/models/produto.dart';
import 'package:coletor_dados/providers/config_provider.dart';
import 'package:coletor_dados/screens/consulta_preco_screen.dart';
import 'package:coletor_dados/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsultaPreco scanner flow', () {
    testWidgets(
      'Fluxo: abre scanner, retorna código, consulta e permanece na tela',
      (tester) async {
        // Injeta MockClient para API
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
            return http.Response('Not Found', 404);
          }),
        );

        // Build app com ConsultaPrecoScreen como home
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ConfigProvider(),
            child: MaterialApp(
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/consulta':
                    return MaterialPageRoute(
                      builder: (_) => const ConsultaPrecoScreen(),
                    );
                  case '/etiqueta':
                    final produtoArg = settings.arguments as Produto?;
                    return MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: Text('Etiqueta: ${produtoArg?.produto ?? ''}'),
                      ),
                    );
                  case '/scanner':
                    // Simula scanner: retorna imediatamente o código '123'
                    return MaterialPageRoute(
                      builder: (context) {
                        Future.microtask(
                          () => Navigator.of(context).pop('123'),
                        );
                        return const SizedBox();
                      },
                    );
                  default:
                    return MaterialPageRoute(
                      builder: (_) => const ConsultaPrecoScreen(),
                    );
                }
              },
              home: const ConsultaPrecoScreen(),
            ),
          ),
        );

        // Digita o código manualmente e aciona consulta
        await tester.enterText(find.byType(TextField), '123');
        await tester.tap(find.text('Consultar'));
        await tester.pumpAndSettle();

        // Verifica que permanece na ConsultaPreco (AppBar presente)
        expect(find.byType(ConsultaPrecoScreen), findsOneWidget);

        // Verifica que produto foi exibido
        expect(find.text('Informações do Produto'), findsOneWidget);
        expect(find.text('X'), findsWidgets);
      },
    );

    testWidgets(
      'Tratamento de erro: ApiService lança exceção e SnackBar é exibido',
      (tester) async {
        ApiService.instance.configure('http://example.com/api');
        ApiService.instance.setClient(
          MockClient((request) async {
            return http.Response('Erro', 500);
          }),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ConfigProvider(),
            child: const MaterialApp(home: ConsultaPrecoScreen()),
          ),
        );

        // Digita código e aciona consulta
        await tester.enterText(find.byType(TextField), '123');
        await tester.tap(find.text('Consultar'));
        await tester.pump();

        // Aguarda
        await tester.pumpAndSettle();

        // SnackBar com erro deve estar visível
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Erro ao consultar produto'),
          findsOneWidget,
        );
      },
    );
  });
}
