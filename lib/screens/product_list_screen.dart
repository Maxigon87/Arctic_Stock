import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import '../services/db_service.dart';

// 🚩 importa tu formulario
import 'product_form.dart'; // <-- ajusta la ruta si está en otra carpeta

class ProductListScreen extends StatefulWidget {
  final bool selectMode; // si true, permite seleccionar producto y devolverlo

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
      soloAgotados: _mostrarSoloAgotados,
    );
    setState(() => productos = data);
  }

  Future<String?> _mostrarDialogoNuevaCategoria() async {
    final TextEditingController _controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Nueva Categoría"),
          content: TextField(
            controller: _controller,
            decoration:
                const InputDecoration(labelText: "Nombre de la categoría"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _controller.text.trim());
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  // 🔁 Navega al formulario para CREAR
  Future<void> _goToCreate() async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductForm()),
    );
    if (ok == true) _loadProductos();
  }

  // 🔁 Navega al formulario para EDITAR
  Future<void> _goToEdit(Map<String, dynamic> p) async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductForm(initial: p)),
    );
    if (ok == true) _loadProductos();
  }

  Future<void> _deleteProducto(int id) async {
    await db.deleteProducto(id);
    _loadProductos();
  }

  String _money(dynamic n) {
    if (n == null) return "\$0.00";
    final d = (n as num).toDouble();
    return "\$${d.toStringAsFixed(2)}";
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Buscar producto",
                prefixIcon: Icon(Icons.search),
              ),
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
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva categoría',
            onPressed: () async {
              final nuevoNombre = await _mostrarDialogoNuevaCategoria();
              if (nuevoNombre != null && nuevoNombre.trim().isNotEmpty) {
                final nuevaId = await db.insertCategoria(nuevoNombre.trim());
                await _loadCategorias();
                setState(() => selectedCategoriaId = nuevaId);
                _loadProductos();
              }
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

                          final precio =
                              (p['precio_venta'] as num?)?.toDouble() ??
                                  0.0; // ⬅️ nuevo campo
                          final costo =
                              (p['costo_compra'] as num?)?.toDouble() ??
                                  0.0; // ⬅️ nuevo campo
                          final utilidad = (precio - costo);

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
                                    title: Text(
                                      p['nombre'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((p['codigo'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text('Código: ${p['codigo']}'),
                                        Text(
                                          'Precio: ${_money(precio)}  |  Costo: ${_money(costo)}  |  Stock: ${p['stock'] ?? 0}',
                                          style: TextStyle(
                                            color: utilidad < 0
                                                ? Colors.red
                                                : null,
                                            fontWeight: utilidad < 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        Text(
                                            'Categoría: ${p['categoria_nombre'] ?? 'Sin categoría'}'),
                                        if ((p['descripcion'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text(
                                            p['descripcion'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontStyle: FontStyle.italic),
                                          ),
                                      ],
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
                                                // ir al formulario con datos cargados
                                                await _goToEdit(p);
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
                                                            "No puedes restar más de lo disponible"),
                                                      ),
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
                                  if (utilidad < 0)
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.warning_amber_rounded,
                                              size: 16, color: Colors.amber),
                                          SizedBox(width: 4),
                                          Text("Vendiendo con pérdida",
                                              style: TextStyle(fontSize: 12)),
                                        ],
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
              onPressed: _goToCreate,
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
