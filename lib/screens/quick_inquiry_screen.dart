import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/db_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../widgets/artic_dialog.dart';
import '../widgets/artic_barcode_scanner.dart';

class QuickInquiryScreen extends StatefulWidget {
  final bool selectMode; // If true, allows returning the product to a sale flow
  const QuickInquiryScreen({super.key, this.selectMode = false});

  @override
  State<QuickInquiryScreen> createState() => _QuickInquiryScreenState();
}

class _QuickInquiryScreenState extends State<QuickInquiryScreen> {
  final DBService _dbService = DBService();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedProduct;
  bool _searching = false;

  List<Map<String, dynamic>> _inquiryCart = [];
  Map<String, dynamic>? _cartData;
  StreamSubscription? _dbSubscription;

  @override
  void initState() {
    super.initState();
    _loadCart();
    _dbSubscription = _dbService.onDatabaseChanged.listen((_) {
      _loadCart();
    });
    // Auto focus the input so hardware barcode scanner works immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    final dataStr = await _dbService.getCarritoTemporal();
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        final data = jsonDecode(dataStr);
        if (data is Map<String, dynamic> && data['carrito'] is List) {
          _cartData = data;
          _inquiryCart = List<Map<String, dynamic>>.from(
            (data['carrito'] as List).map((item) => Map<String, dynamic>.from(item)),
          );
        }
      } catch (_) {}
    } else {
      _inquiryCart = [];
      _cartData = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveCart() async {
    if (_inquiryCart.isEmpty) {
      await _dbService.clearCarritoTemporal();
      _cartData = null;
    } else {
      final subtotalCarrito = _inquiryCart.fold<double>(
        0.0,
        (sum, p) => sum + (p['subtotal'] as num).toDouble(),
      );
      
      final data = Map<String, dynamic>.from(_cartData ?? {});
      data['carrito'] = _inquiryCart;
      data['subtotal'] = subtotalCarrito;
      
      final valDesc = data['descuentoValor'] as num? ?? 0.0;
      final aplicarDescuento = data['aplicarDescuento'] as bool? ?? false;
      final tipoDescuento = data['tipoDescuento'] as String? ?? 'percentage';
      double descuentoMonto = 0.0;
      if (aplicarDescuento) {
        if (tipoDescuento == 'percentage') {
          descuentoMonto = subtotalCarrito * (valDesc / 100.0);
        } else {
          descuentoMonto = valDesc.toDouble();
        }
      }
      data['descuentoMonto'] = descuentoMonto;
      data['total'] = subtotalCarrito - descuentoMonto;
      
      _cartData = data;
      await _dbService.saveCarritoTemporal(jsonEncode(data));
    }
    _dbService.notifyDbChange();
    if (mounted) setState(() {});
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(',', '');
  }

  Future<void> _performSearch(String query) async {
    query = query.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedProduct = null;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      // Fetch all active products and search in-memory using accent-insensitive logic
      final allProds = await _dbService.getProductos(incluirInactivos: false);
      final normalizedQuery = _normalizeText(query);

      final matches = allProds.where((p) {
        final name = _normalizeText(p['nombre'] as String? ?? '');
        final code = _normalizeText(p['codigo'] as String? ?? '');
        final desc = _normalizeText(p['descripcion'] as String? ?? '');
        return name.contains(normalizedQuery) ||
            code.contains(normalizedQuery) ||
            desc.contains(normalizedQuery);
      }).toList();

      // Check if there is an exact barcode or code match
      final exactMatch = matches.firstWhere(
        (p) =>
            (p['codigo'] as String? ?? '').trim().toLowerCase() == query.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      setState(() {
        _searchResults = matches;
        if (exactMatch.isNotEmpty) {
          _selectedProduct = exactMatch;
          // Clear and refocus to allow next quick scan
          _searchCtrl.clear();
          _focusNode.requestFocus();
        } else if (matches.length == 1) {
          _selectedProduct = matches.first;
        } else {
          _selectedProduct = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en la búsqueda: $e')),
      );
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBgColor = isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.65);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black12;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Consulta Rápida',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ArticBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Search & Results
              Expanded(
                flex: 4,
                child: ArticContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Buscar o Escanear Producto',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _focusNode,
                              autofocus: true,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Ingresa nombre, código o escanea código de barras...',
                                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _performSearch('');
                                          _focusNode.requestFocus();
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) => _performSearch(val),
                              onSubmitted: (val) => _performSearch(val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0EA5E9), size: 20),
                            onPressed: () async {
                              final barcodeResult = await Navigator.push<String?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ArticBarcodeScanner(
                                    title: 'Escanear Producto',
                                  ),
                                ),
                              );
                              if (barcodeResult != null && barcodeResult.isNotEmpty) {
                                _searchCtrl.text = barcodeResult;
                                _performSearch(barcodeResult);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _searching
                            ? const Center(child: CircularProgressIndicator())
                            : _searchResults.isEmpty
                                ? Center(
                                    child: Text(
                                      _searchCtrl.text.isEmpty
                                          ? 'Listo para escanear o buscar'
                                          : 'No se encontraron productos',
                                      style: GoogleFonts.manrope(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _searchResults.length,
                                    separatorBuilder: (_, __) => Divider(color: borderColor),
                                    itemBuilder: (context, index) {
                                      final p = _searchResults[index];
                                      final isSelected = _selectedProduct?['id'] == p['id'];
                                      return ListTile(
                                        selected: isSelected,
                                        selectedTileColor: isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.black.withOpacity(0.05),
                                        title: Text(
                                          p['nombre'] ?? '',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Cód: ${p['codigo'] ?? '—'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                        trailing: Text(
                                          formatCurrency((p['precio_venta'] as num?)?.toDouble() ?? 0.0),
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() => _selectedProduct = p);
                                          _focusNode.requestFocus();
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right Column: Detail View
              Expanded(
                flex: 5,
                child: _selectedProduct == null
                    ? ArticContainer(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 64,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Selecciona un producto para ver sus detalles',
                                style: GoogleFonts.manrope(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildDetailCard(context, _selectedProduct!, isDark, cardBgColor, borderColor, textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    Map<String, dynamic> p,
    bool isDark,
    Color cardBgColor,
    Color borderColor,
    Color textColor,
  ) {
    final stock = (p['stock'] as num?)?.toInt() ?? 0;
    final price = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final int productId = p['id'] as int;
    final int cartIndex = _inquiryCart.indexWhere((item) => item['productoId'] == productId);
    final bool isInCart = cartIndex != -1;
    final int currentCartQty = isInCart ? (_inquiryCart[cartIndex]['cantidad'] as num).toInt() : 0;

    // Standardized Stock Status
    Color stockColor = Colors.green;
    String stockLabel = 'Healthy (Stock Óptimo)';
    if (stock <= 0) {
      stockColor = Colors.red;
      stockLabel = 'None (Sin Stock)';
    } else if (stock <= 10) {
      stockColor = Colors.amber;
      stockLabel = 'Low (Stock Bajo)';
    }

    return ArticContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.1) : const Color(0xFF0284C7).withOpacity(0.1),
                child: Text(
                  (p['nombre'] as String? ?? 'P').isNotEmpty
                      ? (p['nombre'] as String)[0].toUpperCase()
                      : 'P',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nombre'] ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (p['categoria_nombre'] != null)
                      Text(
                        p['categoria_nombre']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          // Product Codes
          _buildInfoRow('Código de Barras', p['codigo'] ?? '—', isDark),
          _buildInfoRow('Descripción', p['descripcion'] ?? 'Sin descripción', isDark),
          const SizedBox(height: 24),
          // Price
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PRECIO DE VALTAS / VENTA',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(price),
                  style: GoogleFonts.manrope(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stock indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: stockColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stockColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: stockColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: stockColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Actual: $stock unidades',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        stockLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (widget.selectMode && stock > 0) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(
                'Agregar a Venta Directa',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () {
                Navigator.pop(context, p);
              },
            ),
          ] else ...[
            if (stock <= 0) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.remove_shopping_cart),
                label: Text(
                  'Sin Stock',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: null,
              ),
            ] else if (isInCart) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "En el carrito:",
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 24),
                          color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                          onPressed: () async {
                            final item = _inquiryCart[cartIndex];
                            final int currentQty = (item['cantidad'] as num).toInt();
                            if (currentQty > 1) {
                              item['cantidad'] = currentQty - 1;
                              item['subtotal'] = (item['precioUnit'] as double) * (currentQty - 1);
                            } else {
                              _inquiryCart.removeAt(cartIndex);
                            }
                            await _saveCart();
                          },
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$currentCartQty',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 24),
                          color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                          onPressed: () async {
                            final item = _inquiryCart[cartIndex];
                            final int currentQty = (item['cantidad'] as num).toInt();
                            if (currentQty < stock) {
                              item['cantidad'] = currentQty + 1;
                              item['subtotal'] = (item['precioUnit'] as double) * (currentQty + 1);
                              await _saveCart();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Solo hay $stock unidades disponibles')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  'Agregar al Carrito',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () async {
                  final double precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
                  final double costo = (p['costo_compra'] as num?)?.toDouble() ?? 0.0;
                  _inquiryCart.add({
                    'productoId': productId,
                    'nombre': p['nombre'],
                    'codigo': p['codigo'],
                    'precioUnit': precio,
                    'costoUnit': costo,
                    'cantidad': 1,
                    'subtotal': precio,
                    'stockDisponible': stock,
                    'imageUrl': p['imageUrl'],
                  });
                  await _saveCart();
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
