import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // <-- para cargar logo
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/db_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../Services/file_helper.dart';
import '../utils/file_namer.dart';
import '../models/cliente.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({Key? key}) : super(key: key);

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  Cliente? _clienteSeleccionado;
  String? metodoSeleccionado;
  String? estadoSeleccionado;
  DateTime? desde;
  DateTime? hasta;
  List<Cliente> _clientes = [];
  final dbService = DBService();

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    final clientes = await dbService.getClientes();
    setState(() => _clientes = clientes);
  }

  String _money(num? n) => "\$${(n ?? 0).toStringAsFixed(2)}";

  /// ✅ Filtros en UI
  Widget _buildFiltrosReportes() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<Cliente>(
                hint: const Text("Cliente"),
                value: _clienteSeleccionado,
                items: _clientes
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _clienteSeleccionado = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                hint: const Text("Método Pago"),
                value: metodoSeleccionado,
                items: const ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => metodoSeleccionado = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                hint: const Text("Estado Deuda"),
                value: estadoSeleccionado,
                items: const ["Pendiente", "Pagada"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => estadoSeleccionado = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final rango = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                  );
                  if (rango != null) {
                    setState(() {
                      desde = rango.start;
                      hasta = rango.end;
                    });
                  }
                },
                child: const Text("Elegir Fechas"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ Generar PDF con datos filtrados (incluye ganancia e ítems con snapshot)
  Future<void> _generarReporteFiltrado(BuildContext context) async {
    // 1) Traer ventas según filtros
    final ventas = await dbService.getVentasFiltradasParaReporte(
      clienteId: _clienteSeleccionado?.id,
      metodoPago: metodoSeleccionado,
      desde: desde,
      hasta: hasta,
    );

    // 2) Pre-cargar detalles de cada venta (no usar async dentro del build del PDF)
    final List<_VentaConItems> data = [];
    for (final v in ventas) {
      final items = await dbService.getItemsByVenta(v['id'] as int);
      data.add(_VentaConItems(venta: v, items: items));
    }

    // 3) Cargar logo desde assets de forma correcta
    final logoBytes = await rootBundle.load('assets/images/artic_logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // 4) Construir PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final widgets = <pw.Widget>[];

          // Encabezado
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Artic Stock',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Reporte de Ventas',
                        style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      'Generado: ${DateTime.now().toString().substring(0, 16)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Image(logoImage, width: 80, height: 80),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 16));

          // Totales generales
          double totalIngresoGlobal = 0,
              totalCostoGlobal = 0,
              totalGananciaGlobal = 0;

          for (final bloque in data) {
            final venta = bloque.venta;
            final items = bloque.items;

            // Calcular totales por venta desde los items (snapshot)
            double ingresoVenta = 0, costoVenta = 0, gananciaVenta = 0;

            final rows = <List<String>>[];
            rows.add([
              'Código',
              'Producto',
              'Cant.',
              'Precio',
              'Costo',
              'Subtotal',
              'Ganancia'
            ]);

            for (final it in items) {
              final cant = (it['cantidad'] as num).toInt();
              final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
              final cu = (it['costoUnitario'] as num?)?.toDouble() ?? 0.0;
              final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);
              final gan = (pu - cu) * cant;

              ingresoVenta += sub;
              costoVenta += cu * cant;
              gananciaVenta += gan;

              rows.add([
                (it['codigo']?.toString() ?? ''),
                (it['producto']?.toString() ?? ''),
                cant.toString(),
                _money(pu),
                _money(cu),
                _money(sub),
                _money(gan),
              ]);
            }

            totalIngresoGlobal += ingresoVenta;
            totalCostoGlobal += costoVenta;
            totalGananciaGlobal += gananciaVenta;

            widgets.add(pw.Divider());
            widgets.add(
              pw.Text(
                '🧾 Venta #${venta['id']}   ${venta['fecha']}',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            );
            widgets.add(pw.Text(
                'Cliente: ${venta['clienteNombre'] ?? 'Consumidor Final'}'));
            widgets.add(pw.Text('Método de pago: ${venta['metodoPago']}'));
            widgets.add(pw.SizedBox(height: 6));

            // Tabla por venta
            widgets.add(
              pw.TableHelper.fromTextArray(
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            );

            // Totales por venta
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Ingreso: ${_money(ingresoVenta)}'),
                      pw.Text('Costo:   ${_money(costoVenta)}'),
                      pw.Text('Ganancia: ${_money(gananciaVenta)}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800)),
                    ],
                  ),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 12));
          }

          // Resumen global al final
          widgets.add(pw.Divider());
          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('TOTAL INGRESO: ${_money(totalIngresoGlobal)}'),
                  pw.Text('TOTAL COSTO:   ${_money(totalCostoGlobal)}'),
                  pw.Text('TOTAL GANANCIA: ${_money(totalGananciaGlobal)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900)),
                ],
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reportePdf()}');
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Reporte PDF guardado: ${file.path}")),
    );

    await Printing.layoutPdf(onLayout: (_) async => await pdf.save());
  }

  /// ✅ Exportar Excel (Ventas con ganancia, Items detalle, Deudas)
  Future<void> _exportarExcelFiltrado(BuildContext context) async {
    final ventas = await dbService.getVentasFiltradasParaReporte(
      clienteId: _clienteSeleccionado?.id,
      metodoPago: metodoSeleccionado,
      desde: desde,
      hasta: hasta,
    );
    final deudas = await dbService.getDeudasFiltradasParaReporte(
      clienteId: _clienteSeleccionado?.id,
      estado: estadoSeleccionado,
      desde: desde,
      hasta: hasta,
    );

    final excel = Excel.createExcel();
    final shVentas = excel['Ventas'];
    final shItems = excel['Items'];
    final shDeudas = excel['Deudas'];
    excel.setDefaultSheet('Ventas');

    // Encabezados
    shVentas.appendRow(
        ['ID', 'Cliente', 'Método', 'Fecha', 'Ingreso', 'Costo', 'Ganancia']);
    shItems.appendRow([
      'VentaID',
      'Código',
      'Producto',
      'Cant.',
      'Precio Unit.',
      'Costo Unit.',
      'Subtotal',
      'Ganancia'
    ]);
    shDeudas.appendRow(['ID', 'Cliente', 'Fecha', 'Estado', 'Monto']);

    double totalIngresoGlobal = 0,
        totalCostoGlobal = 0,
        totalGananciaGlobal = 0;

    for (final v in ventas) {
      final items = await dbService.getItemsByVenta(v['id'] as int);

      double ingresoVenta = 0, costoVenta = 0, gananciaVenta = 0;
      for (final it in items) {
        final cant = (it['cantidad'] as num).toInt();
        final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
        final cu = (it['costoUnitario'] as num?)?.toDouble() ?? 0.0;
        final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);
        final gan = (pu - cu) * cant;

        ingresoVenta += sub;
        costoVenta += cu * cant;
        gananciaVenta += gan;

        shItems.appendRow([
          v['id'],
          it['codigo']?.toString() ?? '',
          it['producto']?.toString() ?? '',
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
      ]);
    }

    // Deudas
    for (final d in deudas) {
      shDeudas.appendRow([
        d['id'],
        d['clienteNombre'] ?? 'Consumidor Final',
        d['fecha'],
        d['estado'],
        d['monto'],
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
      totalGananciaGlobal
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
    await Share.shareXFiles([XFile(file.path)], text: "📊 Reporte Filtrado");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reportes Filtrados")),
      body: ArticBackground(
        child: ArticContainer(
          child: Column(
            children: [
              _buildFiltrosReportes(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Generar PDF"),
                onPressed: () => _generarReporteFiltrado(context),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.table_chart),
                label: const Text("Exportar Excel"),
                onPressed: () => _exportarExcelFiltrado(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modelo interno para cargar ventas con items antes de armar el PDF/Excel
class _VentaConItems {
  final Map<String, dynamic> venta;
  final List<Map<String, dynamic>> items;
  _VentaConItems({required this.venta, required this.items});
}
