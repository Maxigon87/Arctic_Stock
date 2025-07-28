import 'package:flutter/material.dart';
import '../services/db_service.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final DBService db = DBService();
  List<Map<String, dynamic>> productos = [];

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    final data = await db.getProductos();
    setState(() => productos = data);
  }

  void _showAddDialog() {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              final precio =
                  double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? -1;

              if (nombre.isEmpty || precio <= 0) {
                print('⚠️ Datos inválidos, no se insertó');
                return;
              }

              try {
                await db.insertProducto({'nombre': nombre, 'precio': precio});
                Navigator.pop(ctx);
                _loadProductos();
              } catch (e) {
                print('🔥 Error al insertar producto: $e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ======= MÉTODO PARA EDITAR PRODUCTO =======
  void _showEditDialog(Map<String, dynamic> producto) {
    final nombreCtrl = TextEditingController(text: producto['nombre']);
    final precioCtrl = TextEditingController(
      text: producto['precio'].toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Producto'),
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
              final precio = double.tryParse(precioCtrl.text) ?? 0;

              if (nombre.isNotEmpty && precio > 0) {
                await db.updateProducto({
                  'nombre': nombre,
                  'precio': precio,
                }, producto['id']);
                Navigator.pop(ctx);
                _loadProductos(); // refresca la lista
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ======= MÉTODO PARA ELIMINAR PRODUCTO =======
  Future<void> _deleteProducto(int id) async {
    await db.deleteProducto(id);
    _loadProductos(); // refresca lista después de eliminar
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: productos.isEmpty
          ? const Center(child: Text('No hay productos'))
          : ListView.builder(
              itemCount: productos.length,
              itemBuilder: (ctx, i) {
                final p = productos[i];
                return Card(
                  child: ListTile(
                    title: Text(p['nombre']),
                    subtitle: Text('Precio: \$${p['precio']}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _showEditDialog(p);
                        if (value == 'delete') _deleteProducto(p['id']);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
