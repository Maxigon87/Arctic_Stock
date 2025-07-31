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

  // ✅ Inicializa control de ventana
  await windowManager.ensureInitialized();

  // ✅ Configura opciones iniciales
  WindowOptions windowOptions = const WindowOptions(
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: "Artic Stock",
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize(); // 🔥 Se abre maximizada
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: MaterialApp(
          key: ValueKey(_themeMode),
          debugShowCheckedModeBanner: false,
          title: "Artic Stock",
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: _themeMode,
          home: ArticLoginScreen(onToggleTheme: _toggleTheme),
        ),
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Artic Stock"),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.wb_sunny
                : Icons.nights_stay),
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
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final opt = _options[index];
                    return _AnimatedHomeCard(
                      title: opt.title,
                      icon: opt.icon,
                      color: opt.color,
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
    Navigator.of(context).push(_createRoute(screens[index]));
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

class _AnimatedHomeCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedHomeCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedHomeCard> createState() => _AnimatedHomeCardState();
}

class _AnimatedHomeCardState extends State<_AnimatedHomeCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _pressed = false;
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double scale = _hovering ? 1.05 : 1.0;
    if (_pressed) scale = 0.97;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        child: Stack(
          children: [
            // 🔥 Fondo base del botón
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFE6F7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(_hovering ? 0.4 : 0.2),
                    blurRadius: _hovering ? 20 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),

            // ❄️ Capa animada de brillo en el borde
            AnimatedBuilder(
              animation: _shineController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: [0.2, 0.5, 0.8],
                      begin: Alignment(-1.0 + 2.0 * _shineController.value, 0),
                      end: Alignment(1.0 + 2.0 * _shineController.value, 0),
                      tileMode: TileMode.clamp,
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcATop,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.transparent, width: 2),
                    ),
                  ),
                );
              },
            ),

            // 🌟 Contenido (Icono + Texto)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                splashColor: Colors.blueAccent.withOpacity(0.1),
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                onTap: widget.onTap,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon,
                            size: 42, color: Colors.blue.shade700),
                        const SizedBox(height: 8),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  color: Colors.white.withOpacity(0.7),
                                  offset: Offset(0, 1),
                                  blurRadius: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
