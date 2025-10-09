import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nymbus_coletor/models/inventario_item.dart';
import 'package:nymbus_coletor/models/produto.dart';
import 'package:nymbus_coletor/providers/config_provider.dart';
import 'package:nymbus_coletor/screens/entrada_screen.dart';
import 'package:nymbus_coletor/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('EntradaScreen scanner flow', () {
    testWidgets(
      'Fluxo: abre scanner, retorna cÃ³digo, consulta, adiciona item e permanece na tela',
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
            return http.Response('Not Found', 404);
          }),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ConfigProvider(),
            child: MaterialApp(
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/inventario-update':
                    final produtoArg = settings.arguments as Produto?;
                    return MaterialPageRoute<InventarioItem>(
                      builder: (context) {
                        // Simula tela de quantidade retornando um InventarioItem imediatamente
                        Future.microtask(() {
                          final p = produtoArg!;
                          final item = InventarioItem(
                            item: p.numeroItem,
                            codigo: int.tryParse(p.codProduto) ?? 0,
                            barras: p.codBarras,
                            produto: p.produto,
                            unidade: p.unidade,
                            estoqueAtual: p.qtdEstoque ?? 0.0,
                            novoEstoque: 1.0,
                          );
                          Navigator.of(context).pop(item);
                        });
                        return const SizedBox();
                      },
                    );
                  case '/scanner':
                    // Simula scanner retornando cÃ³digo '123' imediatamente
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
                      builder: (_) => const EntradaScreen(),
                    );
                }
              },
              home: const EntradaScreen(),
            ),
          ),
        );

        // Aciona scanner pelo Ã­cone da cÃ¢mera
        await tester.tap(find.byIcon(Icons.camera_alt));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verifica que permanece na EntradaScreen
        expect(find.byType(EntradaScreen), findsOneWidget);

        // Verifica que item foi adicionado
        expect(find.text('Nenhum item na entrada'), findsNothing);
        expect(find.text('X'), findsWidgets);
        expect(
          find.textContaining('Enviar Entrada (1 itens)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tratamento de erro: ApiService lanÃ§a exceÃ§Ã£o e SnackBar Ã© exibido',
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
                      builder: (_) => const EntradaScreen(),
                    );
                }
              },
              home: const EntradaScreen(),
            ),
          ),
        );

        // Aciona scanner para iniciar pesquisa com erro
        await tester.tap(find.byIcon(Icons.camera_alt));
        await tester.pump();
        await tester.pumpAndSettle();

        // SnackBar com erro deve estar visÃ­vel
        expect(find.byType(SnackBar), findsOneWidget);

      },
    );
  });
}
