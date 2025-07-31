import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';
import 'detalle_venta_screen.dart';
import '../widgets/artic_background.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Cliente? _clienteSeleccionado;
  List<Cliente> _clientes = [];
  String _metodoPago = "Efectivo";
  final List<Map<String, dynamic>> _carrito = [];
  late Future<List<Map<String, dynamic>>> _ventasFuture;

  @override
  void initState() {
    super.initState();
    _loadVentas();
    _cargarClientes();
  }

  void _loadVentas() {
    setState(() => _ventasFuture = DBService().getVentas());
  }

  Future<void> _cargarClientes() async {
    _clientes = await DBService().getClientes();
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _getProductos() async =>
      await DBService().getProductos();

  /// 🔹 Agregar cliente rápido
  void _agregarClienteRapido() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuevo Cliente"),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: "Nombre")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () async {
                if (ctrl.text.isEmpty) return;
                final nuevo = Cliente(nombre: ctrl.text);
                final id = await DBService().insertCliente(nuevo);
                _clienteSeleccionado = Cliente(id: id, nombre: ctrl.text);
                await _cargarClientes();
                Navigator.pop(context);
              },
              child: const Text("Guardar"))
        ],
      ),
    );
  }

  /// 🔹 Modal para agregar producto
  void _showAddItemDialog() async {
    final productos = await _getProductos();
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No hay productos.")));
      return;
    }

    int? selectedId = productos.first['id'];
    int cantidad = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Agregar producto"),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButton<int>(
                  value: selectedId,
                  items: productos
                      .map((p) => DropdownMenuItem<int>(
                          value: p['id'] as int, child: Text(p['nombre'])))
                      .toList(),
                  onChanged: (v) => setState(() => selectedId = v)),
              TextField(
                  decoration: const InputDecoration(labelText: "Cantidad"),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => cantidad = int.tryParse(v) ?? 1)
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar")),
              ElevatedButton(
                  onPressed: () {
                    final p =
                        productos.firstWhere((e) => e['id'] == selectedId);
                    final precio = (p['precio'] as num).toDouble();
                    _carrito.add({
                      'productoId': selectedId,
                      'nombre': p['nombre'],
                      'cantidad': cantidad,
                      'subtotal': precio * cantidad
                    });
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text("Agregar"))
            ],
          );
        });
      },
    );
  }

  /// ✅ Modal Carrito con efecto ártico
  void _showCarritoModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(10),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("🛒 Carrito",
                  style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(height: 200, child: _buildCarritoList(setModalState)),
              _buildTotalSection(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.white))),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showConfirmVentaDialog();
                    },
                    child: const Text("Confirmar Venta"))
              ])
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildCarritoList(Function(void Function()) setModalState) {
    return ListView.builder(
      itemCount: _carrito.length,
      itemBuilder: (context, i) {
        final item = _carrito[i];
        return ListTile(
          title:
              Text(item['nombre'], style: const TextStyle(color: Colors.white)),
          subtitle: Text("Cant: ${item['cantidad']}",
              style: const TextStyle(color: Colors.white70)),
          trailing: Text("\$${item['subtotal'].toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.cyanAccent)),
          onLongPress: () => setModalState(() => _carrito.removeAt(i)),
        );
      },
    );
  }

  Widget _buildTotalSection() {
    final total =
        _carrito.fold<double>(0, (s, c) => s + (c['subtotal'] as double));
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text("💵 Total: \$${total.toStringAsFixed(2)}",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  /// 🔹 Confirmación de Venta
  void _showConfirmVentaDialog() {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Carrito vacío.")));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar Venta"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButton<Cliente>(
              hint: const Text("Seleccionar cliente"),
              value: _clienteSeleccionado,
              items: _clientes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.nombre)))
                  .toList(),
              onChanged: (v) => setState(() => _clienteSeleccionado = v)),
          DropdownButton<String>(
              value: _metodoPago,
              items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _metodoPago = v!)),
          Text(
              "Total: \$${_carrito.fold<double>(0, (s, c) => s + (c['subtotal'] as double)).toStringAsFixed(2)}")
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () async {
                await _confirmarVenta();
                Navigator.pop(context);
              },
              child: const Text("Confirmar"))
        ],
      ),
    );
  }

  Future<void> _confirmarVenta() async {
    final total =
        _carrito.fold<double>(0, (s, c) => s + (c['subtotal'] as double));
    final ventaId = await DBService().insertVentaBase({
      'clienteId': _clienteSeleccionado?.id,
      'fecha': DateTime.now().toIso8601String(),
      'metodoPago': _metodoPago,
      'total': total
    });
    for (var item in _carrito) {
      await DBService().insertItemVenta({
        'ventaId': ventaId,
        'productoId': item['productoId'],
        'cantidad': item['cantidad'],
        'subtotal': item['subtotal']
      });
    }
    _carrito.clear();
    _loadVentas();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas con Carrito')),
      body: Column(children: [
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _ventasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final ventas = snapshot.data ?? [];
              if (ventas.isEmpty)
                return const Center(child: Text("No hay ventas registradas."));
              return ListView.builder(
                itemCount: ventas.length,
                itemBuilder: (ctx, i) {
                  final v = ventas[i];
                  return ListTile(
                    title: Text("Venta ID: ${v['id']} - ${v['cliente']}"),
                    subtitle: Text(
                        "Pago: ${v['metodoPago']} - Total: \$${v['total']}"),
                    trailing: Text(v['fecha']),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DetalleVentaScreen(ventaId: v['id']))),
                  );
                },
              );
            },
          ),
        )
      ]),
      floatingActionButton:
          Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(
            heroTag: "addItem",
            onPressed: _showAddItemDialog,
            child: const Icon(Icons.add_shopping_cart)),
        const SizedBox(height: 10),
        FloatingActionButton(
            heroTag: "carrito",
            onPressed: _showCarritoModal,
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.shopping_cart))
      ]),
    );
  }
}
