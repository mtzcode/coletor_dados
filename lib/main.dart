import 'package:flutter/material.dart';
import 'package:nymbus_coletor/models/inventario_item.dart';
import 'package:nymbus_coletor/models/produto.dart';
import 'package:nymbus_coletor/providers/config_provider.dart';
import 'package:nymbus_coletor/screens/config_screen.dart';
import 'package:nymbus_coletor/screens/consulta_preco_screen.dart';
import 'package:nymbus_coletor/screens/entrada_screen.dart';
import 'package:nymbus_coletor/screens/etiqueta_screen.dart';
import 'package:nymbus_coletor/screens/home_screen.dart';
import 'package:nymbus_coletor/screens/inventario_screen.dart';
import 'package:nymbus_coletor/screens/inventario_update_screen.dart';
import 'package:nymbus_coletor/screens/login_screen.dart';
import 'package:nymbus_coletor/screens/splash_screen.dart';
import 'package:nymbus_coletor/services/api_service.dart';
import 'package:nymbus_coletor/services/scanner_service.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Registra handler global de nÃ£o autorizado (401/403) para redirecionar ao Login
    ApiService.instance.setUnauthorizedHandler(() {
      final nav = _rootNavigatorKey.currentState;
      if (nav == null) return;
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    });

    return ChangeNotifierProvider(
      create: (context) => ConfigProvider(),
      child: MaterialApp(
        navigatorKey: _rootNavigatorKey,
        title: 'Coletor de Dados',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        home: const SplashScreen(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/config':
              final from = (settings.arguments as String?) ?? 'login';
              return MaterialPageRoute(
                builder: (_) => ConfigScreen(fromScreen: from),
              );
            case '/etiqueta':
              final produtoArg = settings.arguments as Produto?;
              return MaterialPageRoute(
                builder: (_) =>
                    EtiquetaScreen(produtoParaAdicionar: produtoArg),
              );
            case '/consulta':
              return MaterialPageRoute(
                builder: (_) => const ConsultaPrecoScreen(),
              );
            case '/inventario':
              return MaterialPageRoute(
                builder: (_) => const InventarioScreen(),
              );
            case '/entrada':
              return MaterialPageRoute(builder: (_) => const EntradaScreen());
            case '/scanner':
              return MaterialPageRoute<String>(
                builder: (_) => const BarcodeScannerScreen(),
              );
            case '/inventario-update':
              final produto = settings.arguments as Produto;
              return MaterialPageRoute<InventarioItem>(
                builder: (_) => InventarioUpdateScreen(produto: produto),
              );
            default:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
