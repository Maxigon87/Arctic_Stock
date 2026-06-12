import 'package:artic_stock/widgets/artic_background.dart';
import 'package:artic_stock/widgets/artic_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
// En TODAS las pantallas, unifica así:
import '../services/db_service.dart';
import '../utils/currency_formatter.dart';

import 'product_form.dart';
import '../widgets/artic_dialog.dart';

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
  bool _mostrarInactivos = false;
  String _sortBy = 'nombre_asc';

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
      incluirInactivos: _mostrarInactivos,
      orderBy: _sortBy,
    );
    setState(() => productos = data);
  }

  Future<String?> _mostrarDialogoNuevaCategoria() async {
    final TextEditingController controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showArticDialog<String>(
      context: context,
      builder: (context) {
        return ArticDialogCard(
          title: "Nueva Categoría",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancelar",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Guardar"),
            ),
          ],
          child: TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Nombre de la categoría",
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
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

  Widget _buildFiltros(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Buscar producto...",
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black54),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    searchQuery = val;
                    _loadProductos();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedCategoriaId,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    hint: Text("Categoría", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text("Todas las categorías", style: TextStyle(fontSize: 13)),
                      ),
                      ...categorias.map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nombre'], style: const TextStyle(fontSize: 13)),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => selectedCategoriaId = value);
                      _loadProductos();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
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
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text('Ver inactivos', style: TextStyle(fontSize: 12)),
                selected: _mostrarInactivos,
                onSelected: (v) {
                  setState(() => _mostrarInactivos = v);
                  _loadProductos();
                },
                avatar: const Icon(Icons.inventory_2_outlined, size: 14),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Solo sin stock', style: TextStyle(fontSize: 12)),
                selected: _mostrarSoloAgotados,
                onSelected: (v) {
                  setState(() => _mostrarSoloAgotados = v);
                  _loadProductos();
                },
                avatar: const Icon(Icons.warning_amber_rounded, size: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 'nombre_asc', child: Text("Nombre: A-Z", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'precio_asc', child: Text("Precio: Menor a Mayor", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'precio_desc', child: Text("Precio: Mayor a Menor", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'stock_asc', child: Text("Stock: Menor a Mayor", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'stock_desc', child: Text("Stock: Mayor a Menor", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'popularidad', child: Text("Popularidad (Más vendidos)", style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortBy = value);
                        _loadProductos();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget mainWidget = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.selectMode
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Seleccionar Producto',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.selectMode) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Productos e Inventario',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _goToCreate,
                    icon: const Icon(Icons.add),
                    label: const Text("Nuevo Producto"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: ArticContainer(
                maxWidth: double.infinity,
                child: Column(
                  children: [
                    _buildFiltros(isDark),
                    Expanded(
                      child: productos.isEmpty
                          ? const Center(child: Text('No hay productos'))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                int crossAxisCount = (constraints.maxWidth / 320).floor();
                                if (crossAxisCount < 1) crossAxisCount = 1;
                                return GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisExtent: 145,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                                  itemCount: productos.length,
                                  itemBuilder: (ctx, i) {
                                    final p = productos[i];
                                    final id = p['id'] as int;
                                    final sinStock = (p['stock'] ?? 0) <= 0;
                                    final inactivo = (p['activo'] ?? 1) == 0;

                                    final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
                                    final costo = (p['costo_compra'] as num?)?.toDouble() ?? 0.0;
                                    final utilidad = (precio - costo);
                                    final rentabilidad = costo > 0 ? (utilidad / costo) * 100 : 0.0;
                                    final nombre = p['nombre'] ?? '';
                                    final desc = p['descripcion'] ?? '';

                                    Color stockBadgeColor = Colors.green;
                                    if (sinStock) {
                                      stockBadgeColor = Colors.red;
                                    } else if ((p['stock'] ?? 0) <= 5) {
                                      stockBadgeColor = Colors.amber;
                                    }

                                    return InkWell(
                                      onTap: widget.selectMode
                                          ? ((sinStock || inactivo) ? null : () => Navigator.pop(context, p))
                                          : () => _mostrarDetallesProducto(p),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Opacity(
                                        opacity: inactivo ? 0.6 : 1.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.45),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: inactivo
                                                  ? Colors.grey.withOpacity(0.2)
                                                  : (sinStock
                                                      ? Colors.red.withOpacity(0.3)
                                                      : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06))),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                              child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.1) : const Color(0xFF0284C7).withOpacity(0.1),
                                                          child: Text(
                                                            nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                nombre,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 13,
                                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                                ),
                                                              ),
                                                              Text(
                                                                desc.isNotEmpty ? desc : 'Sin descripción',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: isDark ? Colors.white60 : Colors.black54,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (!widget.selectMode)
                                                          PopupMenuButton<String>(
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            icon: Icon(Icons.more_vert, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                                                            onSelected: (value) async {
                                                              if (value == 'edit') {
                                                                await _goToEdit(p);
                                                              }
                                                              if (value == 'delete') {
                                                                await _deleteProducto(id);
                                                              }
                                                              if (value == 'restore') {
                                                                await _restoreProducto(id);
                                                              }
                                                            },
                                                            itemBuilder: (context) => [
                                                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                                              if (inactivo)
                                                                const PopupMenuItem(value: 'restore', child: Text('Restaurar'))
                                                              else
                                                                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                    const Spacer(),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text("Precio", style: TextStyle(fontSize: 9, color: isDark ? Colors.white60 : Colors.black45)),
                                                            Text(
                                                              formatCurrency(precio),
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                                color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Text("Margen/Rent.", style: TextStyle(fontSize: 9, color: isDark ? Colors.white60 : Colors.black45)),
                                                            Text(
                                                              "${formatCurrency(utilidad)} (${rentabilidad.toStringAsFixed(0)}%)",
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 10,
                                                                color: utilidad >= 0 ? Colors.green : Colors.red,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: stockBadgeColor.withOpacity(0.12),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            sinStock
                                                                ? "Agotado"
                                                                : "Stock: ${p['stock']}",
                                                            style: TextStyle(
                                                              color: stockBadgeColor,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        if (!widget.selectMode && !inactivo)
                                                          Row(
                                                            children: [
                                                              IconButton(
                                                                visualDensity: VisualDensity.compact,
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(),
                                                                icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                                                                onPressed: (p['stock'] ?? 0) > 0
                                                                    ? () async {
                                                                        await db.decrementarStock(id, 1);
                                                                        _loadProductos();
                                                                      }
                                                                    : null,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              IconButton(
                                                                visualDensity: VisualDensity.compact,
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(),
                                                                icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.green),
                                                                onPressed: () async {
                                                                  await db.incrementarStock(id, 1);
                                                                  _loadProductos();
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
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
          ],
        ),
      ),
    );

    if (widget.selectMode) {
      return ArticBackground(
        child: mainWidget,
      );
    }
    return mainWidget;
  }

  void _mostrarDetallesProducto(Map<String, dynamic> p) {
    final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final costo = (p['costo_compra'] as num?)?.toDouble() ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showArticDialog(
      context: context,
      builder: (ctx) {
        return ArticDialogCard(
          title: p['nombre'] ?? '',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((p['codigo'] ?? '').toString().isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tag, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                  title: Text('Código Interno', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  trailing: Text(p['codigo'].toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                ),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
              ],
              if ((p['codigoBarras'] ?? '').toString().isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.qr_code, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                  title: Text('Código de Barras', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  trailing: Text(p['codigoBarras'].toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                ),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.attach_money, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                title: Text('Precio', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                trailing: Text(
                  formatCurrency(precio),
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                ),
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.monetization_on_outlined, color: Colors.green),
                title: Text('Costo', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                trailing: Text(formatCurrency(costo), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined, color: Colors.amber),
                title: Text('Stock', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                trailing: Text((p['stock'] ?? 0).toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.category, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                title: Text('Categoría', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                trailing: Text(p['categoria_nombre'] ?? 'Sin categoría', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              ),
              if ((p['descripcion'] ?? '').toString().isNotEmpty) ...[
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.description, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                  title: Text('Descripción', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  subtitle: Text(p['descripcion'], style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<int?> _showAddStockDialog(BuildContext context) async {
    final TextEditingController cantidadController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showArticDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return ArticDialogCard(
          title: "Agregar Stock",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                "Cancelar",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
          child: TextField(
            controller: cantidadController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Cantidad a agregar",
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        );
      },
    );
  }

  Future<int?> _showRemoveStockDialog(
      BuildContext context, int stockActual) async {
    final TextEditingController cantidadController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showArticDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return ArticDialogCard(
          title: "Restar Stock",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                "Cancelar",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Stock actual: $stockActual",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Cantidad a restar",
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
