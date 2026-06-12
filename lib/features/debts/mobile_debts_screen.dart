import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/artic_dialog.dart';

class MobileDebtsScreen extends StatefulWidget {
  const MobileDebtsScreen({super.key});

  @override
  State<MobileDebtsScreen> createState() => _MobileDebtsScreenState();
}

class _MobileDebtsScreenState extends State<MobileDebtsScreen> {
  final DBService _dbService = DBService();
  late StreamSubscription _dbSub;

  List<Map<String, dynamic>> _deudas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeudas();
    _dbSub = _dbService.onDatabaseChanged.listen((_) => _loadDeudas());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _loadDeudas() async {
    try {
      final list = await _dbService.getDeudas();
      // Filter for 'Pendiente'
      final pending = list.where((d) => d['estado'] == 'Pendiente').toList();
      if (mounted) {
        setState(() {
          _deudas = pending;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _registrarPago(int id, double monto, String clienteNombre) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showArticDialog<bool>(
      context: context,
      builder: (c) => ArticDialogCard(
        title: 'Registrar Pago',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar', style: GoogleFonts.manrope(color: isDark ? Colors.white60 : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text('Confirmar', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          ),
        ],
        child: Text(
          '¿Confirmas que deseas registrar el pago de ${formatCurrency(monto)} del cliente $clienteNombre?',
          style: GoogleFonts.manrope(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _dbService.markDeudaAsPagada(id, monto);
        _showSnackbar('✅ Pago registrado correctamente');
        _loadDeudas();
      } catch (e) {
        setState(() => _loading = false);
        _showSnackbar('❌ Error al registrar pago: $e');
      }
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Deudas Pendientes',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18, color: textColor),
        ),
        backgroundColor: appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _loadDeudas,
              color: const Color(0xFF0EA5E9),
              child: _deudas.isEmpty
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
                            itemCount: _deudas.length,
                            itemBuilder: (context, idx) => _buildDebtCard(_deudas[idx]),
                          );
                        } else {
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _deudas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) => _buildDebtCard(_deudas[idx]),
                          );
                        }
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF475569);
    final descColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 60, color: Color(0xFF22C55E)),
            const SizedBox(height: 16),
            Text(
              'Al día con todas las deudas',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No hay deudas pendientes registradas en el sistema.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: descColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtCard(Map<String, dynamic> debt) {
    final id = debt['id'] as int;
    final monto = (debt['monto'] as num?)?.toDouble() ?? 0.0;
    final fecha = debt['fecha'] as String? ?? '';
    final desc = debt['descripcion'] as String? ?? '';
    final clienteNombre = debt['clienteNombre'] as String? ?? 'Cliente';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final descColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);

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
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.money_off, color: Color(0xFFEF4444), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  clienteNombre,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Deuda #$id • ${fecha.split('T').first}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: descColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                formatCurrency(monto),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _registrarPago(id, monto, clienteNombre),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pagar',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF22C55E),
                    ),
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
