import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nymbus_coletor/models/produto.dart';
import 'package:nymbus_coletor/screens/config_screen.dart';
import 'package:nymbus_coletor/screens/consulta_preco_screen.dart';
import 'package:nymbus_coletor/screens/entrada_screen.dart';
import 'package:nymbus_coletor/screens/etiqueta_screen.dart';
import 'package:nymbus_coletor/screens/home_screen.dart';
import 'package:nymbus_coletor/screens/inventario_screen.dart';
import 'package:nymbus_coletor/screens/inventario_update_screen.dart';
import 'package:nymbus_coletor/screens/login_screen.dart';
import 'package:nymbus_coletor/screens/splash_screen.dart';
import 'package:nymbus_coletor/services/scanner_service.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: '/config',
        name: 'config',
        builder: (BuildContext context, GoRouterState state) {
          final from = state.extra as String? ?? 'login';
          return ConfigScreen(fromScreen: from);
        },
      ),
      GoRoute(
        path: '/etiqueta',
        name: 'etiqueta',
        builder: (BuildContext context, GoRouterState state) {
          final produtoArg = state.extra as Produto?;
          return EtiquetaScreen(produtoParaAdicionar: produtoArg);
        },
      ),
      GoRoute(
        path: '/consulta',
        name: 'consulta',
        builder: (BuildContext context, GoRouterState state) =>
            const ConsultaPrecoScreen(),
      ),
      GoRoute(
        path: '/inventario',
        name: 'inventario',
        builder: (BuildContext context, GoRouterState state) =>
            const InventarioScreen(),
      ),
      GoRoute(
        path: '/entrada',
        name: 'entrada',
        builder: (BuildContext context, GoRouterState state) =>
            const EntradaScreen(),
      ),
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        builder: (BuildContext context, GoRouterState state) =>
            const BarcodeScannerScreen(),
      ),
      GoRoute(
        path: '/inventario-update',
        name: 'inventario-update',
        builder: (BuildContext context, GoRouterState state) {
          final produto = state.extra as Produto;
          return InventarioUpdateScreen(produto: produto);
        },
      ),
    ],
  );
}
