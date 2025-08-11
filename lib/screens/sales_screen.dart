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

  // 🛒 carrito con snapshot de precios/costos
  // Keys: productoId, nombre, codigo, cantidad, precioUnit, costoUnit, subtotal
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

  String _money(num? n) => "\$${(n ?? 0).toStringAsFixed(2)}";

  Future<bool> _confirmarPerdidaDialog(double precio, double costo) async {
    if (precio >= costo) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atención'),
        content: Text(
          'Este producto se venderá con pérdida.\n'
          'Precio: ${precio.toStringAsFixed(2)} | Costo: ${costo.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Continuar')),
        ],
      ),
    );
    return ok == true;
  }

  /// 🛒 Carrito (bottom sheet)
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
            double totalCarrito =
                _carrito.fold(0.0, (sum, p) => sum + (p['subtotal'] as num));
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

                  // Cliente
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

                  // Método de pago
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

                  // Lista del carrito
                  Expanded(
                    child: _carrito.isEmpty
                        ? const Center(child: Text("Carrito vacío"))
                        : ListView.builder(
                            controller: scroll,
                            itemCount: _carrito.length,
                            itemBuilder: (_, i) {
                              final p = _carrito[i];
                              final double precioUnit =
                                  (p['precioUnit'] as num).toDouble();
                              final double costoUnit =
                                  (p['costoUnit'] as num).toDouble();
                              final int cantidad =
                                  (p['cantidad'] as num).toInt();
                              final double subtotal =
                                  (p['subtotal'] as num).toDouble();
                              final bool conPerdida = precioUnit < costoUnit;

                              return Column(
                                children: [
                                  ListTile(
                                    title: Text(p['nombre']),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((p['codigo']
                                                ?.toString()
                                                .isNotEmpty ??
                                            false))
                                          Text('Código: ${p['codigo']}'),
                                        Text(
                                          "Precio: ${_money(precioUnit)}  |  Costo: ${_money(costoUnit)}",
                                          style: TextStyle(
                                            color:
                                                conPerdida ? Colors.red : null,
                                            fontWeight: conPerdida
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.redAccent),
                                              onPressed: () {
                                                if (cantidad > 1) {
                                                  setLocalState(() {
                                                    p['cantidad'] =
                                                        cantidad - 1;
                                                    p['subtotal'] = precioUnit *
                                                        (cantidad - 1);
                                                  });
                                                }
                                              },
                                            ),
                                            Text("Cant: ${p['cantidad']}",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle,
                                                  color: Colors.green),
                                              onPressed: () {
                                                setLocalState(() {
                                                  p['cantidad'] = cantidad + 1;
                                                  p['subtotal'] = precioUnit *
                                                      (cantidad + 1);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        Text("Subtotal: ${_money(subtotal)}"),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => setLocalState(
                                          () => _carrito.removeAt(i)),
                                    ),
                                  ),
                                  if (i < _carrito.length - 1)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 4),
                                      child: Divider(
                                          thickness: 1, color: Colors.grey),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),

                  // TOTAL
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.centerRight,
                    child: Text(
                      "TOTAL: ${_money(totalCarrito)}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal),
                    ),
                  ),

                  // Agregar producto
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar Producto"),
                    onPressed: () => _seleccionarProducto(() {
                      setLocalState(() {}); // fuerza rebuild
                    }),
                  ),

                  const SizedBox(height: 10),

                  // Confirmar venta
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

  /// Seleccionar producto (selectMode) y agregar al carrito con snapshot
  void _seleccionarProducto([VoidCallback? onProductoAgregado]) async {
    final producto = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const ProductListScreen(selectMode: true)),
    );

    if (producto != null) {
      final stock = (producto['stock'] as num?)?.toInt() ?? 0;
      if (stock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ Este producto no tiene stock disponible")),
        );
        return;
      }

      final double precio =
          (producto['precio_venta'] as num?)?.toDouble() ?? 0.0;
      final double costo =
          (producto['costo_compra'] as num?)?.toDouble() ?? 0.0;

      // Soft warning si hay pérdida
      final seguir = await _confirmarPerdidaDialog(precio, costo);
      if (!seguir) return;

      setState(() {
        _carrito.add({
          'productoId': producto['id'],
          'nombre': producto['nombre'],
          'codigo': producto['codigo'],
          'precioUnit': precio, // snapshot
          'costoUnit': costo, // snapshot
          'cantidad': 1,
          'subtotal': precio * 1,
        });
      });
      onProductoAgregado?.call();
    }
  }

  /// Confirmar venta (con snapshot y deudas)
  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ El carrito está vacío")),
      );
      return;
    }

    if (metodoSeleccionado == 'Fiado' && _clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ No puedes fiar sin cliente")),
      );
      return;
    }

    // Verificar stock actual antes de procesar
    final productosAgotados = <String>[];
    for (var item in _carrito) {
      final producto = await dbService.getProductoById(item['productoId']);
      if (producto == null) {
        productosAgotados
            .add("Producto desconocido (ID: ${item['productoId']})");
        continue;
      }
      final stock = (producto['stock'] as num?)?.toInt() ?? 0;
      if (stock < (item['cantidad'] as num)) {
        productosAgotados.add(
            "${producto['nombre']} (Stock: $stock / Necesita: ${item['cantidad']})");
      }
    }
    if (productosAgotados.isNotEmpty) {
      _mostrarAlertaStockInsuficiente(productosAgotados);
      return;
    }

    final double total =
        _carrito.fold(0.0, (sum, i) => sum + (i['subtotal'] as num).toDouble());

    try {
      final ventaId = await dbService.insertVentaBase({
        'clienteId': _clienteSeleccionado?.id,
        'fecha': DateTime.now().toIso8601String(),
        'metodoPago': metodoSeleccionado ?? 'Efectivo',
        'total': total, // también podrías setear 0 y luego updateVentaTotal
      });

      for (var i in _carrito) {
        await dbService.insertItemVenta({
          'ventaId': ventaId,
          'productoId': i['productoId'],
          'cantidad': i['cantidad'],
          'precio_unitario': (i['precioUnit'] as num).toDouble(), // snapshot
          'costo_unitario': (i['costoUnit'] as num).toDouble(), // snapshot
          'subtotal': (i['subtotal'] as num).toDouble(),
        });
      }

      if (metodoSeleccionado == 'Fiado' && _clienteSeleccionado != null) {
        await dbService.insertDeuda({
          'clienteId': _clienteSeleccionado!.id,
          'monto': total,
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'Pendiente',
          'descripcion': 'Venta fiada',
        });
      }

      setState(() {
        _carrito.clear();
        _ventasFuture = dbService.getVentas();
      });

      Navigator.pop(context); // cierra el bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Venta registrada correctamente!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: ${e.toString()}")),
      );
    }
  }

  /// Dialogo Nuevo Cliente
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

  /// Filtros
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
                        final cliente =
                            (venta['clienteNombre']?.toString().isNotEmpty ??
                                    false)
                                ? venta['clienteNombre']
                                : 'Consumidor Final';
                        return Card(
                          child: ListTile(
                            title: Text("Venta #${venta['id']} - $cliente"),
                            subtitle: Text(
                                "Total: ${_money(venta['total'])} - Método: ${venta['metodoPago']}"),
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

  void _mostrarAlertaStockInsuficiente(List<String> productos) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚠️ Stock insuficiente"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "No se puede procesar la venta. Revisa estos productos:"),
            const SizedBox(height: 10),
            ...productos.map((p) => Text("• $p")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }
}
