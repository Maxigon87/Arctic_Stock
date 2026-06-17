import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // 👈 NUEVO
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

    return GestureDetector(
      onTap: () => _showSaleDetails(sale),
      child: Container(
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
      ),
    );
  }

  Future<void> _showSaleDetails(Map<String, dynamic> sale) async {
    final id = sale['id'] as int;
    final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
    final method = sale['metodoPago'] as String? ?? '—';
    final clientName = sale['clienteNombre'] as String? ?? 'Consumidor Final';
    final rawFecha = sale['fecha'] as String?;
    String formattedDate = '';
    if (rawFecha != null) {
      try {
        final parsed = DateTime.parse(rawFecha);
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      } catch (_) {
        formattedDate = rawFecha;
      }
    }

    final items = await _dbService.getItemsByVenta(id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomSheetDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = bottomSheetDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final cardColor = bottomSheetDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = bottomSheetDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
        final textC = bottomSheetDark ? Colors.white : const Color(0xFF0F172A);
        final subC = bottomSheetDark ? Colors.white70 : const Color(0xFF64748B);

        Color methodColor = const Color(0xFF0EA5E9);
        if (method.toLowerCase().contains('efectivo')) {
          methodColor = const Color(0xFF22C55E);
        } else if (method.toLowerCase().contains('tarjeta') || method.toLowerCase().contains('débito') || method.toLowerCase().contains('crédito')) {
          methodColor = const Color(0xFFF59E0B);
        }

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bottomSheetDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Comprobante de Venta',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textC,
                ),
              ),
              const SizedBox(height: 20),

              // KPI Metric Cards Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Cobrado",
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: subC,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatCurrency(total),
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Método de Pago",
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: subC,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: methodColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: methodColor.withOpacity(0.25), width: 1),
                            ),
                            child: Text(
                              method,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: methodColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Transaction Metadata Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Resumen de Transacción",
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textC,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Número de Venta', '#$id', subC),
                    Divider(height: 20, color: borderColor),
                    _buildDetailRow('Cliente', clientName, subC),
                    Divider(height: 20, color: borderColor),
                    _buildDetailRow('Fecha y Hora', formattedDate, subC),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Products Section Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de Productos',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textC,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
                        itemBuilder: (c, idx) {
                          final item = items[idx];
                          final name = item['producto'] ?? '';
                          final cant = item['cantidad'] ?? 0;
                          final sub = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$cant x $name',
                                  style: GoogleFonts.manrope(fontSize: 13, color: subC),
                                ),
                              ),
                              Text(
                                formatCurrency(sub),
                                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: textC),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share_outlined),
                label: Text('Compartir Ticket', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                onPressed: () {
                  _shareSaleTicket(sale, items);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey)),
        Text(value, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  void _shareSaleTicket(Map<String, dynamic> sale, List<Map<String, dynamic>> items) {
    final id = sale['id'];
    final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
    final clientName = sale['clienteNombre'] as String? ?? 'Consumidor Final';
    final method = sale['metodoPago'] as String? ?? '—';
    final rawFecha = sale['fecha'] as String?;
    String formattedDate = '';
    if (rawFecha != null) {
      try {
        final parsed = DateTime.parse(rawFecha);
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      } catch (_) {}
    }

    final buffer = StringBuffer();
    buffer.writeln('❄️ Arctic Stock ❄️');
    buffer.writeln('=================================');
    buffer.writeln('Ticket de Venta #$id');
    buffer.writeln('Fecha: $formattedDate');
    buffer.writeln('Cliente: $clientName');
    buffer.writeln('Metodo: $method');
    buffer.writeln('=================================');
    buffer.writeln('Productos:');
    for (var item in items) {
      final name = item['producto'] ?? '';
      final cant = item['cantidad'] ?? 0;
      final sub = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
      buffer.writeln('- $cant x $name: ${formatCurrency(sub)}');
    }
    buffer.writeln('=================================');
    buffer.writeln('TOTAL: ${formatCurrency(total)}');
    buffer.writeln('=================================');
    buffer.writeln('¡Gracias por su compra!');

    Share.share(buffer.toString(), subject: 'Ticket de Venta #$id');
  }
}
