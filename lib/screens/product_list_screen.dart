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
          title:
              Text(widget.selectMode ? 'Seleccionar Producto' : 'Productos')),
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
                          return Card(
                            child: ListTile(
                              title: Text(p['nombre']),
                              subtitle: Text(
                                  'Precio: \$${p['precio']} | Categoría: ${p['categoria_nombre'] ?? 'Sin categoría'}'),
                              onTap: widget.selectMode
                                  ? () => Navigator.pop(context,
                                      p) // ✅ Si está en modo selección, devuelve el producto
                                  : null,
                              trailing: widget.selectMode
                                  ? null
                                  : PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') _showEditDialog(p);
                                        if (value == 'delete')
                                          _deleteProducto(p['id']);
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Eliminar')),
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
}
