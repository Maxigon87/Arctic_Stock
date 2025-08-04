import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../screens/product_list_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Cliente? _clienteSeleccionado;
  String? metodoSeleccionado;
  DateTime? desde;
  DateTime? hasta;
  List<Cliente> _clientes = [];
  final List<Map<String, dynamic>> _carrito = [];
  late Future<List<Map<String, dynamic>>> _ventasFuture;

  final dbService = DBService();

  @override
  void initState() {
    super.initState();
    _ventasFuture = dbService.getVentas();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    final clientes = await dbService.getClientes();
    setState(() => _clientes = clientes);
  }

  Future<void> _cargarVentasFiltradas() async {
    setState(() {
      _ventasFuture = dbService.buscarVentasAvanzado(
        clienteId: _clienteSeleccionado?.id,
        metodoPago: metodoSeleccionado,
        desde: desde,
        hasta: hasta,
      );
    });
  }

  /// 🟢 **Dialogo para agregar cliente en caliente**
  Future<Cliente?> _showNuevoClienteDialog() async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();

    return showDialog<Cliente>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Nuevo Cliente"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: "Nombre")),
              TextField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: "Teléfono")),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;

                final nuevoCliente =
                    Cliente(nombre: nombre, telefono: telefonoCtrl.text.trim());
                final id = await dbService.insertCliente(nuevoCliente);

                Navigator.pop(
                    ctx,
                    Cliente(
                        id: id,
                        nombre: nombre,
                        telefono: telefonoCtrl.text.trim()));
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  /// 🛒 **Carrito**
  void _abrirCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scroll) {
          return StatefulBuilder(builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.97),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("🛒 Nueva Venta",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  /// 🔹 Cliente
                  /// 🔹 Cliente
                  DropdownButtonFormField<Cliente?>(
                    value: _clienteSeleccionado,
                    hint: const Text("Cliente (opcional)"),
                    items: [
                      const DropdownMenuItem<Cliente?>(
                          value: null, child: Text("Consumidor Final")),
                      ..._clientes.map((c) => DropdownMenuItem<Cliente?>(
                          value: c, child: Text(c.nombre))),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => _clienteSeleccionado = value),
                  ),

                  /// ➕ Botón agregar cliente
                  TextButton.icon(
                    icon: const Icon(Icons.person_add, color: Colors.teal),
                    label: const Text("Agregar Cliente"),
                    onPressed: () async {
                      final nuevo = await _showNuevoClienteDialog();
                      if (nuevo != null) {
                        setState(() => _clientes.add(nuevo));
                        setLocalState(() => _clienteSeleccionado = nuevo);
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  /// 🔹 Método de pago
                  DropdownButtonFormField<String>(
                    value: metodoSeleccionado ?? "Efectivo",
                    hint: const Text("Método de Pago"),
                    items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => metodoSeleccionado = value),
                  ),

                  const SizedBox(height: 15),

                  /// 🔹 Lista de productos agregados
                  Expanded(
                    child: _carrito.isEmpty
                        ? const Center(child: Text("Carrito vacío"))
                        : ListView.builder(
                            controller: scroll,
                            itemCount: _carrito.length,
                            itemBuilder: (_, i) {
                              final p = _carrito[i];
                              return ListTile(
                                title: Text(p['nombre']),
                                subtitle: Text(
                                    "Cant: ${p['cantidad']}  -  \$${p['subtotal']}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      setLocalState(() => _carrito.removeAt(i)),
                                ),
                              );
                            },
                          ),
                  ),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar Producto"),
                    onPressed: () => _seleccionarProducto(() {
                      setLocalState(() {}); // ✅ Fuerza rebuild del modal
                    }),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Confirmar Venta"),
                    onPressed: _confirmarVenta,
                  ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  /// ✅ Seleccionar producto desde lista
  void _seleccionarProducto([VoidCallback? onProductoAgregado]) async {
    final producto = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const ProductListScreen(selectMode: true)),
    );

    if (producto != null) {
      final stock = producto['stock'] ?? 0;
      if (stock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ Este producto no tiene stock disponible")),
        );
        return;
      }
      setState(() {
        final precio = (producto['precio'] as num).toDouble();
        _carrito.add({
          'productoId': producto['id'],
          'nombre': producto['nombre'],
          'precio': precio,
          'cantidad': 1,
          'subtotal': precio,
        });
      });
      if (onProductoAgregado != null) {
        onProductoAgregado();
      }
    }
  }

  /// ✅ Confirmar venta
  /// ✅ Confirmar venta (modificado para permitir cliente null)
  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ El carrito está vacío")));
      return;
    }

    // ✅ Solo bloquea si es fiado y no hay cliente
    if (metodoSeleccionado == 'Fiado' && _clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ No puedes fiar sin cliente")));
      return;
    }

    final total = _carrito.fold(0.0, (sum, i) => sum + i['subtotal']);

    try {
      // ✅ Primero insertamos la venta
      final ventaId = await dbService.insertVentaBase({
        'clienteId': _clienteSeleccionado?.id,
        'fecha': DateTime.now().toIso8601String(),
        'metodoPago': metodoSeleccionado ?? 'Efectivo',
        'total': total,
      });

      // ✅ Luego insertamos cada item y verificamos stock
      for (var i in _carrito) {
        await dbService.insertItemVenta({
          'ventaId': ventaId,
          'productoId': i['productoId'],
          'cantidad': i['cantidad'],
          'subtotal': i['subtotal'],
        });
      }

      // ✅ Si es fiado y hay cliente, registra deuda
      if (metodoSeleccionado == 'Fiado' && _clienteSeleccionado != null) {
        await dbService.insertDeuda({
          'clienteId': _clienteSeleccionado!.id,
          'monto': total,
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'Pendiente',
          'descripcion': 'Venta fiada',
        });
      }

      // ✅ Refrescar UI
      setState(() {
        _carrito.clear();
        _ventasFuture = dbService.getVentas();
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Venta registrada correctamente!")));
    } catch (e) {
      // ❌ Si no hay stock, mostramos mensaje y no seguimos
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: ${e.toString()}")),
      );
    }
  }

  /// 🔍 Filtros de búsqueda
  Widget _buildFiltros() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<Cliente?>(
                hint: const Text("Cliente (opcional)"),
                value: _clienteSeleccionado,
                items: [
                  const DropdownMenuItem<Cliente?>(
                      value: null, child: Text("Consumidor Final")),
                  ..._clientes.map((c) => DropdownMenuItem<Cliente?>(
                      value: c, child: Text(c.nombre))),
                ],
                onChanged: (value) {
                  setState(() => _clienteSeleccionado = value);
                  _cargarVentasFiltradas();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                hint: const Text("Método de Pago"),
                value: metodoSeleccionado,
                items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  setState(() => metodoSeleccionado = value);
                  _cargarVentasFiltradas();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
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
              _cargarVentasFiltradas();
            }
          },
          child: const Text("Filtrar por Fecha"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ventas")),
      body: ArticBackground(
        child: ArticContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFiltros(),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ventasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No hay ventas"));
                    }
                    final ventas = snapshot.data!;
                    return ListView.builder(
                      itemCount: ventas.length,
                      itemBuilder: (context, index) {
                        final venta = ventas[index];

                        // ✅ Si clienteNombre es null o vacío, usar "Consumidor Final"
                        final cliente =
                            (venta['clienteNombre']?.toString().isNotEmpty ??
                                    false)
                                ? venta['clienteNombre']
                                : 'Consumidor Final';

                        return Card(
                          child: ListTile(
                            title: Text("Venta #${venta['id']} - $cliente"),
                            subtitle: Text(
                                "Total: \$${venta['total']} - Método: ${venta['metodoPago']}"),
                            trailing: Text(
                                venta['fecha'].toString().split('T').first),
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_shopping_cart),
        onPressed: _abrirCarrito,
      ),
    );
  }
}
