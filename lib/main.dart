import 'dart:async';
import 'dart:io';

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/db_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'widgets/artic_background.dart';
import 'widgets/articlogo.dart';
import 'widgets/artic_sidebar.dart';
import 'widgets/artic_dialog.dart';

import 'utils/theme_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/quick_inquiry_screen.dart';
import 'screens/debt_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/clientes_screen.dart';
import 'screens/historial_archivos_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/artic_login_screen.dart';
import 'features/auth/mobile_login_screen.dart';
import 'features/home/mobile_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final appData = Platform.environment['APPDATA'] ?? '';
    if (appData.isNotEmpty) {
      final dbDir = p.join(appData, 'ArcticStock');
      await databaseFactory.setDatabasesPath(dbDir);
    }
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      title: 'Arctic Stock',
      size: Size(1100, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(const Size(800, 600));
      await Future.delayed(const Duration(milliseconds: 30));
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await initializeDateFormatting('es_AR', null);
  await initializeDateFormatting('es', null);

  Intl.defaultLocale = 'es_AR';

  await ThemeController.instance.init();
  await DBService().initActiveUser();

  // Iniciar sincronización si hay un negocio configurado localmente
  final authService = AuthService();
  final cachedNegocioId = await authService.getLocalNegocioId();
  if (cachedNegocioId != null) {
    SyncService().startPeriodicSync();
    // Ejecutar una sincronización inicial asíncrona
    SyncService().syncData();
  }

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
      iconTheme: const IconThemeData(size: 24),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0284C7),
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
      iconTheme: const IconThemeData(size: 24),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF22D3EE),
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
            '/mobile_login': (_) => const MobileLoginScreen(),
            '/mobile_home': (_) => const MobileHomeScreen(),
          },
          initialRoute: (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ? '/mobile_login' : '/login',
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
  quickInquiry,
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
  bool _hasPendingCart = false;

  NavItem _selected = NavItem.none;
  bool _startNewSaleInVentas = false;
  bool _isWindowMaximized = false;
  final GlobalKey<SalesScreenState> _salesScreenKey = GlobalKey<SalesScreenState>();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final isMax = await windowManager.isMaximized();
        if (!isMax) {
          await windowManager.maximize();
        }
        if (mounted) {
          setState(() {
            _isWindowMaximized = true;
          });
        }
      }
    });
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
    final hasCart = await DBService().getCarritoTemporal() != null;
    if (!mounted) return;
    if (count != _productosSinStock || hasCart != _hasPendingCart) {
      setState(() {
        _productosSinStock = count;
        _hasPendingCart = hasCart;
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
    DBService().setActiveUser(id: null, nombre: null, avatar: null);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ArticLoginScreen()),
      (route) => false,
    );
  }

  // ======== SHELL CON LAYOUT LADO-IZQ / CONTENIDO DERECHA ===
  Widget _buildCustomTitleBar(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isWindows = !kIsWeb && Platform.isWindows;
    final isMac = !kIsWeb && Platform.isMacOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDesktop) {
      return SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              if (DBService().activeUserName != null)
                _UserBadge(
                  name: DBService().activeUserName!,
                  onChangeUser: _goToLogin,
                  onSettings: () =>
                      setState(() => _selected = NavItem.configuracion),
                ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (isMac) const SizedBox(width: 80),
          const Expanded(
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),
          if (DBService().activeUserName != null)
            _UserBadge(
              name: DBService().activeUserName!,
              onChangeUser: _goToLogin,
              onSettings: () =>
                  setState(() => _selected = NavItem.configuracion),
            ),
          if (isWindows) _buildWindowButtons(context, isDark),
        ],
      ),
    );
  }

  Widget _buildWindowButtons(BuildContext context, bool isDark) {
    final iconColor = isDark ? Colors.white70 : const Color(0xFF0F172A);
    final hoverColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWindowButton(
          icon: Icons.minimize,
          color: iconColor,
          hoverColor: hoverColor,
          onTap: () async {
            await windowManager.minimize();
          },
        ),
        _buildWindowButton(
          icon: _isWindowMaximized ? Icons.filter_none : Icons.crop_square,
          iconSize: 12,
          color: iconColor,
          hoverColor: hoverColor,
          onTap: () async {
            if (_isWindowMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
            final isMax = await windowManager.isMaximized();
            setState(() {
              _isWindowMaximized = isMax;
            });
          },
        ),
        _buildWindowButton(
          icon: Icons.close,
          color: iconColor,
          hoverColor: isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1),
          hoverIconColor: Colors.redAccent,
          onTap: () async {
            final salir = await _mostrarDialogoConfirmacion(context);
            if (salir == true) {
              exit(0);
            }
          },
        ),
      ],
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    double iconSize = 14,
    required Color color,
    required Color hoverColor,
    Color? hoverIconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: hoverColor,
      child: SizedBox(
        width: 46,
        height: 40,
        child: Icon(
          icon,
          size: iconSize,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1150;

    return WillPopScope(
      onWillPop: () async =>
          await _mostrarDialogoConfirmacion(context) ?? false,
      child: Scaffold(
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ArticBackground(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    _buildCustomTitleBar(context),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            // ==== LADO IZQUIERDO: BARRA ====
                            ArticSidebar(
                              selectedItem: _selected,
                              onItemSelected: (item) => setState(() => _selected = item),
                              productosSinStock: _productosSinStock,
                              isCompact: isCompact,
                              hasPendingCart: _hasPendingCart,
                              onNewSale: () {
                                setState(() {
                                  _startNewSaleInVentas = true;
                                  _selected = NavItem.ventas;
                                });
                              },
                              onQuickInquiry: () {
                                setState(() {
                                  _selected = NavItem.quickInquiry;
                                });
                              },
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
                  ],
                ),
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
        final startNew = _startNewSaleInVentas;
        _startNewSaleInVentas = false; // reset
        return _PageWrap(
          keyName: 'ventas',
          child: SalesScreen(
            key: _salesScreenKey,
            startNewSale: startNew,
          ),
        );

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
          child: SettingsScreen(),
        );

      case NavItem.quickInquiry:
        return const _PageWrap(
          keyName: 'quickInquiry',
          child: QuickInquiryScreen(),
        );
    }
  }

  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showArticDialog<bool>(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: "¿Salir de Arctic Stock?",
        actions: [
          TextButton(
            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Salir"),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
        child: Text(
          "¿Estás seguro que querés cerrar la aplicación?",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
    return ok;
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
        child: child,
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
          // Date button with plus emoji
          ElevatedButton.icon(
            onPressed: () {
              // Placeholder: could open new user creation
            },
            icon: const Text('📅'),
            label: Text(
              '${DateFormat('dd MMM').format(DateTime.now())} +',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenido',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20),
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
    if (shouldExit == true) {
      await windowManager.destroy();
      return true;
    }
    return false;
  }

  @override
  void onWindowMaximize() {
    state.setState(() {
      state._isWindowMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    state.setState(() {
      state._isWindowMaximized = false;
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            (() {
              final avatarBytes = DBService().activeUserAvatarBytes;
              return CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                backgroundImage: avatarBytes != null
                    ? MemoryImage(avatarBytes)
                    : null,
                child: avatarBytes == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 10),
                      )
                    : null,
              );
            })(),
            if (!isCompact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
