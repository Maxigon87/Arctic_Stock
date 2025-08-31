import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Services/db_service.dart';
import 'widgets/artic_background.dart';
import 'widgets/articlogo.dart';

import 'utils/theme_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/debt_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/clientes_screen.dart';
import 'screens/historial_archivos_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/artic_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await initializeDateFormatting('es_AR', null);
  await initializeDateFormatting('es', null); // opcional
  Intl.defaultLocale = 'es_AR';

  await ThemeController.instance.init();

  const windowOptions = WindowOptions(
    title: 'Arctic Stock',
    minimumSize: Size(800, 600), // ajusta según tu preferencia
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.maximize(); // asegurate que se maximiza tras mostrarse
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
      ).copyWith(
        outline: const Color(0xFFE3F2FD),
        shadow: const Color(0xFFE3F2FD),
      ),
      useMaterial3: true,
      // Provide a base light text theme so colors adapt automatically.
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: const Color(0xFFF6F6F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      cardColor: const Color(0xFFE3F2FD),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ).copyWith(
        outline: const Color(0xFF0D1B2A),
        shadow: const Color(0xFF0D1B2A),
      ),
      useMaterial3: true,
      // Ensure text contrasts properly on dark backgrounds.
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme)
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      cardColor: const Color(0xFF0D1B2A),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Arctic Stock",
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
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
          routes: {
            '/login': (_) => const ArticLoginScreen(),
            '/home': (_) => const HomeScreen(),
          },
          initialRoute: '/login',
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum NavItem {
  none, // estado "logo"
  dashboard,
  ventas,
  productos,
  reportes,
  deudas,
  clientes,
  historial,
  configuracion,
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late StreamSubscription _dbSub;
  late final _MyWindowListener _listener;

  int _productosSinStock = 0;
  bool _animarBadge = false;

  NavItem _selected = NavItem.none;

  int _selectedIndex() => _items.indexWhere((e) => e.id == _selected);

  final List<_NavMeta> _items = const [
    _NavMeta(NavItem.none, 'Inicio', Icons.home_outlined), // <- NUEVO PRIMERO
    _NavMeta(NavItem.dashboard, 'Dashboard', Icons.dashboard_outlined),
    _NavMeta(NavItem.ventas, 'Ventas', Icons.point_of_sale),
    _NavMeta(NavItem.productos, 'Productos', Icons.inventory_2_outlined),
    _NavMeta(NavItem.reportes, 'Reportes', Icons.analytics_outlined),
    _NavMeta(NavItem.deudas, 'Deudas', Icons.money_off),
    _NavMeta(NavItem.clientes, 'Clientes', Icons.people_alt_outlined),
    _NavMeta(NavItem.historial, 'Archivos', Icons.folder_open),
    _NavMeta(NavItem.configuracion, 'Configuración', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _listener = _MyWindowListener(this); // 👈
    windowManager.addListener(_listener);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();

    _loadProductosSinStock();
    _dbSub = DBService().onDatabaseChanged.listen(
      (_) => _loadProductosSinStock(),
    );
  }

  Future<void> _loadProductosSinStock() async {
    final count = await DBService().getProductosSinStockCount();
    if (!mounted) return;
    if (count != _productosSinStock) {
      setState(() {
        _productosSinStock = count;
        _animarBadge = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _animarBadge = false);
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(_listener);
    _controller.dispose();
    _dbSub.cancel();
    super.dispose();
  }

  // dentro de _HomeScreenState
  void _goToLogin() {
    DBService().setActiveUser(id: null, nombre: null);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ArticLoginScreen()),
      (route) => false,
    );
  }

  // ======== SHELL CON LAYOUT LADO-IZQ / CONTENIDO DERECHA =========
  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1150;

    return WillPopScope(
      onWillPop: () async =>
          await _mostrarDialogoConfirmacion(context) ?? false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Gestión comercial total"),
          actions: [
            if (DBService().activeUserName != null)
              _UserBadge(
                name: DBService().activeUserName!,
                onChangeUser: _goToLogin, // 👈 acá
                onSettings: () =>
                    setState(() => _selected = NavItem.configuracion),
              ),
            IconButton(
              tooltip: "Salir de la App",
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                /* ... tu confirmación y exit(0) ... */
              },
            ),
          ],
        ),
        body: ArticBackground(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Row(
                children: [
                  // ==== LADO IZQUIERDO: BARRA ====
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isCompact ? 72 : 260,
                    // barra izquierda
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest, // <- antes: surfaceContainerHighest
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 0.6,
                        ),
                      ),
                    ),

                    child: Column(
                      children: [
                        // Encabezado barra
                        // Encabezado barra (solo logo, sin texto)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Center(
                            child: Image.asset(
                              'assets/logo/logo_sin_titulo.png',
                              width: isCompact ? 28 : 36,
                              height: isCompact ? 28 : 36,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        Expanded(
                          child: NavigationRail(
                            extended: !isCompact,
                            minExtendedWidth: 240,
                            selectedIndex: (_selectedIndex() >= 0)
                                ? _selectedIndex()
                                : 0,
                            onDestinationSelected: (idx) {
                              setState(() => _selected = _items[idx].id);
                            },
                            groupAlignment: -1.0,
                            destinations: _items.map((e) {
                              final isProductos = e.id == NavItem.productos;
                              final showBadge =
                                  isProductos && _productosSinStock > 0;

                              return NavigationRailDestination(
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(e.icon),
                                    if (showBadge)
                                      Positioned(
                                        top: -2,
                                        right: -6,
                                        child: AnimatedScale(
                                          scale: _animarBadge ? 1.2 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: _DotBadge(
                                            count: _productosSinStock,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                selectedIcon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(e.icon),
                                    if (showBadge)
                                      Positioned(
                                        top: -2,
                                        right: -6,
                                        child: AnimatedScale(
                                          scale: _animarBadge ? 1.2 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: _DotBadge(
                                            count: _productosSinStock,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                label: Text(e.label),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // ==== LADO DERECHO: CONTENIDO ====
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _buildContent(_selected),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(NavItem item) {
    switch (item) {
      case NavItem.none:
        return const _LogoView();

      case NavItem.dashboard:
        return const _PageWrap(keyName: 'dashboard', child: DashboardScreen());

      case NavItem.ventas:
        return const _PageWrap(keyName: 'ventas', child: SalesScreen());

      case NavItem.productos:
        return const _PageWrap(
          keyName: 'productos',
          child: ProductListScreen(),
        );

      case NavItem.reportes:
        return const _PageWrap(keyName: 'reportes', child: ReportesScreen());

      case NavItem.deudas:
        return const _PageWrap(keyName: 'deudas', child: DebtScreen());

      case NavItem.clientes:
        return const _PageWrap(keyName: 'clientes', child: ClientesScreen());

      case NavItem.historial:
        return const _PageWrap(
          keyName: 'historial',
          child: HistorialArchivosScreen(),
        );

      case NavItem.configuracion:
        return const _PageWrap(
          keyName: 'config',
          child: SettingsScreen(), // 👈 sin onUsersChanged
        );
    }
  }

  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Salir de Arctic Stock?"),
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
}

class _NavMeta {
  final NavItem id;
  final String label;
  final IconData icon;
  const _NavMeta(this.id, this.label, this.icon);
}

class _PageWrap extends StatelessWidget {
  final Widget child;
  final String keyName;
  const _PageWrap({required this.child, required this.keyName});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: PageStorageKey(keyName),
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LogoView extends StatelessWidget {
  const _LogoView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ArticLogo(size: 440),
          const SizedBox(height: 8),
          Text(
            'Bienvenido',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DotBadge extends StatelessWidget {
  final int count;
  const _DotBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 18),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MyWindowListener extends WindowListener {
  final _HomeScreenState state;
  _MyWindowListener(this.state);

  @override
  Future<bool> onWindowClose() async {
    final shouldExit = await state._mostrarDialogoConfirmacion(state.context);
    return shouldExit == true;
  }
}

class _UserBadge extends StatelessWidget {
  final String name;
  final VoidCallback onChangeUser;
  final VoidCallback onSettings;

  const _UserBadge({
    required this.name,
    required this.onChangeUser,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1000;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<int>(
        tooltip: name,
        onSelected: (v) {
          if (v == 1) onChangeUser();
          if (v == 2) onSettings();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 1, child: Text('Cambiar usuario')),
          PopupMenuItem(value: 2, child: Text('Configuración')),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
