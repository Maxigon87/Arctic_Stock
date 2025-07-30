import 'package:flutter/material.dart';
import '../models/cliente.dart'; // ✅ necesario
import '../services/db_service.dart';
import 'detalle_venta_screen.dart';

List<Map<String, dynamic>> _ventasFiltradas = [];
String _filtroMetodoPago = "";

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Cliente? _clienteSeleccionado; // ✅ solo usamos este
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

  void _agregarClienteRapido() {
    final nombreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuevo Cliente"),
        content: TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(labelText: "Nombre")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              final nuevo = Cliente(nombre: nombreCtrl.text);
              final id = await DBService().insertCliente(nuevo);
              _clienteSeleccionado = Cliente(id: id, nombre: nombreCtrl.text);
              await _cargarClientes();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _loadVentas() {
    setState(() {
      _ventasFuture = DBService().getVentas();
    });
  }

  Future<void> _cargarClientes() async {
    _clientes = await DBService().getClientes();
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _getProductos() async {
    return await DBService().getProductos();
  }

  // 🔹 Modal para agregar productos al carrito
  void _showAddItemDialog() async {
    final productos = await _getProductos();
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay productos registrados.")),
      );
      return;
    }

    int? selectedProductoId = productos.first['id'];
    int cantidad = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Agregar producto al carrito"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: selectedProductoId,
                    items: productos.map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(p['nombre']),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedProductoId = value),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "Cantidad"),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => cantidad = int.tryParse(val) ?? 1,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final producto = productos.firstWhere(
                      (p) => p['id'] == selectedProductoId,
                    );
                    final double precio =
                        (producto['precio'] as num).toDouble();

                    _carrito.add({
                      'productoId': selectedProductoId,
                      'nombre': producto['nombre'],
                      'cantidad': cantidad,
                      'subtotal': precio * cantidad,
                    });
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text("Agregar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🔹 Modal para datos generales de la venta
  void _showConfirmVentaDialog() {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega productos antes de confirmar.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Confirmar Venta"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Cliente>(
                    value: _clienteSeleccionado,
                    isExpanded: true,
                    hint: const Text("Seleccionar cliente"),
                    items: [
                      ..._clientes.map((c) =>
                          DropdownMenuItem(value: c, child: Text(c.nombre))),
                      const DropdownMenuItem(
                          value: null, child: Text("➕ Agregar nuevo cliente")),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        _agregarClienteRapido();
                      } else {
                        setState(() => _clienteSeleccionado = value);
                      }
                    },
                  ),
                  DropdownButton<String>(
                    value: _metodoPago,
                    items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _metodoPago = val!),
                  ),
                  Text(
                    "Total: \$${_carrito.fold(0.0, (sum, item) => sum + (item['subtotal'] as double))}",
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _confirmarVenta();
                    Navigator.pop(context);
                  },
                  child: const Text("Confirmar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🔹 Insertar la venta y sus items en la DB
  Future<void> _confirmarVenta() async {
    final total = _carrito.fold(
      0.0,
      (sum, item) => sum + (item['subtotal'] as double),
    );

    // 1. Crear venta base
    final ventaId = await DBService().insertVentaBase({
      'clienteId': _clienteSeleccionado?.id,
      'fecha': DateTime.now().toIso8601String(),
      'metodoPago': _metodoPago,
      'total': total,
    });

    // 2. Insertar productos en items_venta
    for (var item in _carrito) {
      await DBService().insertItemVenta({
        'ventaId': ventaId,
        'productoId': item['productoId'],
        'cantidad': item['cantidad'],
        'subtotal': item['subtotal'],
      });
    }

    // 3. Si es fiado, crear deuda automática
    if (_metodoPago == "Fiado") {
      await DBService().insertDeuda({
        'clienteId': _clienteSeleccionado?.id,
        'monto': total,
        'fecha': DateTime.now().toIso8601String(),
        'estado': 'Pendiente',
        'descripcion': 'Deuda generada automáticamente por venta fiada',
      });
    }

    // 4. Limpiar carrito y refrescar ventas
    _carrito.clear();
    _loadVentas();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas con Carrito')),
      body: Column(
        children: [
          // 🔹 Carrito actual
          if (_carrito.isNotEmpty)
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: _carrito.length,
                itemBuilder: (context, index) {
                  final item = _carrito[index];
                  return ListTile(
                    title: Text(item['nombre']),
                    subtitle: Text('Cantidad: ${item['cantidad']}'),
                    trailing: Text('\$${item['subtotal']}'),
                    onLongPress: () {
                      setState(() => _carrito.removeAt(index));
                    },
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Carrito vacío. Agrega productos."),
            ),
          TextField(
            decoration: const InputDecoration(
              labelText: "Buscar cliente...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) async {
              final results = await DBService().buscarVentas(cliente: val);
              setState(() => _ventasFiltradas = results);
            },
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _filtroMetodoPago.isEmpty ? null : _filtroMetodoPago,
            hint: const Text("Filtrar por método de pago"),
            items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) async {
              _filtroMetodoPago = val ?? "";
              final results =
                  await DBService().buscarVentas(metodoPago: _filtroMetodoPago);
              setState(() => _ventasFiltradas = results);
            },
          ),

          // 🔹 Ventas registradas en DB
          Expanded(
            flex: 1,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _ventasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final ventas = _ventasFiltradas.isNotEmpty
                    ? _ventasFiltradas
                    : (snapshot.data ?? []);

                if (ventas.isEmpty) {
                  return const Center(
                    child: Text('No hay ventas registradas.'),
                  );
                }
                return ListView.builder(
                  itemCount: ventas.length,
                  itemBuilder: (context, index) {
                    final v = ventas[index];
                    return ListTile(
                      title: Text('Venta ID: ${v['id']} - ${v['cliente']}'),
                      subtitle: Text(
                        'Pago: ${v['metodoPago']} - Total: \$${v['total']}',
                      ),
                      trailing: Text(v['fecha']),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetalleVentaScreen(ventaId: v['id']),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "addItem",
            onPressed: _showAddItemDialog,
            child: const Icon(Icons.add_shopping_cart),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "confirmVenta",
            onPressed: _showConfirmVentaDialog,
            backgroundColor: Colors.green,
            child: const Icon(Icons.check),
          ),
        ],
      ),
    );
  }
}
