import 'dart:async';
import 'dart:convert'; // 👈 NUEVO
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  final DBService _dbService = DBService();
  late StreamSubscription _dbSub;

  double _ventasHoy = 0;
  double _gananciaHoy = 0;
  int _productosSinStock = 0;
  double _deudasPendientes = 0;
  List<Map<String, dynamic>> _ultimasVentas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _dbSub = _dbService.onDatabaseChanged.listen((_) => _loadData());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  Future<void> _loadData() async {
    try {
      final hoy = DateTime.now();
      
      final vHoy = await _dbService.getTotalVentasDia(hoy);
      final gHoy = await _dbService.getGananciaTotal(
        desde: _startOfDay(hoy),
        hasta: _endOfDay(hoy),
      );
      final sinStock = await _dbService.getProductosSinStockCount();
      final deudas = await _dbService.getTotalDeudasPendientes();

      // Recent 5 sales
      final allSales = await _dbService.getVentas();
      final recentSales = allSales.take(5).toList();

      if (mounted) {
        setState(() {
          _ventasHoy = vHoy;
          _gananciaHoy = gHoy;
          _productosSinStock = sinStock;
          _deudasPendientes = deudas;
          _ultimasVentas = recentSales;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Arctic Stock',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 20, color: textColor),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/logo/logo_sin_titulo.png',
              width: 24,
              height: 24,
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_dbService.activeUserName != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    backgroundImage: (_dbService.activeUserAvatar != null && _dbService.activeUserAvatar!.isNotEmpty)
                        ? MemoryImage(base64Decode(_dbService.activeUserAvatar!))
                        : null,
                    child: (_dbService.activeUserAvatar == null || _dbService.activeUserAvatar!.isEmpty)
                        ? Text(
                            _dbService.activeUserName!.isNotEmpty ? _dbService.activeUserName![0].toUpperCase() : 'U',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9), fontSize: 14),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dbService.activeUserName!,
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF0EA5E9),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Indicadores de Hoy',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // KPIs Grid/Flex Layout
                        if (isWide)
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Ventas Hoy',
                                  value: formatCurrency(_ventasHoy),
                                  icon: Icons.point_of_sale,
                                  color: const Color(0xFF0EA5E9),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Ganancia Hoy',
                                  value: formatCurrency(_gananciaHoy),
                                  icon: Icons.trending_up,
                                  color: const Color(0xFF22C55E),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Sin Stock',
                                  value: '$_productosSinStock',
                                  icon: Icons.warning_amber_rounded,
                                  color: _productosSinStock > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Deudas Pendientes',
                                  value: formatCurrency(_deudasPendientes),
                                  icon: Icons.money_off,
                                  color: _deudasPendientes > 0 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          )
                        else
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.4,
                            children: [
                              _buildKpiCard(
                                title: 'Ventas Hoy',
                                value: formatCurrency(_ventasHoy),
                                icon: Icons.point_of_sale,
                                color: const Color(0xFF0EA5E9),
                              ),
                              _buildKpiCard(
                                title: 'Ganancia Hoy',
                                value: formatCurrency(_gananciaHoy),
                                icon: Icons.trending_up,
                                color: const Color(0xFF22C55E),
                              ),
                              _buildKpiCard(
                                title: 'Sin Stock',
                                value: '$_productosSinStock',
                                icon: Icons.warning_amber_rounded,
                                color: _productosSinStock > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                              ),
                              _buildKpiCard(
                                title: 'Deuda Pendiente',
                                value: formatCurrency(_deudasPendientes),
                                icon: Icons.money_off,
                                color: _deudasPendientes > 0 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Últimas Ventas',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRecentSalesList(),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final innerBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_ultimasVentas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'No hay ventas registradas',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ultimasVentas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final sale = _ultimasVentas[index];
        final id = sale['id'];
        final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
        final rawFecha = sale['fecha'] as String?;
        final clientName = sale['clienteNombre'] as String? ?? 'Consumidor Final';
        final user = sale['usuarioNombre'] as String? ?? '';
        final method = sale['metodoPago'] as String? ?? '';

        String formattedDate = '';
        if (rawFecha != null) {
          try {
            final parsed = DateTime.parse(rawFecha);
            formattedDate = DateFormat('dd/MM HH:mm').format(parsed);
          } catch (_) {
            formattedDate = rawFecha;
          }
        }

        // Method payment label styling
        Color methodColor = const Color(0xFF64748B);
        if (method == 'Efectivo') methodColor = const Color(0xFF22C55E);
        if (method == 'Fiado') methodColor = const Color(0xFFEF4444);
        if (method == 'Debito' || method == 'Credito' || method == 'Transferencia') methodColor = const Color(0xFF0EA5E9);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: innerBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_outlined, color: Color(0xFF0EA5E9), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venta #$id',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$clientName • $formattedDate',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (user.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Vendido por: $user',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(total),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      method,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: methodColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
