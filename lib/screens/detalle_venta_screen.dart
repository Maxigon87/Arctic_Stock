import 'package:flutter/material.dart';
import '../services/db_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DetalleVentaScreen extends StatelessWidget {
  final int ventaId;
  final String cliente;
  final String metodoPago;
  final double total;
  final String fecha;

  const DetalleVentaScreen({
    Key? key,
    required this.ventaId,
    required this.cliente,
    required this.metodoPago,
    required this.total,
    required this.fecha,
  }) : super(key: key);

  Future<List<Map<String, dynamic>>> _getItems() async {
    return await DBService().getItemsByVenta(ventaId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalle de Venta")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Datos generales de la venta
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Cliente: $cliente\nPago: $metodoPago\nTotal: \$${total.toStringAsFixed(2)}\nFecha: $fecha",
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Productos",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text("No hay productos en esta venta."),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item['producto']),
                      subtitle: Text(
                        "Cantidad: ${item['cantidad']} x \$${item['precioUnitario']}",
                      ),
                      trailing: Text("Subtotal: \$${item['subtotal']}"),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ✅ Aquí va el FAB para generar PDF
      floatingActionButton: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getItems(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return FloatingActionButton(
            onPressed: items.isEmpty
                ? null
                : () async {
                    await _generatePDF(context, items);
                  },
            backgroundColor: Colors.red,
            child: const Icon(Icons.picture_as_pdf),
          );
        },
      ),
    );
  }

  Future<void> _generatePDF(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();

    // 🔹 Construir contenido
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Factura de Venta",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Cliente: $cliente"),
              pw.Text("Fecha: $fecha"),
              pw.Text("Pago: $metodoPago"),
              pw.Divider(),
              pw.Text("Productos:", style: pw.TextStyle(fontSize: 18)),
              pw.Table.fromTextArray(
                headers: ["Producto", "Cant.", "Precio Unit.", "Subtotal"],
                data: items
                    .map(
                      (e) => [
                        e['producto'],
                        e['cantidad'].toString(),
                        "\$${e['precioUnitario']}",
                        "\$${e['subtotal']}",
                      ],
                    )
                    .toList(),
              ),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "TOTAL: \$${total.toStringAsFixed(2)}",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // ✅ Guardar en carpeta "Documents/JeremiasVentas"
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory("${directory.path}/JeremiasVentas");
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final filePath = "${exportDir.path}/venta_$ventaId.pdf";
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // ✅ Mostrar confirmación
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("PDF guardado en: $filePath")));

    // ✅ Abrir visor de impresión (opcional)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    // ✅ Preguntar si quiere compartir
    await Share.shareXFiles([
      XFile(file.path),
    ], text: "Factura de Venta - Cliente: $cliente");
  }
}
