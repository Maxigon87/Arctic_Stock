import 'package:flutter/material.dart';
import '../Services/db_service.dart';
import '../utils/currency_formatter.dart';

class DetalleVentaScreen extends StatefulWidget {
  final int ventaId; // ✅ ahora solo recibe el ID de la venta

  const DetalleVentaScreen({super.key, required this.ventaId});

  @override
  State<DetalleVentaScreen> createState() => _DetalleVentaScreenState();
}

class _DetalleVentaScreenState extends State<DetalleVentaScreen> {
  Map<String, dynamic>? venta; // Datos generales de la venta
  List<Map<String, dynamic>> items = []; // Productos vendidos

  @override
  void initState() {
    super.initState();
    _loadDetalle(); // ✅ Carga datos desde la DB
  }

  /// 🔹 Obtiene los datos de la venta y sus productos relacionados
  Future<void> _loadDetalle() async {
    final ventaData = await DBService().getVentaById(widget.ventaId);
    final productosData = await DBService().getItemsByVenta(widget.ventaId);

    setState(() {
      venta = ventaData;
      items = productosData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Venta')),
      body: venta == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Datos generales de la venta
                ListTile(
                  title: Text("Cliente: " + (venta!['cliente'] ?? 'Sin asignar')),
                  subtitle: Text("Fecha: " + venta!['fecha'].toString()),
                  trailing: Text("Total: " + formatCurrency(venta!['total'])),
                ),
                const Divider(),

                // ✅ Encabezado de la lista de productos
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Productos",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),

                // ✅ Lista de productos vendidos
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item['producto']),
                        subtitle: Text(
                          "Cantidad: " + item['cantidad'].toString() +
                              " x " + formatCurrency(item['precioUnitario']),
                        ),
                        trailing: Text(formatCurrency(item['subtotal'])),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
