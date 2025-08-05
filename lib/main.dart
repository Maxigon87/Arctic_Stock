import 'dart:async';
import 'package:ArticStock/Services/db_service.dart';
import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = _themeMode == ThemeMode.dark;
    await prefs.setBool('isDark', !isDark);
    setState(() => _themeMode = !isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green, foregroundColor: Colors.white),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87, foregroundColor: Colors.white),
    );

    return AnimatedTheme(
      data: _themeMode == ThemeMode.dark ? darkTheme : lightTheme,
      duration: const Duration(milliseconds: 400),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Artic Stock",
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeMode,
        home: ArticLoginScreen(onToggleTheme: _toggleTheme),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({Key? key, required this.onToggleTheme}) : super(key: key);

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
    if (mounted) setState(() => _productosSinStock = count);
  }

  @override
  void dispose() {
    _controller.dispose();
    _dbSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Artic Stock"),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny
                  : Icons.nights_stay,
            ),
            onPressed: widget.onToggleTheme,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 900 ? 3 : 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.3, // 🔥 ajusta proporción a tu gusto
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final opt = _options[index];
                    return _AnimatedHomeCard(
                      title: opt.title,
                      icon: opt.icon,
                      color: opt.color,
                      badgeCount:
                          opt.title == "Productos" ? _productosSinStock : null,
                      onTap: () => _navigateTo(context, index),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  const _AnimatedHomeCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  }) : super(key: key);

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
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
