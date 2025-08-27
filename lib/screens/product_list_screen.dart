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
                              // Reduce card height now that we show less content
                              mainAxisExtent: 110,
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Stack(
                                      children: [
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              p['nombre'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Precio: ${_money(precio)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: Text(
                                                    p['descripcion'] ?? '',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: widget.selectMode
                                                ? ((sinStock || inactivo)
                                                    ? null
                                                    : () => Navigator.pop(
                                                        context, p))
                                                : () =>
                                                    _mostrarDetallesProducto(p),
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
                                            top: 0,
                                            right: 0,
                                            child: _chip('SIN STOCK',
                                                Colors.red.shade700),
                                          ),
                                        if (inactivo)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            child: _chip('INACTIVO',
                                                Colors.grey.shade700),
                                          ),
                                        if (utilidad < 0 && !inactivo)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
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

  void _mostrarDetallesProducto(Map<String, dynamic> p) {
    final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final costo = (p['costo_compra'] as num?)?.toDouble() ?? 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        p['nombre'] ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    if ((p['codigo'] ?? '').toString().isNotEmpty) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.qr_code),
                        title: const Text('Código'),
                        trailing: Text(p['codigo'].toString()),
                      ),
                      const Divider(),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_money),
                      title: const Text('Precio'),
                      trailing: Text(
                        _money(precio),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.monetization_on_outlined),
                      title: const Text('Costo'),
                      trailing: Text(_money(costo)),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('Stock'),
                      trailing: Text((p['stock'] ?? 0).toString()),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category),
                      title: const Text('Categoría'),
                      trailing:
                          Text(p['categoria_nombre'] ?? 'Sin categoría'),
                    ),
                    if ((p['descripcion'] ?? '').toString().isNotEmpty) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description),
                        title: const Text('Descripción'),
                        subtitle: Text(p['descripcion']),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
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
