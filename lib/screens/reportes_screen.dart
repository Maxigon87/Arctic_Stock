import 'package:artic_stock/widgets/artic_background.dart';
import 'package:artic_stock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fl_chart/fl_chart.dart';
import '../services/db_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../services/file_helper.dart';
import '../utils/file_namer.dart';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final dbService = DBService();

  DateTime? _mesSeleccionado; // cualquier día del mes elegido
  DateTime? desde;
  DateTime? hasta;

  @override
  void initState() {
    super.initState();
    // Por defecto: mes actual
    final hoy = DateTime.now();
    _setMes(hoy);
  }

  // ---- Helpers ----
  String formateaFechaHora(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  String _fmt(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  DateTimeRange _rangeMensual(DateTime referencia) {
    final inicio = DateTime(referencia.year, referencia.month, 1);
    final fin = DateTime(referencia.year, referencia.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: inicio, end: fin);
  }

  void _setMes(DateTime fechaReferencia) {
    final r = _rangeMensual(fechaReferencia);
    setState(() {
      _mesSeleccionado = fechaReferencia;
      desde = r.start;
      hasta = r.end;
    });
  }

  Future<void> _elegirMes() async {
    // Usamos showDatePicker para elegir cualquier día, y normalizamos al mes
    final pick = await showDatePicker(
      context: context,
      initialDate: _mesSeleccionado ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      helpText: 'Elegí un día del mes',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (pick != null) _setMes(pick);
  }

  // ---- UI filtros (solo mes) ----
  Widget _buildFiltroMes() {
    final base = _mesSeleccionado ?? DateTime.now();
    final mes = DateFormat.MMMM('es_ES').format(base);
    final anio = base.year;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Mes seleccionado: ${toBeginningOfSentenceCase(mes)} $anio',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _elegirMes,
          child: const Text('Elegir mes'),
        ),
      ],
    );
  }

  // ---- PDF (formato "dividido por compra") ----
  Future<void> _generarReporteFiltrado(BuildContext context) async {
    // Solo fechas (mensual). Pasamos null al resto por compatibilidad.
    final ventas = await dbService.getVentasFiltradasParaReporte(
      clienteId: null,
      metodoPago: null,
      desde: desde,
      hasta: hasta,
    );

    // Juntar items por venta
    final List<_VentaConItems> data = [];
    for (final v in ventas) {
      final items = await dbService.getItemsByVenta(v['id'] as int);
      data.add(_VentaConItems(venta: v, items: items));
    }

    // Orden por fecha ascendente (cambia a fb.compareTo(fa) si querés descendente)
    data.sort((a, b) {
      final fa = DateTime.parse(a.venta['fecha'] as String);
      final fb = DateTime.parse(b.venta['fecha'] as String);
      return fa.compareTo(fb);
    });

    // Título mensual real usando 'desde' (ya normalizado)
    final DateTime baseDate = (desde ??
        (data.isNotEmpty
            ? DateTime.parse(data.first.venta['fecha'] as String)
            : DateTime.now()));
    final String monthName = DateFormat.MMMM('es_ES').format(baseDate);
    final int year = baseDate.year;

    // Período visible
    String? rangoVisible;
    if (desde != null && hasta != null) {
      final f = DateFormat('dd/MM/yyyy');
      rangoVisible = 'Período: ${f.format(desde!)} – ${f.format(hasta!)}';
    }

    final logoBytes = await rootBundle.load('assets/logo/logo_con_titulo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final numberFmt = NumberFormat.decimalPattern('es_AR');
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        build: (context) {
          final widgets = <pw.Widget>[];

          widgets.add(
            pw.Center(child: pw.Image(logo, width: 80)),
          );
          widgets.add(pw.SizedBox(height: 8));

          // Título
          widgets.add(
            pw.Text(
              'Reporte mensual de ventas - $monthName $year',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          );

          if (rangoVisible != null) {
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.Text(
                rangoVisible,
                style: const pw.TextStyle(fontSize: 11),
              ),
            );
          }

          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Divider(color: PdfColors.blue, thickness: 2));
          widgets.add(pw.SizedBox(height: 16));

          if (data.isEmpty) {
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.6, color: PdfColors.blue),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'No hay ventas para el período seleccionado.',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            );
            return widgets;
          }

          // Compras
          for (int i = 0; i < data.length; i++) {
            final venta = data[i].venta;
            final items = data[i].items;
            final fecha = DateTime.parse(venta['fecha'] as String);

            final totalUnidades = items.fold<int>(
              0,
              (acc, it) => acc + ((it['cantidad'] as num?)?.toInt() ?? 0),
            );
            final precioTotal = items.fold<double>(
              0.0,
              (acc, it) {
                final cant = (it['cantidad'] as num?)?.toInt() ?? 0;
                final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
                final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);
                return acc + sub;
              },
            );

            // Cabecera compra
            widgets.add(
              pw.Container(
                margin: pw.EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 6),
                child: pw.Text(
                  'Compra ${i + 1}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );

            // Lista de productos: "Producto — Descripción" ... precio y "xCant"
            widgets.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: items.map((it) {
                  final prod =
                      (it['producto'] ?? it['nombre'] ?? '').toString();
                  final desc = (it['descripcion'] ?? '').toString();

                  final cant = (it['cantidad'] as num?)?.toInt() ?? 0;
                  final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: desc.isEmpty
                              ? pw.Text(prod,
                                  style: const pw.TextStyle(fontSize: 12))
                              : pw.RichText(
                                  text: pw.TextSpan(children: [
                                    pw.TextSpan(
                                        text: '$prod — ',
                                        style:
                                            const pw.TextStyle(fontSize: 12)),
                                    pw.TextSpan(
                                        text: desc,
                                        style: pw.TextStyle(
                                            fontSize: 12,
                                            fontStyle: pw.FontStyle.italic)),
                                  ]),
                                ),
                        ),
                        pw.Text(
                          formatCurrency(pu),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text('x${numberFmt.format(cant)}',
                            style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );

            // Metadatos abajo
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.6, color: PdfColors.blue),
                  ),
                ),
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Método de pago: ${venta['metodoPago'] ?? '-'}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Fecha y hora: ${formateaFechaHora(fecha)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Cantidad de productos: ${numberFmt.format(totalUnidades)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Total de la compra: ${formatCurrency(precioTotal)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            );

            // Separador entre compras
            if (i < data.length - 1) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Divider(thickness: 0.5, color: PdfColors.blue),
              );
            }
          }

          return widgets;
        },
      ),
    );

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reportePdf()}')
      ..createSync(recursive: true);
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ PDF guardado: ${file.path}")),
    );
    await Share.shareXFiles([XFile(file.path)], text: "📄 Reporte Mensual");
  }

  CellValue? _toCell(dynamic val) {
    if (val == null) return null;
    if (val is int) return IntCellValue(val);
    if (val is double) return DoubleCellValue(val);
    if (val is bool) return BoolCellValue(val);
    return TextCellValue(val.toString());
  }

  // ---- Excel mensual (mismas fechas, sin otros filtros) ----
  Future<void> _exportarExcelMensual(BuildContext context) async {
    final ventas = await dbService.getVentasFiltradasParaReporte(
      clienteId: null,
      metodoPago: null,
      desde: desde,
      hasta: hasta,
    );

    final excel = Excel.createExcel();
    final shVentas = excel['Ventas'];
    final shItems = excel['Items'];
    excel.setDefaultSheet('Ventas');

    // Encabezados
    shVentas.appendRow([
      'ID',
      'Cliente',
      'Método',
      'Fecha',
      'Ingreso',
      'Costo',
      'Ganancia',
      'Total Unidades'
    ].map(_toCell).toList());
    shItems.appendRow([
      'VentaID',
      'Código',
      'Producto',
      'Descripción',
      'Cant.',
      'Precio Unit.',
      'Costo Unit.',
      'Subtotal',
      'Ganancia'
    ].map(_toCell).toList());

    double totalIngresoGlobal = 0,
        totalCostoGlobal = 0,
        totalGananciaGlobal = 0;

    for (final v in ventas) {
      final items = await dbService.getItemsByVenta(v['id'] as int);

      double ingresoVenta = 0, costoVenta = 0, gananciaVenta = 0;
      int totalUnidades = 0;

      for (final it in items) {
        final cant = (it['cantidad'] as num?)?.toInt() ?? 0;
        final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
        final cu = (it['costoUnitario'] as num?)?.toDouble() ?? 0.0;
        final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);
        final gan = (pu - cu) * cant;

        ingresoVenta += sub;
        costoVenta += cu * cant;
        gananciaVenta += gan;
        totalUnidades += cant;

        shItems.appendRow([
          v['id'],
          it['codigo']?.toString() ?? '',
          it['producto']?.toString() ?? it['nombre']?.toString() ?? '',
          it['descripcion']?.toString() ?? '',
          cant,
          pu,
          cu,
          sub,
          gan,
        ].map(_toCell).toList());
      }

      totalIngresoGlobal += ingresoVenta;
      totalCostoGlobal += costoVenta;
      totalGananciaGlobal += gananciaVenta;

      shVentas.appendRow([
        v['id'],
        v['clienteNombre'] ?? 'Consumidor Final',
        v['metodoPago'],
        v['fecha'],
        ingresoVenta,
        costoVenta,
        gananciaVenta,
        totalUnidades,
      ].map(_toCell).toList());
    }

    // Totales globales al pie de Ventas
    shVentas.appendRow(<CellValue?>[]);
    shVentas.appendRow([
      '',
      '',
      '',
      'TOTALES',
      totalIngresoGlobal,
      totalCostoGlobal,
      totalGananciaGlobal,
      '', // total unidades globales opcional: podés sumar si querés
    ].map(_toCell).toList());

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reporteExcel()}')
      ..createSync(recursive: true);

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Excel guardado: ${file.path}")),
    );
    await Share.shareXFiles([XFile(file.path)], text: "📊 Reporte Mensual");
  }

  // ---- PDF con listado de productos por categoría ----
  Future<void> _generarReporteProductos(BuildContext context) async {
    final productos = await dbService.getProductos(incluirInactivos: true);

    // Agrupar por categoría
    final Map<String, List<Map<String, dynamic>>> porCat = {};
    for (final p in productos) {
      final cat = (p['categoria_nombre'] ?? 'Sin categoría').toString();
      porCat.putIfAbsent(cat, () => []).add(p);
    }

    final categorias = porCat.keys.toList()..sort();

    final numberFmt = NumberFormat.decimalPattern('es_AR');
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'Reporte de Productos',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
          ];

          for (final cat in categorias) {
            final prods = porCat[cat]!;
            prods.sort((a, b) => (a['nombre'] ?? '')
                .toString()
                .compareTo((b['nombre'] ?? '').toString()));

            widgets.add(pw.Text(cat,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 6));

            widgets.add(pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: prods.map((p) {
                final nombre = (p['nombre'] ?? '').toString();
                final stock = (p['stock'] as num?)?.toInt() ?? 0;
                final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(nombre,
                            style: const pw.TextStyle(fontSize: 12)),
                      ),
                      pw.Text('Stock: ${numberFmt.format(stock)}',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        formatCurrency(precio),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ));
            widgets.add(pw.SizedBox(height: 12));
          }

          return widgets;
        },
      ),
    );

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reporteProductosPdf()}')
      ..createSync(recursive: true);
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ PDF guardado: ${file.path}")),
    );
    await Share.shareXFiles([XFile(file.path)],
        text: "📄 Reporte de Productos");
  }

  // ---- PDF con listado de ingresos de stock ----
  Future<void> _generarReporteIngresos(BuildContext context) async {
    final ingresos =
        await dbService.getIngresosStock(desde: desde, hasta: hasta);

    final logoBytes = await rootBundle.load('assets/logo/logo_con_titulo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    DateTime baseDate = (desde ??
        (ingresos.isNotEmpty
            ? DateTime.parse(ingresos.first['fecha'] as String)
            : DateTime.now()));
    final String monthName = DateFormat.MMMM('es_ES').format(baseDate);
    final int year = baseDate.year;

    String? rangoVisible;
    if (desde != null && hasta != null) {
      final f = DateFormat('dd/MM/yyyy');
      rangoVisible = 'Período: ${f.format(desde!)} – ${f.format(hasta!)}';
    }

    final numberFmt = NumberFormat.decimalPattern('es_AR');
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        build: (context) {
          final widgets = <pw.Widget>[];

          widgets.add(pw.Center(child: pw.Image(logo, width: 80)));
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(
            pw.Text(
              'Reporte de ingresos de stock - $monthName $year',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          );

          if (rangoVisible != null) {
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
                pw.Text(rangoVisible, style: const pw.TextStyle(fontSize: 11)));
          }

          widgets.add(pw.SizedBox(height: 16));

          if (ingresos.isEmpty) {
            widgets.add(pw.Text('No hay ingresos en este período.',
                style: const pw.TextStyle(fontSize: 12)));
            return widgets;
          }

          final headers = ['Fecha', 'Producto', 'Cant.', 'Tipo', 'Nota'];
          final data = ingresos.map((r) {
            final fecha = DateTime.tryParse((r['fecha'] ?? '').toString());
            final fechaStr = fecha != null ? _fmt(fecha) : '-';
            final producto = (r['producto'] ?? '').toString();
            final cant =
                numberFmt.format((r['cantidad'] as num?)?.toInt() ?? 0);
            final tipo = (r['tipo'] ?? '').toString();
            final nota = (r['nota'] ?? '').toString();
            return [fechaStr, producto, cant, tipo, nota];
          }).toList();

          widgets.add(
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
              },
            ),
          );

          return widgets;
        },
      ),
    );

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reporteIngresosPdf()}')
      ..createSync(recursive: true);
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ PDF guardado: ${file.path}")),
    );
    await Share.shareXFiles([XFile(file.path)], text: "📄 Reporte de Ingresos");
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required List<Widget> actions,
    required List<FlSpot> sparklineData,
    required Color accentColor,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 5,
                  minY: 0,
                  maxY: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: sparklineData,
                      isCurved: true,
                      color: accentColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: accentColor.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required bool isDark,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      icon: Icon(icon, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      onPressed: onPressed,
    );
  }

  Widget _buildTimeSelector(bool isDark) {
    final activeColor = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: activeColor),
            const SizedBox(width: 8),
            Text(
              "Rango del Reporte:",
              style: textStyle,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                desde != null && hasta != null
                    ? "${DateFormat('dd/MM/yyyy').format(desde!)} – ${DateFormat('dd/MM/yyyy').format(hasta!)}"
                    : "Selecciona un rango",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTimeOption("Este Mes", () {
                final hoy = DateTime.now();
                _setMes(hoy);
              }, isDark),
              const SizedBox(width: 8),
              _buildTimeOption("Último Trimestre", () {
                final hoy = DateTime.now();
                final tresMesesAtras = DateTime(hoy.year, hoy.month - 3, 1);
                setState(() {
                  _mesSeleccionado = hoy;
                  desde = tresMesesAtras;
                  hasta = DateTime(hoy.year, hoy.month + 1, 0, 23, 59, 59);
                });
              }, isDark),
              const SizedBox(width: 8),
              _buildTimeOption("Año Actual", () {
                final hoy = DateTime.now();
                setState(() {
                  _mesSeleccionado = hoy;
                  desde = DateTime(hoy.year, 1, 1);
                  hasta = DateTime(hoy.year, 12, 31, 23, 59, 59);
                });
              }, isDark),
              const SizedBox(width: 8),
              _buildTimeOption("Personalizado 🗓️", () async {
                final pick = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2022),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark
                            ? const ColorScheme.dark(
                                primary: Color(0xFF22D3EE),
                                onPrimary: Color(0xFF0F172A),
                                surface: Color(0xFF1E293B),
                                onSurface: Colors.white,
                              )
                            : const ColorScheme.light(
                                primary: Color(0xFF0284C7),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Color(0xFF0F172A),
                              ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (pick != null) {
                  setState(() {
                    desde = pick.start;
                    hasta = pick.end;
                  });
                }
              }, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeOption(String label, VoidCallback onTap, bool isDark) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reportes y Exportaciones",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ArticContainer(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeSelector(isDark),
                    const SizedBox(height: 20),
                    // Grid of cards
                    SizedBox(
                      height: 225,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildReportCard(
                              title: "Reporte de Ventas",
                              description: "Historial completo de ventas, ingresos, costos y ganancias del período.",
                              icon: Icons.receipt_long,
                              accentColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                              sparklineData: [
                                FlSpot(0, 2),
                                FlSpot(1, 4),
                                FlSpot(2, 3),
                                FlSpot(3, 5),
                                FlSpot(4, 4),
                                FlSpot(5, 6),
                              ],
                              actions: [
                                _buildActionButton(
                                  label: "PDF",
                                  icon: Icons.picture_as_pdf,
                                  onPressed: () => _generarReporteFiltrado(context),
                                  color: Colors.redAccent,
                                  isDark: isDark,
                                ),
                                _buildActionButton(
                                  label: "Excel",
                                  icon: Icons.table_chart,
                                  onPressed: () => _exportarExcelMensual(context),
                                  color: Colors.green,
                                  isDark: isDark,
                                ),
                              ],
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildReportCard(
                              title: "Reporte de Stock",
                              description: "Listado agrupado por categorías de productos con sus cantidades y precios.",
                              icon: Icons.inventory_2_outlined,
                              accentColor: Colors.orangeAccent,
                              sparklineData: [
                                FlSpot(0, 3),
                                FlSpot(1, 2),
                                FlSpot(2, 4),
                                FlSpot(3, 3),
                                FlSpot(4, 5),
                                FlSpot(5, 4),
                              ],
                              actions: [
                                _buildActionButton(
                                  label: "PDF",
                                  icon: Icons.picture_as_pdf,
                                  onPressed: () => _generarReporteProductos(context),
                                  color: Colors.redAccent,
                                  isDark: isDark,
                                ),
                              ],
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildReportCard(
                              title: "Reporte de Ingresos",
                              description: "Historial de adición de mercadería y movimientos internos en stock.",
                              icon: Icons.add_business_outlined,
                              accentColor: Colors.purpleAccent,
                              sparklineData: [
                                FlSpot(0, 1),
                                FlSpot(1, 3),
                                FlSpot(2, 2),
                                FlSpot(3, 4),
                                FlSpot(4, 3),
                                FlSpot(5, 5),
                              ],
                              actions: [
                                _buildActionButton(
                                  label: "PDF",
                                  icon: Icons.picture_as_pdf,
                                  onPressed: () => _generarReporteIngresos(context),
                                  color: Colors.redAccent,
                                  isDark: isDark,
                                ),
                              ],
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ingresos de stock recientes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: dbService.getIngresosStock(desde: desde, hasta: hasta),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return Center(child: Text('Error: ${snap.error}'));
                          }
                          final ingresos = snap.data ?? const [];
                          if (ingresos.isEmpty) {
                            return Center(
                              child: Text(
                                'No hay ingresos registrados en este período',
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            );
                          }
                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: ingresos.length,
                            itemBuilder: (_, i) {
                              final r = ingresos[i];
                              final nombre = (r['producto'] ?? '').toString();
                              final cant = (r['cantidad'] as num?)?.toInt() ?? 0;
                              final fecha = DateTime.tryParse((r['fecha'] ?? '').toString());

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: isDark
                                    ? Colors.white.withOpacity(0.02)
                                    : Colors.white.withOpacity(0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.add_shopping_cart, color: Colors.green, size: 18),
                                  ),
                                  title: Text(
                                    '$nombre (+$cant)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    fecha != null ? _fmt(fecha) : '-',
                                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modelo interno
class _VentaConItems {
  final Map<String, dynamic> venta;
  final List<Map<String, dynamic>> items;
  _VentaConItems({required this.venta, required this.items});
}
