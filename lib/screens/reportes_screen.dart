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

    // ✅ Construcción del PDF igual que antes...
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("📊 Reporte Mensual - $mesActual",
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              // ... resto igual
            ],
          );
        },
      ),
    );

    // ✅ Guardar en carpeta fija con nombre dinámico
    final dir = await FileHelper.getReportesDir();
    final filename = FileNamer.reportePdf();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    // ✅ Mostrar snack y abrir visor
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Reporte PDF guardado en: ${file.path}")),
    );

    // ✅ Previsualizar PDF en visor nativo
    await Printing.layoutPdf(onLayout: (_) async => await pdf.save());
  }

  Future<void> _exportarExcelMensual(BuildContext context) async {
    final mesActual = DateTime.now().month.toString().padLeft(2, '0');
    final stock = await DBService().getStockProductos();
    final ventas = await DBService().getVentasDelMes(mesActual);
    final deudas = await DBService().getDeudasDelMes(mesActual);

    final excel = Excel.createExcel();
    final sheet = excel['Reporte_Mensual'];

    // ✅ (Contenido igual que antes)
    // ...

    // ✅ Guardar en carpeta fija con nombre dinámico
    final dir = await FileHelper.getReportesDir();
    final filename = FileNamer.reporteExcel();
    final filePath = '${dir.path}/$filename';
    final fileBytes = excel.encode();
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    // ✅ Snack y compartir
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Reporte Excel guardado en: $filePath")),
    );

    await Share.shareXFiles([XFile(file.path)],
        text: "📊 Reporte Jeremías - $mesActual");
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

class FileHelper {
  static Future<Directory> getVentasDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final ventasDir = Directory('${dir.path}/JeremiasVentas');
    if (!await ventasDir.exists()) {
      await ventasDir.create(recursive: true);
    }
    return ventasDir;
  }

  static Future<Directory> getReportesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportesDir = Directory('${dir.path}/JeremiasReportes');
    if (!await reportesDir.exists()) {
      await reportesDir.create(recursive: true);
    }
    return reportesDir;
  }
}
