import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart' show NavItem;

class ArticSidebar extends StatelessWidget {
  final NavItem selectedItem;
  final ValueChanged<NavItem> onItemSelected;
  final int productosSinStock;
  final bool isCompact;
  final VoidCallback? onNewSale;
  final VoidCallback? onQuickInquiry;

  const ArticSidebar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
    required this.productosSinStock,
    this.isCompact = false,
    this.onNewSale,
    this.onQuickInquiry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF22D3EE); // Celeste brillante / Cyan hielo

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCompact ? 76 : 260,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.45),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
            width: 1.0,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado con Logo y Nombre
              _buildHeader(context, isDark, accentColor),

              // Botón Destacado: Nueva Venta
              _buildActionButton(context, accentColor),

              // Botón Destacado: Consulta Rápida
              _buildQuickInquiryButton(context, accentColor),

              // Elementos del Menú categorizados
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categoría General
                      _buildCategoryHeader(context, "General"),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.none,
                        label: "Inicio",
                        icon: Icons.home_outlined,
                        accentColor: accentColor,
                      ),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.dashboard,
                        label: "Dashboard",
                        icon: Icons.dashboard_outlined,
                        accentColor: accentColor,
                      ),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.reportes,
                        label: "Reportes",
                        icon: Icons.analytics_outlined,
                        accentColor: accentColor,
                      ),

                      const SizedBox(height: 16),
                      // Categoría Operaciones
                      _buildCategoryHeader(context, "Operaciones"),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.ventas,
                        label: "Ventas",
                        icon: Icons.point_of_sale_outlined,
                        accentColor: accentColor,
                      ),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.deudas,
                        label: "Deudas",
                        icon: Icons.money_off_outlined,
                        accentColor: accentColor,
                      ),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.productos,
                        label: "Productos",
                        icon: Icons.inventory_2_outlined,
                        accentColor: accentColor,
                        badgeCount: productosSinStock > 0 ? productosSinStock : null,
                      ),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.clientes,
                        label: "Clientes",
                        icon: Icons.people_outline_outlined,
                        accentColor: accentColor,
                      ),

                      const SizedBox(height: 16),
                      // Categoría Administración
                      _buildCategoryHeader(context, "Administración"),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.historial,
                        label: "Archivos",
                        icon: Icons.folder_open_outlined,
                        accentColor: accentColor,
                      ),
                      _buildMenuItem(
                        context: context,
                        item: NavItem.configuracion,
                        label: "Configuración",
                        icon: Icons.settings_outlined,
                        accentColor: accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color accentColor) {
    if (isCompact) {
      return Container(
        height: 70,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/logo/logo_sin_titulo.png',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Image.asset(
            'assets/logo/logo_sin_titulo.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [accentColor, const Color(0xFF38BDF8)],
                  ).createShader(bounds),
                  child: const Text(
                    "Arctic Stock",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  "POLO CORPORATIVO",
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColors = isDark
        ? [accentColor, const Color(0xFF38BDF8)]
        : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)];

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Tooltip(
            message: "Nueva Venta",
            child: InkWell(
              onTap: onNewSale,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: buttonColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? accentColor : const Color(0xFF0EA5E9)).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_shopping_cart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: buttonColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? accentColor : const Color(0xFF0EA5E9)).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onNewSale,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.add_shopping_cart,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Nueva Venta",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
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

  Widget _buildQuickInquiryButton(BuildContext context, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColors = isDark
        ? [accentColor, accentColor.withValues(alpha: 0.8)]
        : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)];

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Center(
          child: Tooltip(
            message: "Consulta Rápida",
            child: InkWell(
              onTap: onQuickInquiry,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: buttonColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? accentColor : const Color(0xFF0EA5E9)).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: buttonColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? accentColor : const Color(0xFF0EA5E9)).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onQuickInquiry,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Consulta Rápida",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
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

  Widget _buildCategoryHeader(BuildContext context, String title) {
    if (isCompact) return const SizedBox(height: 6);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey : const Color(0xFF475569),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required NavItem item,
    required String label,
    required IconData icon,
    required Color accentColor,
    int? badgeCount,
  }) {
    final isSelected = selectedItem == item;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: 20,
          color: isSelected
              ? (isDark ? accentColor : const Color(0xFF0EA5E9))
              : (isDark ? Colors.white60 : const Color(0xFF475569)),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );

    if (isCompact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Tooltip(
            message: label,
            child: InkWell(
              onTap: () => onItemSelected(item),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.0)
                      : null,
                ),
                alignment: Alignment.center,
                child: iconWidget,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: () => onItemSelected(item),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: isSelected ? accentColor : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0EA5E9))
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
