import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/db_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../Services/file_helper.dart';
import '../utils/file_namer.dart';
import '../models/cliente.dart';
import 'package:intl/intl.dart';

// Generación de reportes mensuales en PDF con ventas ordenadas
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

  String formateaFechaHora(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }


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
    final ventas = await dbService.getVentasFiltradasParaReporte(
      clienteId: _clienteSeleccionado?.id,
      metodoPago: metodoSeleccionado,
      desde: desde,
      hasta: hasta,
    );

    final List<_VentaConItems> data = [];
    for (final v in ventas) {
      final items = await dbService.getItemsByVenta(v['id'] as int);
      data.add(_VentaConItems(venta: v, items: items));
    }

    data.sort((a, b) {
      final fa = DateTime.parse(a.venta['fecha'] as String);
      final fb = DateTime.parse(b.venta['fecha'] as String);
      return fa.compareTo(fb);
    });

    final primerDia =
        data.isNotEmpty ? DateTime.parse(data.first.venta['fecha']) : DateTime.now();
    final monthName = DateFormat.MMMM('es_ES').format(primerDia);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reporte mensual de ventas - $monthName ${primerDia.year}',
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            ...List.generate(data.length, (i) {
              final venta = data[i].venta;
              final items = data[i].items;
              final fecha = DateTime.parse(venta['fecha'] as String);
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
                    child: pw.Text(
                      'Compra ${i + 1} - ${formateaFechaHora(fecha)} - ${venta['metodoPago']}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  pw.Table.fromTextArray(
                    headers: ['Producto', 'Descripción', 'Cantidad'],
                    data: items
                        .map((it) => [
                              it['producto'] ?? it['nombre'] ?? '',
                              it['descripcion'] ?? '',
                              (it['cantidad'] ?? '').toString(),
                            ])
                        .toList(),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
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
