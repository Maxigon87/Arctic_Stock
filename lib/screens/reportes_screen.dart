import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/db_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({Key? key}) : super(key: key);

  Future<void> _generarReporteMensual(BuildContext context) async {
    final mesActual = DateTime.now().month.toString().padLeft(2, '0');
    final stock = await DBService().getStockProductos();
    final ventas = await DBService().getVentasDelMes(mesActual);
    final deudas = await DBService().getDeudasDelMes(mesActual);

    double totalVentas = ventas.fold(0, (sum, v) => sum + (v['total'] ?? 0));
    double totalDeudas = deudas.fold(0, (sum, d) => sum + (d['monto'] ?? 0));

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "📊 Reporte Mensual - $mesActual",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text("🟢 STOCK ACTUAL", style: pw.TextStyle(fontSize: 18)),
              pw.Table.fromTextArray(
                headers: ["Producto", "Precio", "ID"],
                data: stock
                    .map(
                      (p) => [
                        p['nombre'],
                        "\$${p['precio']}",
                        p['id'].toString(),
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 15),

              pw.Text("🟣 VENTAS DEL MES", style: pw.TextStyle(fontSize: 18)),
              pw.Table.fromTextArray(
                headers: ["Cliente", "Pago", "Total"],
                data: ventas
                    .map(
                      (v) => [v['cliente'], v['metodoPago'], "\$${v['total']}"],
                    )
                    .toList(),
              ),
              pw.Text(
                "TOTAL VENTAS: \$${totalVentas.toStringAsFixed(2)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 15),
              pw.Text("🔴 DEUDAS DEL MES", style: pw.TextStyle(fontSize: 18)),
              pw.Table.fromTextArray(
                headers: ["Cliente", "Monto", "Pago"],
                data: deudas
                    .map(
                      (d) => [
                        d['cliente'],
                        "\$${d['monto']}",
                        d['metodoPago'] ?? 'Pendiente',
                      ],
                    )
                    .toList(),
              ),
              pw.Text(
                "TOTAL DEUDAS: \$${totalDeudas.toStringAsFixed(2)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    // ✅ Mostrar PDF en visor
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportarExcelMensual(BuildContext context) async {
    final mesActual = DateTime.now().month.toString().padLeft(2, '0');

    // 🔹 Obtener datos desde DB
    final stock = await DBService().getStockProductos();
    final ventas = await DBService().getVentasDelMes(mesActual);
    final deudas = await DBService().getDeudasDelMes(mesActual);

    // 🔹 Crear nuevo Excel
    final excel = Excel.createExcel();
    final sheet = excel['Reporte_Mensual'];

    // ✅ Encabezado
    sheet.appendRow(['📊 Reporte Mensual', 'Mes: $mesActual']);
    sheet.appendRow([]);

    // ✅ Stock
    sheet.appendRow(['🟢 STOCK ACTUAL']);
    sheet.appendRow(['Producto', 'Precio', 'ID']);
    for (var p in stock) {
      sheet.appendRow([p['nombre'], p['precio'], p['id']]);
    }
    sheet.appendRow([]);

    // ✅ Ventas
    sheet.appendRow(['🟣 VENTAS DEL MES']);
    sheet.appendRow(['Cliente', 'Pago', 'Total']);
    double totalVentas = 0;
    for (var v in ventas) {
      totalVentas += (v['total'] ?? 0);
      sheet.appendRow([v['cliente'], v['metodoPago'], v['total']]);
    }
    sheet.appendRow(['TOTAL VENTAS', '', totalVentas]);
    sheet.appendRow([]);

    // ✅ Deudas
    sheet.appendRow(['🔴 DEUDAS DEL MES']);
    sheet.appendRow(['Cliente', 'Monto', 'Pago']);
    double totalDeudas = 0;
    for (var d in deudas) {
      totalDeudas += (d['monto'] ?? 0);
      sheet.appendRow([
        d['cliente'],
        d['monto'],
        d['metodoPago'] ?? 'Pendiente',
      ]);
    }
    sheet.appendRow(['TOTAL DEUDAS', '', totalDeudas]);

    // 🔹 Guardar archivo
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/Reporte_Jeremias_$mesActual.xlsx';
    final fileBytes = excel.encode();
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    // ✅ Notificar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Reporte Excel guardado en: $filePath")),
    );

    // ✅ Compartir
    await Share.shareXFiles([
      XFile(file.path),
    ], text: "📊 Reporte Jeremías - $mesActual");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reporte Mensual")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Generar Reporte PDF"),
              onPressed: () => _generarReporteMensual(context),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.table_chart),
              label: const Text("Exportar Reporte Excel"),
              onPressed: () => _exportarExcelMensual(context),
            ),
          ],
        ),
      ),
    );
  }
}
