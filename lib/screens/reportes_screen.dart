import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/db_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../Services/file_helper.dart';
import '../utils/file_namer.dart';
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

    final logoBytes =
        await rootBundle.load('assets/logo/logo_con_titulo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

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
                  border:
                      pw.Border.all(width: 0.6, color: PdfColors.blue),
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
                final cant = (it['cantidad'] as num?)?.toDouble() ?? 0.0;
                final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
                final sub =
                    (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);
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
                  final cant = (it['cantidad'] ?? '').toString();
                  final pu =
                      (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            desc.isEmpty ? prod : '$prod — $desc',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ),
                        pw.Text('\$${pu.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 12)),
                        pw.SizedBox(width: 4),
                        pw.Text('x$cant',
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
                      'Cantidad de productos: $totalUnidades',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Total de la compra: \$${precioTotal.toStringAsFixed(2)}',
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
    ]);
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
    ]);

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
        ]);
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
      ]);
    }

    // Totales globales al pie de Ventas
    shVentas.appendRow([]);
    shVentas.appendRow([
      '',
      '',
      '',
      'TOTALES',
      totalIngresoGlobal,
      totalCostoGlobal,
      totalGananciaGlobal,
      '', // total unidades globales opcional: podés sumar si querés
    ]);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reportes Mensuales")),
      body: ArticBackground(
        child: ArticContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFiltroMes(),
              const SizedBox(height: 20),

              // Botones existentes
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Generar PDF"),
                onPressed: () => _generarReporteFiltrado(context),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.table_chart),
                label: const Text("Exportar Excel"),
                onPressed: () => _exportarExcelMensual(context),
              ),

              const SizedBox(height: 24),
              Text(
                'Ingresos de stock',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              // ====== LISTA SIMPLE DE INGRESOS ======
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future:
                      dbService.getIngresosStock(desde: desde, hasta: hasta),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final ingresos = snap.data ?? const [];
                    if (ingresos.isEmpty) {
                      return const Center(
                          child: Text('No hay ingresos en este período'));
                    }
                    return ListView.builder(
                      itemCount: ingresos.length,
                      itemBuilder: (_, i) {
                        final r = ingresos[i];
                        final nombre = (r['producto'] ?? '').toString();
                        final cant = (r['cantidad'] as num?)?.toInt() ?? 0;
                        final fecha =
                            DateTime.tryParse((r['fecha'] ?? '').toString());

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.add_shopping_cart),
                            title: Text('$nombre (+$cant)'),
                            subtitle: Text(
                              fecha != null ? _fmt(fecha) : '-',
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
    );
  }
}

// Modelo interno
class _VentaConItems {
  final Map<String, dynamic> venta;
  final List<Map<String, dynamic>> items;
  _VentaConItems({required this.venta, required this.items});
}
