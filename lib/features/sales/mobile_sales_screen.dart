import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';
import 'mobile_new_sale_screen.dart';

class MobileSalesScreen extends StatefulWidget {
  final Map<String, dynamic>? initialSelectedSale;
  final VoidCallback? onDetailShown;

  const MobileSalesScreen({
    super.key,
    this.initialSelectedSale,
    this.onDetailShown,
  });

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
    _loadVentas().then((_) {
      _checkInitialSelectedSale();
    });
    _dbSub = _dbService.onDatabaseChanged.listen((_) => _loadVentas());
  }

  @override
  void didUpdateWidget(covariant MobileSalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedSale != null &&
        widget.initialSelectedSale != oldWidget.initialSelectedSale) {
      _checkInitialSelectedSale();
    }
  }

  void _checkInitialSelectedSale() {
    if (widget.initialSelectedSale != null) {
      final saleId = widget.initialSelectedSale!['id'];
      final sale = _ventas.firstWhere((v) => v['id'] == saleId, orElse: () => widget.initialSelectedSale!);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSaleDetails(sale);
        if (widget.onDetailShown != null) {
          widget.onDetailShown!();
        }
      });
    }
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

  Future<void> _shareSaleTicket(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    try {
      final bytes = await _generarPdfComprobante(sale, items);
      
      // Save it to cache/temporary folder to share it
      final tempDir = await getTemporaryDirectory();
      final ventaId = sale['id'] as int? ?? 0;
      final cliente = sale['clienteNombre']?.toString() ?? 'Consumidor Final';
      
      // Sanitize file name
      final sanitizedClient = cliente.replaceAll(RegExp(r'[^\w\s-]'), '');
      final file = File('${tempDir.path}/factura_${ventaId}_$sanitizedClient.pdf');
      await file.writeAsBytes(bytes, flush: true);
      
      await Share.shareXFiles([XFile(file.path)], subject: 'Ticket de Venta #$ventaId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar y compartir ticket: $e')),
      );
    }
  }

  Future<Uint8List> _generarPdf58mm(
      Map<String, dynamic> header, List<Map<String, dynamic>> items, pw.MemoryImage logoImage) async {
    final pdf = pw.Document();
    const int lineWidth = 32;
    final font = pw.Font.courier();

    String _repeat(String char, int times) => List.filled(times, char).join();

    List<String> _wrap(String text) {
      final lines = <String>[];
      for (var i = 0; i < text.length; i += lineWidth) {
        final end = (i + lineWidth < text.length) ? i + lineWidth : text.length;
        lines.add(text.substring(i, end));
      }
      return lines;
    }

    void _addWrapped(List<String> target, String text) {
      target.addAll(_wrap(text));
    }

    void _addCentered(List<String> target, String text) {
      for (final line in _wrap(text)) {
        final pad = ((lineWidth - line.length) / 2).floor();
        final leftPad = pad > 0 ? pad : 0;
        target.add("${_repeat(' ', leftPad)}$line");
      }
    }

    final ventaId = header['id'] as int? ?? 0;
    final fechaRaw = header['fecha'] as String?;
    String fecha = '';
    if (fechaRaw != null) {
      try {
        final parsed = DateTime.parse(fechaRaw);
        fecha = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      } catch (_) {
        fecha = fechaRaw.split('T').first;
      }
    }
    final cliente = (header['clienteNombre']?.toString().isNotEmpty ?? false)
        ? header['clienteNombre']
        : 'Consumidor Final';
    final vendedor = (header['usuarioNombre']?.toString().isNotEmpty ?? false)
        ? header['usuarioNombre']
        : '—';
    final metodo = header['metodoPago'] ?? '—';
    final total = (header['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (header['subtotal'] as num?)?.toDouble() ?? total;
    final descuento = (header['descuento'] as num?)?.toDouble() ?? 0.0;

    final linesOut = <String>[];
    _addCentered(linesOut, 'Venta #$ventaId');
    _addCentered(linesOut, fecha);
    linesOut.add(_repeat('-', lineWidth));
    _addWrapped(linesOut, 'Cliente: $cliente');
    _addWrapped(linesOut, 'Vendedor: $vendedor');
    _addWrapped(linesOut, 'Método: $metodo');
    linesOut.add(_repeat('-', lineWidth));
    _addCentered(linesOut, 'PRODUCTOS');
    linesOut.add(_repeat('-', lineWidth));

    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final nombre = (it['producto'] ?? '').toString();
      final cant = (it['cantidad'] as num?)?.toInt() ?? 0;
      final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
      final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);

      _addWrapped(linesOut, nombre);
      linesOut.add('$cant x ${formatCurrency(pu)}');
      linesOut.add(formatCurrency(sub));
      
      if (i < items.length - 1) {
        linesOut.add('---');
      }
    }

    linesOut.add(_repeat('-', lineWidth));
    
    if (descuento > 0) {
      linesOut.add('SUBTOTAL');
      linesOut.add(formatCurrency(subtotal));
      linesOut.add('DESCUENTO');
      linesOut.add('-${formatCurrency(descuento)}');
      linesOut.add(_repeat('-', lineWidth));
    }

    final totalLines = <String>[];
    totalLines.add(_repeat('=', 17));
    totalLines.add('      TOTAL      ');
    final totalStr = formatCurrency(total);
    final pad = ((17 - totalStr.length) / 2).floor();
    final leftPad = pad > 0 ? pad : 0;
    totalLines.add("${_repeat(' ', leftPad)}$totalStr");
    totalLines.add(_repeat('=', 17));

    final finalMessageLines = <String>[];
    finalMessageLines.add('');
    _addCentered(finalMessageLines, '¡Gracias por su compra!');
    _addCentered(finalMessageLines, 'Arctic Stock');

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Center(child: pw.Image(logoImage, width: 40)),
            pw.SizedBox(height: 8),
            pw.Text(
              linesOut.join('\n'),
              style: pw.TextStyle(font: font, fontSize: 8.5, height: 1.1),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              totalLines.join('\n'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, height: 1.1),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              finalMessageLines.join('\n'),
              style: pw.TextStyle(font: font, fontSize: 8.5, height: 1.1),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _generarPdf80mm(
      Map<String, dynamic> header, List<Map<String, dynamic>> items, pw.MemoryImage logoImage) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final ventaId = header['id'] as int? ?? 0;
    final fechaRaw = header['fecha'] as String?;
    String fecha = '';
    if (fechaRaw != null) {
      try {
        final parsed = DateTime.parse(fechaRaw);
        fecha = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      } catch (_) {
        fecha = fechaRaw.split('T').first;
      }
    }
    final cliente = (header['clienteNombre']?.toString().isNotEmpty ?? false)
        ? header['clienteNombre']
        : 'Consumidor Final';
    final vendedor = (header['usuarioNombre']?.toString().isNotEmpty ?? false)
        ? header['usuarioNombre']
        : '—';
    final metodo = header['metodoPago'] ?? '—';
    final total = (header['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (header['subtotal'] as num?)?.toDouble() ?? total;
    final descuento = (header['descuento'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.all(6),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Image(logoImage, width: 50)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Arctic Stock',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 14),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Comprobante de Venta',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Venta #$ventaId', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                pw.Text(fecha, style: pw.TextStyle(font: font, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text('Cliente: $cliente', style: pw.TextStyle(font: font, fontSize: 9)),
            pw.Text('Vendedor: $vendedor', style: pw.TextStyle(font: font, fontSize: 9)),
            pw.Text('Método de Pago: $metodo', style: pw.TextStyle(font: font, fontSize: 9)),
            
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Text('PRODUCTOS', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 6),

            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                for (final it in items)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          (it['producto'] ?? '').toString(),
                          style: pw.TextStyle(font: font, fontSize: 8.5),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          '${it['cantidad']} x ${formatCurrency(it['precioUnitario'])}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: font, fontSize: 8.5),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          formatCurrency(it['subtotal'] ?? 0.0),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 6),

            if (descuento > 0) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text(formatCurrency(subtotal), style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Descuento:', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('-${formatCurrency(descuento)}', style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
            ],
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                pw.Text(formatCurrency(total), style: pw.TextStyle(font: fontBold, fontSize: 12)),
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              '¡Gracias por su compra!',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
            pw.Text(
              'Arctic Stock',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey500),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _generarPdfA4(
      Map<String, dynamic> header, List<Map<String, dynamic>> items, pw.MemoryImage logoImage) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final ventaId = header['id'] as int? ?? 0;
    final fechaRaw = header['fecha'] as String?;
    String fecha = '';
    if (fechaRaw != null) {
      try {
        final parsed = DateTime.parse(fechaRaw);
        fecha = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      } catch (_) {
        fecha = fechaRaw.split('T').first;
      }
    }
    final cliente = (header['clienteNombre']?.toString().isNotEmpty ?? false)
        ? header['clienteNombre']
        : 'Consumidor Final';
    final vendedor = (header['usuarioNombre']?.toString().isNotEmpty ?? false)
        ? header['usuarioNombre']
        : '—';
    final metodo = header['metodoPago'] ?? '—';
    final total = (header['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (header['subtotal'] as num?)?.toDouble() ?? total;
    final descuento = (header['descuento'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Image(logoImage, width: 48, height: 48),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ARCTIC STOCK',
                          style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColor.fromHex('#0284C7')),
                        ),
                        pw.Text(
                          'Sistema de Ventas y Control de Stock',
                          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#0284C7'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'COMPROBANTE',
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Venta Nº: #$ventaId',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.grey900),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 16),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DETALLES DEL CLIENTE',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        cliente,
                        style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.grey900),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Cliente Registrado',
                        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DETALLES DE LA TRANSACCIÓN',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Text('Fecha: ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(fecha, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Vendedor: ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(vendedor, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Método de Pago: ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#F0FDFA'),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              border: pw.Border.all(color: PdfColor.fromHex('#CCFBF1'), width: 1),
                            ),
                            child: pw.Text(
                              metodo,
                              style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#0F766E')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(3.5),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('CÓDIGO', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#475569'))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('DESCRIPCIÓN DEL PRODUCTO', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#475569'))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('CANTIDAD', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#475569'))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('P. UNITARIO', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#475569'))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#475569'))),
                    ),
                  ],
                ),
                for (final it in items)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((it['codigo'] ?? '—').toString(), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((it['producto'] ?? '').toString(), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey900)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(it['cantidad'].toString(), textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(formatCurrency(it['precioUnitario'] ?? 0.0), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(formatCurrency(it['subtotal'] ?? 0.0), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey900)),
                      ),
                    ],
                  ),
              ],
            ),

            pw.SizedBox(height: 16),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TÉRMINOS Y CONDICIONES',
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Este documento sirve como comprobante oficial de la transacción. Para cualquier reclamo o devolución, presente este comprobante.',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 40),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if (descuento > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(formatCurrency(subtotal), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Descuento:', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red500)),
                            pw.Text('-${formatCurrency(descuento)}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red500)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(thickness: 1, color: PdfColors.grey300),
                        pw.SizedBox(height: 6),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL NETO:', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey900)),
                          pw.Text(
                            formatCurrency(total),
                            style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColor.fromHex('#0284C7')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '¡Gracias por confiar en nosotros!',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Arctic Stock • www.arcticstock.com',
                  style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _generarPdfComprobante(
      Map<String, dynamic> header, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final tipoTicket = prefs.getString('tipo_ticket') ?? 'ticket_58mm';

    final logoData = await rootBundle.load('assets/logo/logo_sin_titulo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    if (tipoTicket == 'pdf_normal') {
      return _generarPdfA4(header, items, logoImage);
    } else if (tipoTicket == 'ticket_80mm') {
      return _generarPdf80mm(header, items, logoImage);
    } else {
      return _generarPdf58mm(header, items, logoImage);
    }
  }
}
