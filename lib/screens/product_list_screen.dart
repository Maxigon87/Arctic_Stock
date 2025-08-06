import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import '../services/db_service.dart';

class ProductListScreen extends StatefulWidget {
  final bool
      selectMode; // ✅ si true, permite seleccionar producto y devolverlo a la pantalla anterior

  const ProductListScreen({Key? key, this.selectMode = false})
      : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final DBService db = DBService();
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> categorias = [];
  int? selectedCategoriaId;
  String searchQuery = "";
  bool _mostrarSoloAgotados = false;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
    _loadProductos();
  }

  Future<void> _loadCategorias() async {
    categorias = await db.getAllCategorias();
    setState(() {});
  }

  Future<void> _loadProductos() async {
    final data = await db.getProductos(
      search: searchQuery,
      categoriaId: selectedCategoriaId,
      soloAgotados: _mostrarSoloAgotados, // ✅ se filtran si está activo
    );
    setState(() => productos = data);
  }

  /// ✅ Diálogo para agregar un producto
  void _showAddDialog() {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    int? catSeleccionada;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Agregar Producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: precioCtrl,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: "Categoría"),
                  value: catSeleccionada,
                  items: categorias
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nombre']),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setLocalState(() => catSeleccionada = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  final precio = double.tryParse(precioCtrl.text) ?? -1;
                  if (nombre.isEmpty || precio <= 0) return;

                  await db.insertProducto({
                    'nombre': nombre,
                    'precio': precio,
                    'categoria_id': catSeleccionada,
                  });

                  Navigator.pop(ctx);
                  _loadProductos();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ✅ Diálogo para editar producto
  void _showEditDialog(Map<String, dynamic> producto) {
    final nombreCtrl = TextEditingController(text: producto['nombre']);
    final precioCtrl =
        TextEditingController(text: producto['precio'].toString());
    int? catSeleccionada = producto['categoria_id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Editar Producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(
                    controller: precioCtrl,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: "Categoría"),
                  value: catSeleccionada,
                  items: categorias
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nombre']),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setLocalState(() => catSeleccionada = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  final precio = double.tryParse(precioCtrl.text) ?? 0;
                  if (nombre.isEmpty || precio <= 0) return;

                  await db.updateProducto({
                    'nombre': nombre,
                    'precio': precio,
                    'categoria_id': catSeleccionada,
                  }, producto['id']);

                  Navigator.pop(ctx);
                  _loadProductos();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteProducto(int id) async {
    await db.deleteProducto(id);
    _loadProductos();
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                  labelText: "Buscar producto", prefixIcon: Icon(Icons.search)),
              onChanged: (val) {
                searchQuery = val;
                _loadProductos();
              },
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: selectedCategoriaId,
            hint: const Text("Categoría"),
            items: categorias
                .map((c) => DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(c['nombre']),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => selectedCategoriaId = value);
              _loadProductos();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Seleccionar Producto' : 'Productos'),
        actions: [
          IconButton(
            tooltip: _mostrarSoloAgotados
                ? 'Mostrar todos los productos'
                : 'Mostrar solo sin stock',
            icon: Icon(
              _mostrarSoloAgotados
                  ? Icons.list_alt
                  : Icons.warning_amber_rounded,
              color: _mostrarSoloAgotados ? Colors.teal : Colors.redAccent,
            ),
            onPressed: () {
              setState(() {
                _mostrarSoloAgotados = !_mostrarSoloAgotados;
              });
              _loadProductos();
            },
          ),
        ],
      ),
      body: ArticBackground(
        child: ArticContainer(
          child: Column(
            children: [
              _buildFiltros(),
              Expanded(
                child: productos.isEmpty
                    ? const Center(child: Text('No hay productos'))
                    : ListView.builder(
                        itemCount: productos.length,
                        itemBuilder: (ctx, i) {
                          final p = productos[i];
                          final sinStock = (p['stock'] ?? 0) <= 0;

                          return Opacity(
                            opacity: sinStock ? 0.5 : 1.0,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: sinStock
                                      ? Colors.red
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ListTile(
                                    title: Text(p['nombre']),
                                    subtitle: Text(
                                      'Precio: \$${p['precio']} | '
                                      'Stock: ${p['stock'] ?? 0} | '
                                      'Categoría: ${p['categoria_nombre'] ?? 'Sin categoría'}',
                                      style: TextStyle(
                                        color: sinStock ? Colors.red : null,
                                        fontWeight: sinStock
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    onTap: widget.selectMode
                                        ? (sinStock
                                            ? null
                                            : () => Navigator.pop(context, p))
                                        : null,
                                    trailing: widget.selectMode
                                        ? null
                                        : PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'edit') {
                                                _showEditDialog(p);
                                              }
                                              if (value == 'delete') {
                                                _deleteProducto(p['id']);
                                              }
                                              if (value == 'addStock') {
                                                final cantidad =
                                                    await _showAddStockDialog(
                                                        context);
                                                if (cantidad != null &&
                                                    cantidad > 0) {
                                                  await DBService()
                                                      .incrementarStock(
                                                          p['id'], cantidad);
                                                  _loadProductos();
                                                }
                                              }
                                              if (value == 'removeStock') {
                                                final cantidad =
                                                    await _showRemoveStockDialog(
                                                        context,
                                                        p['stock'] ?? 0);
                                                if (cantidad != null &&
                                                    cantidad > 0) {
                                                  if ((p['stock'] ?? 0) >=
                                                      cantidad) {
                                                    await DBService()
                                                        .decrementarStock(
                                                            p['id'], cantidad);
                                                    _loadProductos();
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              "No puedes restar más de lo disponible")),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Editar')),
                                              PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Eliminar')),
                                              PopupMenuItem(
                                                  value: 'addStock',
                                                  child: Text('Agregar Stock')),
                                              PopupMenuItem(
                                                  value: 'removeStock',
                                                  child: Text('Restar Stock')),
                                            ],
                                          ),
                                  ),
                                  if (sinStock)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          "SIN STOCK",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.selectMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<int?> _showAddStockDialog(BuildContext context) async {
    final TextEditingController _cantidadController = TextEditingController();

    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Agregar Stock"),
          content: TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Cantidad a agregar"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                final cantidad = int.tryParse(_cantidadController.text);
                Navigator.pop(context, cantidad);
              },
              child: const Text("Agregar"),
            ),
          ],
        );
      },
    );
  }

  Future<int?> _showRemoveStockDialog(
      BuildContext context, int stockActual) async {
    final TextEditingController _cantidadController = TextEditingController();

    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Restar Stock"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Stock actual: $stockActual"),
              const SizedBox(height: 8),
              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Cantidad a restar"),
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
                final cantidad = int.tryParse(_cantidadController.text);
                Navigator.pop(context, cantidad);
              },
              child: const Text("Restar"),
            ),
          ],
        );
      },
    );
  }
}
