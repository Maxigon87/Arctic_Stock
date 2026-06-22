import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/artic_dialog.dart';
import '../../../widgets/artic_barcode_scanner.dart';

class MobileProductsScreen extends StatefulWidget {
  const MobileProductsScreen({super.key});

  @override
  State<MobileProductsScreen> createState() => _MobileProductsScreenState();
}

class _MobileProductsScreenState extends State<MobileProductsScreen> {
  final DBService _dbService = DBService();
  late StreamSubscription _dbSub;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _productos = [];
  String _searchQuery = '';
  bool _loading = true;
  String _sortBy = 'nombre_asc'; // 👈 NUEVO

  @override
  void initState() {
    super.initState();
    _loadProductos();
    _dbSub = _dbService.onDatabaseChanged.listen((_) => _loadProductos());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    try {
      final list = await _dbService.getProductos(orderBy: _sortBy); // 👈
      // Filter out inactive products if necessary, or just keep active ones
      final active = list.where((p) => p['activo'] == 1).toList();
      if (mounted) {
        setState(() {
          _productos = active;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _productos.where((p) {
      final name = (p['nombre'] as String? ?? '').toLowerCase();
      final code = (p['codigo'] as String? ?? '').toLowerCase();
      final desc = (p['descripcion'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || code.contains(query) || desc.contains(query);
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final searchBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fieldFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Productos',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 20, color: textColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0EA5E9)),
            tooltip: 'Escanear código',
            onPressed: () async {
              final scannedCode = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ArticBarcodeScanner(
                    title: 'Buscar por Código de Barras',
                  ),
                ),
              );
              if (scannedCode != null && scannedCode.isNotEmpty) {
                setState(() {
                  _searchCtrl.text = scannedCode;
                  _searchQuery = scannedCode;
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : Column(
              children: [
                // Search Bar Container
                Container(
                  color: searchBgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar producto...',
                            hintStyle: GoogleFonts.manrope(color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: fieldFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          style: GoogleFonts.manrope(fontSize: 14, color: textColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: fieldFillColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: searchBgColor,
                            icon: const Icon(Icons.sort, color: Color(0xFF64748B), size: 18),
                            style: GoogleFonts.manrope(fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(value: 'nombre_asc', child: Text("A-Z")),
                              DropdownMenuItem(value: 'precio_asc', child: Text("Precio \$")),
                              DropdownMenuItem(value: 'precio_desc', child: Text("Precio \$\$\$")),
                              DropdownMenuItem(value: 'stock_asc', child: Text("Stock 📉")),
                              DropdownMenuItem(value: 'stock_desc', child: Text("Stock 📈")),
                              DropdownMenuItem(value: 'popularidad', child: Text("Popular")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _sortBy = val;
                                  _loading = true;
                                });
                                _loadProductos();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadProductos,
                    color: const Color(0xFF0EA5E9),
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 600;
                              if (isWide) {
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 3.5,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) => _buildProductCard(filtered[idx]),
                                );
                              } else {
                                return ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildProductCard(filtered[idx]),
                                );
                              }
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: _showAddProductoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddProductoDialog() {
    final nombreCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');

    showArticDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final style = GoogleFonts.manrope(color: isDark ? Colors.white : const Color(0xFF0F172A));
        final labelStyle = GoogleFonts.manrope(color: isDark ? Colors.white60 : const Color(0xFF64748B));
        
        return ArticDialogCard(
          title: 'Nuevo Producto',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.manrope(color: isDark ? Colors.white60 : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nombreCtrl.text.trim();
                final precioVal = double.tryParse(precioCtrl.text.trim());
                final stockVal = int.tryParse(stockCtrl.text.trim()) ?? 0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                if (precioVal == null || precioVal < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El precio debe ser un número válido >= 0')),
                  );
                  return;
                }

                try {
                  await _dbService.insertProducto({
                    'nombre': name,
                    'codigo': codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(),
                    'precio_venta': precioVal,
                    'stock': stockVal,
                    'costo_compra': 0.0,
                    'categoria_id': null,
                  });
                  Navigator.pop(ctx);
                  _loadProductos();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al crear producto: $e')),
                  );
                }
              },
              child: Text('Guardar', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                style: style,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  labelStyle: labelStyle,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codigoCtrl,
                style: style,
                decoration: InputDecoration(
                  labelText: 'Código / Cód. Barras',
                  labelStyle: labelStyle,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: style,
                decoration: InputDecoration(
                  labelText: 'Precio de Venta *',
                  labelStyle: labelStyle,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                style: style,
                decoration: InputDecoration(
                  labelText: 'Stock Inicial',
                  labelStyle: labelStyle,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 60, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Intenta con otros términos de búsqueda.'
                  : 'Registra productos en la versión de escritorio para comenzar.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustStockDialog(Map<String, dynamic> prod) {
    final int productId = prod['id'] as int;
    final String name = prod['nombre'] as String? ?? 'Producto';
    final int currentStock = (prod['stock'] as num?)?.toInt() ?? 0;
    final String code = prod['codigo'] as String? ?? '';
    final String barcode = prod['codigoBarras'] as String? ?? '';
    
    int tempStock = currentStock;
    final controller = TextEditingController(text: currentStock.toString());
    
    showArticDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ArticDialogCard(
              title: 'Ajustar Stock',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await _dbService.setStockConAjuste(productId, tempStock);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Stock actualizado correctamente', style: GoogleFonts.manrope()),
                          backgroundColor: const Color(0xFF22C55E),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar stock: $e', style: GoogleFonts.manrope()),
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Guardar',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(fontSize: 15, color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                  if (code.isNotEmpty || barcode.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    if (code.isNotEmpty)
                      Text(
                        'Cód. Interno: $code',
                        style: GoogleFonts.manrope(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                      ),
                    if (barcode.isNotEmpty)
                      Text(
                        'Cód. Barras: $barcode',
                        style: GoogleFonts.manrope(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (tempStock > 0) {
                            setDialogState(() {
                              tempStock--;
                              controller.text = tempStock.toString();
                            });
                          }
                        },
                        icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.white60 : const Color(0xFF64748B), size: 32),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 0) {
                              tempStock = parsed;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            tempStock++;
                            controller.text = tempStock.toString();
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0EA5E9), size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> prod) {
    final name = prod['nombre'] as String? ?? 'Producto sin nombre';
    final code = prod['codigo'] as String? ?? '';
    final barcode = prod['codigoBarras'] as String? ?? '';
    final price = (prod['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final stock = (prod['stock'] as num?)?.toInt() ?? 0;

    Color stockColor = const Color(0xFF22C55E); // Green
    String stockStatus = 'Stock correcto';
    if (stock == 0) {
      stockColor = const Color(0xFFEF4444); // Red
      stockStatus = 'Sin stock';
    } else if (stock <= 5) {
      stockColor = const Color(0xFFF59E0B); // Yellow
      stockStatus = 'Stock bajo';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final innerBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => _showAdjustStockDialog(prod),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: innerBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0EA5E9), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (code.isNotEmpty || barcode.isNotEmpty) ...[
                    Text(
                      code == barcode
                          ? 'Cód: $code'
                          : 'Cód: $code | Barras: $barcode',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: stockColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$stock unidades ($stockStatus)',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatCurrency(price),
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
