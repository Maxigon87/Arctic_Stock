import 'package:ArticStock/widgets/artic_background.dart';
import 'package:ArticStock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// En TODAS las pantallas, unifica así:
import '../Services/db_service.dart';

import 'product_form.dart';

class ProductListScreen extends StatefulWidget {
  final bool selectMode;

  const ProductListScreen({super.key, this.selectMode = false});

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
  bool _mostrarInactivos = false; // ⬅️ NUEVO

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
      incluirInactivos: _mostrarInactivos, // ⬅️ NUEVO
    );
    setState(() => productos = data);
  }

  Future<String?> _mostrarDialogoNuevaCategoria() async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Nueva Categoría"),
          content: TextField(
            controller: controller,
            decoration:
                const InputDecoration(labelText: "Nombre de la categoría"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goToCreate() async {
    final ok = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ProductForm()));
    if (ok == true) _loadProductos();
  }

  Future<void> _goToEdit(Map<String, dynamic> p) async {
    final ok = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ProductForm(initial: p)));
    if (ok == true) _loadProductos();
  }

  Future<void> _deleteProducto(int id) async {
    await db.deleteProducto(id); // soft-delete (activo=0)
    _loadProductos();
  }

  Future<void> _restoreProducto(int id) async {
    await db.activarProducto(id); // ⬅️ requiere el método de abajo en DBService
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
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
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
          FilterChip(
            label: const Text('Ver inactivos'),
            selected: _mostrarInactivos,
            onSelected: (v) {
              setState(() => _mostrarInactivos = v);
              _loadProductos();
            },
            avatar: const Icon(Icons.inventory_2_outlined),
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
                ? 'Mostrar todos'
                : 'Mostrar solo sin stock',
            icon: Icon(
              _mostrarSoloAgotados
                  ? Icons.list_alt
                  : Icons.warning_amber_rounded,
              color: _mostrarSoloAgotados ? Colors.teal : Colors.redAccent,
            ),
            onPressed: () {
              setState(() => _mostrarSoloAgotados = !_mostrarSoloAgotados);
              _loadProductos();
            },
          ),
        ],
      ),
      body: ArticBackground(
        child: ArticContainer(
          maxWidth: double.infinity,
          child: Column(
            children: [
              _buildFiltros(),
              Expanded(
                child: productos.isEmpty
                    ? const Center(child: Text('No hay productos'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount =
                              (constraints.maxWidth / 400).floor();
                          if (crossAxisCount < 1) crossAxisCount = 1;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: productos.length,
                            itemBuilder: (ctx, i) {
                              final p = productos[i];
                              final sinStock = (p['stock'] ?? 0) <= 0;
                              final inactivo = (p['activo'] ?? 1) == 0;

                              final precio =
                                  (p['precio_venta'] as num?)?.toDouble() ??
                                      0.0;
                              final costo =
                                  (p['costo_compra'] as num?)?.toDouble() ??
                                      0.0;
                              final utilidad = (precio - costo);

                              return Opacity(
                                opacity: (sinStock || inactivo) ? 0.55 : 1.0,
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: inactivo
                                          ? Colors.grey
                                          : (sinStock
                                              ? Colors.red
                                              : Colors.transparent),
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
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontStyle:
                                                        FontStyle.italic),
                                              ),
                                          ],
                                        ),
                                        onTap: widget.selectMode
                                            ? ((sinStock || inactivo)
                                                ? null
                                                : () => Navigator.pop(
                                                    context, p))
                                            : null,
                                        trailing: widget.selectMode
                                            ? null
                                            : PopupMenuButton<String>(
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    await _goToEdit(p);
                                                  }
                                                  if (value == 'delete') {
                                                    await _deleteProducto(
                                                        p['id'] as int);
                                                  }
                                                  if (value == 'restore') {
                                                    await _restoreProducto(
                                                        p['id'] as int);
                                                  }
                                                  if (value == 'addStock') {
                                                    if (inactivo) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "No podés modificar stock de un producto inactivo.")),
                                                      );
                                                      return;
                                                    }
                                                    final cantidad =
                                                        await _showAddStockDialog(
                                                            context);
                                                    if (cantidad != null &&
                                                        cantidad > 0) {
                                                      await DBService()
                                                          .incrementarStock(
                                                              p['id'] as int,
                                                              cantidad);
                                                      _loadProductos();
                                                    }
                                                  }
                                                  if (value == 'removeStock') {
                                                    if (inactivo) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "No podés modificar stock de un producto inactivo.")),
                                                      );
                                                      return;
                                                    }
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
                                                                p['id']
                                                                    as int,
                                                                cantidad);
                                                        _loadProductos();
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                              content: Text(
                                                                  "No podés restar más de lo disponible")),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('Editar')),
                                                  if (inactivo)
                                                    const PopupMenuItem(
                                                        value: 'restore',
                                                        child:
                                                            Text('Restaurar'))
                                                  else
                                                    const PopupMenuItem(
                                                        value: 'delete',
                                                        child:
                                                            Text('Eliminar')),
                                                  const PopupMenuItem(
                                                      value: 'addStock',
                                                      child: Text(
                                                          'Agregar Stock')),
                                                  const PopupMenuItem(
                                                      value: 'removeStock',
                                                      child:
                                                          Text('Restar Stock')),
                                                ],
                                              ),
                                      ),
                                      if (sinStock)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: _chip('SIN STOCK',
                                              Colors.red.shade700),
                                        ),
                                      if (inactivo)
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: _chip('INACTIVO',
                                              Colors.grey.shade700),
                                        ),
                                      if (utilidad < 0 && !inactivo)
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: Row(
                                            children: const [
                                              Icon(
                                                  Icons.warning_amber_rounded,
                                                  size: 16,
                                                  color: Colors.amber),
                                              SizedBox(width: 4),
                                              Text("Vendiendo con pérdida",
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
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
      floatingActionButton: widget.selectMode
          ? null
          : FloatingActionButton(
              onPressed: _goToCreate,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Future<int?> _showAddStockDialog(BuildContext context) async {
    final TextEditingController cantidadController = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text("Agregar Stock"),
          content: TextField(
            controller: cantidadController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: "Cantidad a agregar"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                final cant = int.tryParse(cantidadController.text) ?? 0;
                if (cant <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ingrese una cantidad válida (> 0)')));
                } else {
                  Navigator.pop(dialogCtx, cant);
                }
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
    final TextEditingController cantidadController = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text("Restar Stock"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Stock actual: $stockActual"),
              const SizedBox(height: 8),
              TextField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: "Cantidad a restar"),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                final cant = int.tryParse(cantidadController.text) ?? 0;
                if (cant <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ingrese una cantidad válida (> 0)')));
                } else {
                  Navigator.pop(dialogCtx, cant);
                }
              },
              child: const Text("Restar"),
            ),
          ],
        );
      },
    );
  }
}
