import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dashboard/mobile_dashboard_screen.dart';
import '../sales/mobile_sales_screen.dart';
import '../products/mobile_products_screen.dart';
import '../clients/mobile_clients_screen.dart';
import '../more/mobile_more_screen.dart';

import '../../widgets/snow_background.dart';
import '../../services/sync_service.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MobileDashboardScreen(),
    MobileSalesScreen(),
    MobileProductsScreen(),
    MobileClientsScreen(),
    MobileMoreScreen(),
  ];

  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Salir de Arctic Stock?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro que querés cerrar la aplicación?',
          style: GoogleFonts.manrope(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            child: Text("Cancelar", style: GoogleFonts.manrope(color: isDark ? Colors.white60 : Colors.black54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Salir"),
            onPressed: () async {
              BuildContext? loaderContext;
              showDialog(
                context: ctx,
                barrierDismissible: false,
                builder: (loadingCtx) {
                  loaderContext = loadingCtx;
                  return WillPopScope(
                    onWillPop: () async => false,
                    child: const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE))),
                          SizedBox(height: 16),
                          Text("Guardando y sincronizando cambios pendientes antes de salir...", textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                },
              );

              try {
                await SyncService().syncData(force: true);
              } catch (_) {}

              if (loaderContext != null) {
                Navigator.of(loaderContext!).pop();
              }
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final barColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return WillPopScope(
      onWillPop: () async {
        final salir = await _mostrarDialogoConfirmacion(context);
        return salir ?? false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SnowBackground(
          child: _screens[_currentIndex],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: barColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: barColor,
            selectedItemColor: const Color(0xFF0EA5E9),
            unselectedItemColor: unselectedColor,
            selectedLabelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale_outlined),
                activeIcon: Icon(Icons.point_of_sale),
                label: 'Ventas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Productos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Clientes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_outlined),
                activeIcon: Icon(Icons.more_horiz),
                label: 'Más',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
