import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nymbus_coletor/services/api_service.dart';

void main() {
  group('ApiService unit tests', () {
    setUp(() {
      ApiService.instance.configure('http://example.com/api');
    });

    test(
      'Retry/backoff: primeira tentativa falha por timeout, segunda tem sucesso',
      () async {
        int callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (request.method == 'GET' &&
              request.url.path.endsWith('/fv/produtos')) {
            if (callCount == 1) {
              throw TimeoutException('timeout');
            }
            return http.Response(
              jsonEncode([
                {
                  'cod_barras': '123',
                  'cod_produto': '1',
                  'produto': 'Teste',
                  'unidade': 'UN',
                  'valor_venda1': 9.9,
                },
              ]),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });
        ApiService.instance.setClient(client);

        final result = await ApiService.instance.buscarProdutoFV('123');
        expect(result, isNotNull);
        expect(callCount, 2); // 1 falha + 1 sucesso
      },
    );

    test('Unauthorized handler Ã© chamado em 401 (GET)', () async {
      bool unauthorizedCalled = false;
      ApiService.instance.setUnauthorizedHandler(() {
        unauthorizedCalled = true;
      });
      final client = MockClient((request) async {
        return http.Response('', 401);
      });
      ApiService.instance.setClient(client);

      final conectado = await ApiService.instance.testarConectividade('0000');
      expect(
        conectado,
        isTrue,
      ); // testarConectividade retorna true para status < 500
      expect(unauthorizedCalled, isTrue);
    });

    test(
      'Unauthorized handler Ã© chamado em 403 (POST) e enviarDados retorna false',
      () async {
        bool unauthorizedCalled = false;
        ApiService.instance.setUnauthorizedHandler(() {
          unauthorizedCalled = true;
        });
        final client = MockClient((request) async {
          if (request.method == 'POST' && request.url.path.endsWith('/dados')) {
            return http.Response('', 403);
          }
          return http.Response('Not Found', 404);
        });
        ApiService.instance.setClient(client);

        final ok = await ApiService.instance.enviarDados({'a': 1});
        expect(ok, isFalse);
        expect(unauthorizedCalled, isTrue);
      },
    );

    test('buscarProdutoFV lanÃ§a exceÃ§Ã£o em erro 500', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/fv/produtos')) {
          return http.Response('erro', 500);
        }
        return http.Response('Not Found', 404);
      });
      ApiService.instance.setClient(client);
      expect(
        () => ApiService.instance.buscarProdutoFV('999'),
        throwsA(isA<Exception>()),
      );
    });

    test('Retry/backoff: GET falha por TimeoutException atÃ© estourar e rethrow', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/etiquetas')) {
          throw TimeoutException('timeout');
        }
        return http.Response('Not Found', 404);
      });
      ApiService.instance.setClient(client);
      expect(
        () => ApiService.instance.buscarTiposEtiquetas(),
        throwsA(isA<Exception>()),
      );
    });

    test('Unauthorized handler Ã© chamado em 401 (GET) em /etiquetas e mÃ©todo lanÃ§a exceÃ§Ã£o', () async {
      bool unauthorizedCalled = false;
      ApiService.instance.setUnauthorizedHandler(() {
        unauthorizedCalled = true;
      });
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/etiquetas')) {
          return http.Response('', 401);
        }
        return http.Response('Not Found', 404);
      });
      ApiService.instance.setClient(client);
      await expectLater(
        ApiService.instance.buscarTiposEtiquetas(),
        throwsA(isA<Exception>()),
      );
      expect(unauthorizedCalled, isTrue);
    });

    test('Unauthorized handler Ã© chamado em 403 (GET) em /etiquetas e mÃ©todo lanÃ§a exceÃ§Ã£o', () async {
      bool unauthorizedCalled = false;
      ApiService.instance.setUnauthorizedHandler(() {
        unauthorizedCalled = true;
      });
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/etiquetas')) {
          return http.Response('', 403);
        }
        return http.Response('Not Found', 404);
      });
      ApiService.instance.setClient(client);
      await expectLater(
        ApiService.instance.buscarTiposEtiquetas(),
        throwsA(isA<Exception>()),
      );
      expect(unauthorizedCalled, isTrue);
    });

    test('Retry/backoff: POST falha por ClientException atÃ© estourar e rethrow', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/dados')) {
          throw http.ClientException('client error');
        }
        return http.Response('Not Found', 404);
      });
      ApiService.instance.setClient(client);
      expect(
        () => ApiService.instance.enviarDados({'a': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('POST enviarDados retorna verdadeiro em 201', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/dados')) {
          return http.Response('', 201);
        }
        return http.Response('Not Found', 404);
      });
      ApiService.instance.setClient(client);
      final ok = await ApiService.instance.enviarDados({'x': 2});
      expect(ok, isTrue);
    });
  });
}
