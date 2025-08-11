import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/db_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

  /// ✅ Filtros en UI
  Widget _buildFiltrosReportes() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<Cliente>(
                hint: Text("Cliente"),
                value: _clienteSeleccionado,
                items: _clientes.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.nombre));
                }).toList(),
                onChanged: (v) => setState(() => _clienteSeleccionado = v),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                hint: Text("Método Pago"),
                value: metodoSeleccionado,
                items: ["Efectivo", "Tarjeta", "Transferencia"].map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (v) => setState(() => metodoSeleccionado = v),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                hint: Text("Estado Deuda"),
                value: estadoSeleccionado,
                items: ["Pendiente", "Pagada"].map((e) {
                  return DropdownMenuItem(value: e, child: Text(e));
                }).toList(),
                onChanged: (v) => setState(() => estadoSeleccionado = v),
              ),
            ),
            SizedBox(width: 10),
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
                child: Text("Elegir Fechas"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ Generar PDF con datos filtrados
  Future<void> _generarReporteFiltrado(BuildContext context) async {
    final ventas = await dbService.getVentasFiltradasParaReporte(
      clienteId: _clienteSeleccionado?.id,
      metodoPago: metodoSeleccionado,
      desde: desde,
      hasta: hasta,
    );

    final pdf = pw.Document();

    final logoImage = pw.MemoryImage(
      File('assets/images/artic_logo.png').readAsBytesSync(),
    );

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Artic Stock',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'Reporte de Ventas',
                    style: pw.TextStyle(fontSize: 14),
                  ),
                  pw.Text(
                    'Generado: ${DateTime.now().toString().substring(0, 16)}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Image(logoImage, width: 80, height: 80),
            ],
          ),
          pw.SizedBox(height: 20),
          ...ventas
              .map((venta) async {
                final detalles = await dbService.getItemsByVenta(venta['id']);
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Divider(),
                    pw.Text(
                      '🧾 Venta #${venta['id']} - ${venta['fecha']}',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Cliente: ${venta['clienteNombre']}'),
                    pw.Text('Método de pago: ${venta['metodoPago']}'),
                    pw.Text('Total: \$${venta['total'].toStringAsFixed(2)}'),
                    pw.SizedBox(height: 5),
                    pw.Table.fromTextArray(
                      headers: [
                        'Producto',
                        'Cantidad',
                        'Precio Unitario',
                        'Subtotal'
                      ],
                      data: detalles.map((item) {
                        return [
                          item['producto'],
                          item['cantidad'].toString(),
                          '\$${item['precioUnitario'].toStringAsFixed(2)}',
                          '\$${item['subtotal'].toStringAsFixed(2)}'
                        ];
                      }).toList(),
                    ),
                    pw.SizedBox(height: 10),
                  ],
                );
              })
              .toList()
              .cast<pw.Widget>(),
        ],
      ),
    );

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reportePdf()}');
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Reporte PDF guardado: ${file.path}")),
    );

    await Printing.layoutPdf(onLayout: (_) async => await pdf.save());
  }

  /// ✅ Exportar Excel con filtros
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
    final sheet = excel['Reporte_Filtrado'];
    excel.setDefaultSheet('Reporte_Filtrado');

    sheet.appendRow(["Ventas"]);
    sheet.appendRow(['ID', 'Cliente', 'Total']);
    ventas.forEach(
        (v) => sheet.appendRow([v['id'], v['clienteNombre'], v['total']]));
    sheet.appendRow([]);
    sheet.appendRow(["Deudas"]);
    sheet.appendRow(['ID', 'Cliente', 'Total']);
    deudas.forEach(
        (d) => sheet.appendRow([d['id'], d['clienteNombre'], d['monto']]));

    final dir = await FileHelper.getReportesDir();
    final file = File('${dir.path}/${FileNamer.reporteExcel()}')
      ..createSync(recursive: true);

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Excel guardado: ${file.path}")),
    );
    await Share.shareXFiles([XFile(file.path)], text: "📊 Reporte Filtrado");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reportes Filtrados")),
      body: ArticBackground(
        child: ArticContainer(
          child: Column(
            children: [
              _buildFiltrosReportes(),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.picture_as_pdf),
                label: Text("Generar PDF"),
                onPressed: () => _generarReporteFiltrado(context),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.table_chart),
                label: Text("Exportar Excel"),
                onPressed: () => _exportarExcelFiltrado(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
