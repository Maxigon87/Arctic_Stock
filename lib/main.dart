import 'dart:async';
import 'package:ArticStock/Services/db_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'screens/product_list_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/debt_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/clientes_screen.dart';
import 'screens/historial_archivos_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/artic_background.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/artic_login_screen.dart';
import 'dart:io';
import 'screens/splash_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es_AR', null);
  Intl.defaultLocale = 'es_AR';
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: "Artic Stock",
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87, foregroundColor: Colors.white),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Artic Stock",
      theme: darkTheme,
      locale: const Locale('es', 'AR'),
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(),
    );
    // <-- Add this closing parenthesis for WillPopScope
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late StreamSubscription _dbSub;
  int _productosSinStock = 0;
  bool _animarBadge = false;

  final List<_HomeOption> _options = const [
    _HomeOption("Productos", Icons.shopping_bag, Colors.blue),
    _HomeOption("Ventas", Icons.point_of_sale, Colors.green),
    _HomeOption("Deudas", Icons.money_off, Colors.redAccent),
    _HomeOption("Reportes", Icons.analytics, Colors.orange),
    _HomeOption("Historial", Icons.folder_open, Colors.purple),
    _HomeOption("Clientes", Icons.people, Colors.teal),
    _HomeOption("Dashboard", Icons.dashboard, Colors.indigo),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(_MyWindowListener(this));
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _loadProductosSinStock();
    _dbSub =
        DBService().onDatabaseChanged.listen((_) => _loadProductosSinStock());
  }

  Future<void> _loadProductosSinStock() async {
    final count = await DBService().getProductosSinStockCount();

    if (mounted && count != _productosSinStock) {
      setState(() {
        _productosSinStock = count;
        _animarBadge = true; // 🔥 dispara animación
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _animarBadge = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dbSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          final shouldExit = await _mostrarDialogoConfirmacion(context);
          return shouldExit ?? false;
        },
        child: Scaffold(
          appBar: AppBar(
            leading: Image.asset('assets/logo/logo_sin_titulo.png'),
            title: const Text("Artic Stock"),
            actions: [
              IconButton(
                tooltip: "Salir de la App",
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  exit(0); // 🔥 Cierra la app al instante (solo en Desktop)
                },
              ),
            ],
          ),
          body: ArticBackground(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 900 ? 3 : 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio:
                            1.3, // 🔥 ajusta proporción a tu gusto
                      ),
                      itemCount: _options.length,
                      itemBuilder: (context, index) {
                        final opt = _options[index];
                        return _AnimatedHomeCard(
                          title: opt.title,
                          icon: opt.icon,
                          color: opt.color,
                          badgeCount: opt.title == "Productos"
                              ? _productosSinStock
                              : null,
                          animateBadge: opt.title == "Productos"
                              ? _animarBadge
                              : false, // ✅
                          onTap: () => _navigateTo(context, index),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
    // <-- Add this closing parenthesis for WillPopScope
  }

  void _navigateTo(BuildContext context, int index) {
    final screens = [
      ProductListScreen(),
      SalesScreen(),
      DebtScreen(),
      ReportesScreen(),
      HistorialArchivosScreen(),
      ClientesScreen(),
      DashboardScreen(),
    ];
    Navigator.of(context).push(_createRoute(screens[index])).then((_) {
      _loadProductosSinStock();
    });
  }

  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Salir de Artic Stock?"),
        content: const Text("¿Estás seguro que querés cerrar la aplicación?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text("Salir"),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        final fadeAnimation = Tween<double>(begin: 0, end: 1)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));
        return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child));
      },
    );
  }
}

class _HomeOption {
  final String title;
  final IconData icon;
  final Color color;
  const _HomeOption(this.title, this.icon, this.color);
}

class _AnimatedHomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool animateBadge;

  const _AnimatedHomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
    this.animateBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 160,
              maxWidth: 180,
              minHeight: 140,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE6F7FF)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 42, color: color),
                const SizedBox(height: 8),
                Text(title,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedScale(
              scale: animateBadge ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MyWindowListener extends WindowListener {
  final _HomeScreenState state;
  _MyWindowListener(this.state);

  @override
  Future<bool> onWindowClose() async {
    final shouldExit = await state._mostrarDialogoConfirmacion(state.context);
    if (shouldExit == true) {
      return true; // cerrar
    } else {
      return false; // cancelar
    }
  }
}
