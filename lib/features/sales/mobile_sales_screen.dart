import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';
import 'mobile_new_sale_screen.dart';

class MobileSalesScreen extends StatefulWidget {
  const MobileSalesScreen({super.key});

  @override
  State<MobileSalesScreen> createState() => _MobileSalesScreenState();
}

class _MobileSalesScreenState extends State<MobileSalesScreen> {
  final DBService _dbService = DBService();
  late StreamSubscription _dbSub;

  List<Map<String, dynamic>> _ventas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVentas();
    _dbSub = _dbService.onDatabaseChanged.listen((_) => _loadVentas());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _loadVentas() async {
    try {
      final list = await _dbService.getVentas();
      if (mounted) {
        setState(() {
          _ventas = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _navigateToNewSale() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MobileNewSaleScreen()),
    );
    if (result == true) {
      _loadVentas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Ventas',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 20, color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _loadVentas,
              color: const Color(0xFF0EA5E9),
              child: _ventas.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        if (isWide) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 3.2,
                            ),
                            itemCount: _ventas.length,
                            itemBuilder: (context, idx) => _buildSaleCard(_ventas[idx]),
                          );
                        } else {
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _ventas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) => _buildSaleCard(_ventas[idx]),
                          );
                        }
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: Text('Nueva Venta', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        onPressed: _navigateToNewSale,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          Text(
            'No hay ventas registradas',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las ventas que realices aparecerán aquí.',
            style: GoogleFonts.manrope(color: const Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final id = sale['id'];
    final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
    final rawFecha = sale['fecha'] as String?;
    final clientName = sale['clienteNombre'] as String? ?? 'Consumidor Final';
    final user = sale['usuarioNombre'] as String? ?? '';
    final method = sale['metodoPago'] as String? ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final innerBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String formattedDate = '';
    if (rawFecha != null) {
      try {
        final parsed = DateTime.parse(rawFecha);
        formattedDate = DateFormat('dd/MM HH:mm').format(parsed);
      } catch (_) {
        formattedDate = rawFecha;
      }
    }

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                    fontSize: 11,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Por: $user',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
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
                  color: methodColor.withOpacity(0.1),
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
  }
}
