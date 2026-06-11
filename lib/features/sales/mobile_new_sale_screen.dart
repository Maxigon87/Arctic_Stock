import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/cliente.dart';
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';

class MobileNewSaleScreen extends StatefulWidget {
  const MobileNewSaleScreen({super.key});

  @override
  State<MobileNewSaleScreen> createState() => _MobileNewSaleScreenState();
}

class _MobileNewSaleScreenState extends State<MobileNewSaleScreen> {
  final DBService _dbService = DBService();

  // Step state
  int _currentStep = 0; // 0: Cliente, 1: Productos, 2: Pago

  // Sale Data
  Map<String, dynamic>? _selectedCliente; // null represents 'Consumidor Final'
  final List<Map<String, dynamic>> _cart = []; // Map keys: 'product', 'quantity', 'price'
  String _metodoPago = 'Efectivo'; // 'Efectivo', 'Debito', 'Credito', 'Transferencia', 'Fiado'

  // DB Lists
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _productos = [];
  String _clienteSearch = '';
  String _productoSearch = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final db = await _dbService.database;
      
      // Load Clientes
      final clis = await db.query('clientes', orderBy: 'nombre ASC');
      
      // Load Products
      final prods = await db.query('productos', where: 'activo = 1', orderBy: 'nombre ASC');

      setState(() {
        _clientes = clis;
        _productos = prods;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _subtotal {
    return _cart.fold<double>(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + (price * qty);
    });
  }

  void _addToCart(Map<String, dynamic> prod) {
    final stock = (prod['stock'] as num?)?.toInt() ?? 0;
    if (stock <= 0) {
      _showSnackbar('⚠️ Este producto no tiene stock disponible');
      return;
    }

    final existingIdx = _cart.indexWhere((item) => item['product']['id'] == prod['id']);
    
    // Check if adding exceeds stock
    int currentQty = 0;
    if (existingIdx != -1) {
      currentQty = _cart[existingIdx]['quantity'] as int;
    }

    if (currentQty + 1 > stock) {
      _showSnackbar('⚠️ No puedes agregar más unidades de las disponibles en stock ($stock)');
      return;
    }

    setState(() {
      if (existingIdx != -1) {
        _cart[existingIdx]['quantity'] = currentQty + 1;
      } else {
        _cart.add({
          'product': prod,
          'quantity': 1,
          'price': (prod['precio_venta'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });
    _showSnackbar('✅ ${prod['nombre']} agregado al carrito');
  }

  void _updateCartQuantity(int index, int newQty) {
    if (newQty <= 0) {
      setState(() {
        _cart.removeAt(index);
      });
      return;
    }

    final item = _cart[index];
    final prod = item['product'] as Map<String, dynamic>;
    final stock = (prod['stock'] as num?)?.toInt() ?? 0;

    if (newQty > stock) {
      _showSnackbar('⚠️ No puedes agregar más de $stock unidades (Límite de stock)');
      return;
    }

    setState(() {
      _cart[index]['quantity'] = newQty;
    });
  }

  Future<void> _finalizeSale() async {
    if (_cart.isEmpty) {
      _showSnackbar('⚠️ El carrito está vacío');
      return;
    }

    if (_metodoPago == 'Fiado' && _selectedCliente == null) {
      _showSnackbar('⚠️ Debes seleccionar un cliente para realizar una venta fiada');
      return;
    }

    setState(() => _loading = true);

    try {
      final total = _subtotal;
      
      // 1. Insert Sale
      final ventaId = await _dbService.insertVenta({
        'clienteId': _selectedCliente?['id'],
        'fecha': DateTime.now().toIso8601String(),
        'metodoPago': _metodoPago,
        'total': total,
      });

      // 2. Insert items and trigger stock decreases
      for (final item in _cart) {
        final prod = item['product'] as Map<String, dynamic>;
        final qty = item['quantity'] as int;
        final price = item['price'] as double;
        final cost = (prod['costo_compra'] as num?)?.toDouble() ?? 0.0;

        await _dbService.insertItemVenta({
          'ventaId': ventaId,
          'productoId': prod['id'],
          'cantidad': qty,
          'precio_unitario': price,
          'costo_unitario': cost,
          'subtotal': price * qty,
          'producto_nombre': prod['nombre'],
          'producto_descripcion': prod['descripcion'] ?? '',
          'producto_codigo': prod['codigo'] ?? '',
        });
      }

      // 3. If "Fiado", create debt
      if (_metodoPago == 'Fiado' && _selectedCliente != null) {
        await _dbService.insertDeuda({
          'clienteId': _selectedCliente!['id'],
          'monto': total,
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'Pendiente',
          'descripcion': 'Venta fiada (Mobile)',
          'ventaId': ventaId,
        });
      }

      _showSnackbar('🎉 ¡Venta registrada correctamente!');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnackbar('❌ Error al registrar venta: $e');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Nueva Venta',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : Column(
              children: [
                _buildStepProgress(),
                Expanded(
                  child: IndexedStack(
                    index: _currentStep,
                    children: [
                      _buildClienteStep(),
                      _buildProductosStep(),
                      _buildPagoStep(),
                    ],
                  ),
                ),
                _buildBottomSummary(),
              ],
            ),
    );
  }

  Widget _buildStepProgress() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepNode(0, 'Cliente', _currentStep >= 0),
          _buildStepLine(_currentStep >= 1),
          _buildStepNode(1, 'Productos', _currentStep >= 1),
          _buildStepLine(_currentStep >= 2),
          _buildStepNode(2, 'Pago', _currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, bool active) {
    final color = active ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0);
    final textColor = active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8);
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0EA5E9).withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: active ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
      ),
    );
  }

  void _showAddClienteDialog() {
    final nombreCtrl = TextEditingController();
    final dniCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Nuevo Cliente',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dniCtrl,
                decoration: InputDecoration(
                  labelText: 'DNI / CUIT',
                  labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: direccionCtrl,
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.manrope(color: const Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () async {
              final name = nombreCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio')),
                );
                return;
              }
              final c = Cliente(
                nombre: name,
                dni: dniCtrl.text.trim(),
                telefono: telefonoCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                direccion: direccionCtrl.text.trim(),
              );
              try {
                final insertedId = await _dbService.insertCliente(c);
                await _loadInitialData();
                
                // Buscar el recién insertado para seleccionarlo
                final Map<String, dynamic>? newCli = _clientes.firstWhere(
                  (item) => item['id'] == insertedId,
                  orElse: () => <String, dynamic>{},
                );

                setState(() {
                  if (newCli != null && newCli.isNotEmpty) {
                    _selectedCliente = newCli;
                  }
                });
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al crear cliente: $e')),
                );
              }
            },
            child: Text('Guardar', style: GoogleFonts.manrope()),
          ),
        ],
      );
    });
  }

  Widget _buildClienteStep() {
    final filtered = _clientes.where((c) {
      final name = (c['nombre'] as String? ?? '').toLowerCase();
      final dni = (c['dni'] as String? ?? '').toLowerCase();
      return name.contains(_clienteSearch.toLowerCase()) || dni.contains(_clienteSearch.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _clienteSearch = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  style: GoogleFonts.manrope(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _showAddClienteDialog,
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Consumidor Final Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _selectedCliente == null ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
                    width: _selectedCliente == null ? 2 : 1,
                  ),
                ),
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Icon(Icons.person, color: const Color(0xFF64748B)),
                ),
                title: Text('Consumidor Final', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: _selectedCliente == null ? const Icon(Icons.check_circle, color: Color(0xFF0EA5E9)) : null,
                onTap: () {
                  setState(() {
                    _selectedCliente = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              // Clients List
              if (filtered.isNotEmpty) ...[
                Text(
                  'Clientes Registrados',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final c = filtered[idx];
                    final isSelected = _selectedCliente != null && _selectedCliente!['id'] == c['id'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.08),
                        child: Text(
                          c['nombre'].toString().isNotEmpty ? c['nombre'].toString()[0].toUpperCase() : 'C',
                          style: GoogleFonts.manrope(color: const Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(c['nombre'] as String? ?? '', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: c['dni'] != null && c['dni'].toString().isNotEmpty
                          ? Text('DNI: ${c['dni']}', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF64748B)))
                          : null,
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF0EA5E9)) : null,
                      onTap: () {
                        setState(() {
                          _selectedCliente = c;
                        });
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductosStep() {
    final filtered = _productos.where((p) {
      final name = (p['nombre'] as String? ?? '').toLowerCase();
      final code = (p['codigo'] as String? ?? '').toLowerCase();
      return name.contains(_productoSearch.toLowerCase()) || code.contains(_productoSearch.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            onChanged: (val) => setState(() => _productoSearch = val),
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            style: GoogleFonts.manrope(fontSize: 14),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final p = filtered[idx];
              final stock = (p['stock'] as num?)?.toInt() ?? 0;
              final price = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
              
              // Find if already in cart
              final cartIdx = _cart.indexWhere((item) => item['product']['id'] == p['id']);
              final cartQty = cartIdx != -1 ? _cart[cartIdx]['quantity'] as int : 0;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['nombre'] as String? ?? '', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Stock: $stock | ${formatCurrency(price)}', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    if (cartQty > 0)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                            onPressed: () => _updateCartQuantity(cartIdx, cartQty - 1),
                          ),
                          Text('$cartQty', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0EA5E9)),
                            onPressed: () => _updateCartQuantity(cartIdx, cartQty + 1),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                          foregroundColor: const Color(0xFF0EA5E9),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: Text('Agregar', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _addToCart(p),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPagoStep() {
    final paymentMethods = ['Efectivo', 'Debito', 'Credito', 'Transferencia', 'Fiado'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cart Summary Card
        Text(
          'Resumen de Compra',
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cart.length,
                separatorBuilder: (_, __) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final item = _cart[idx];
                  final prod = item['product'];
                  final qty = item['quantity'] as int;
                  final price = item['price'] as double;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prod['nombre'] as String? ?? '', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('$qty x ${formatCurrency(price)}', style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Text(formatCurrency(price * qty), style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
              const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  Text(formatCurrency(_subtotal), style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0EA5E9))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Payment Method Card
        Text(
          'Método de Pago',
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            children: paymentMethods.map((method) {
              final isSelected = _metodoPago == method;
              
              // Prevent selecting "Fiado" if no client is selected
              final isDisabled = method == 'Fiado' && _selectedCliente == null;

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(
                  method,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDisabled ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF0EA5E9))
                    : (isDisabled ? const Icon(Icons.lock_outline, size: 18, color: Color(0xFF94A3B8)) : null),
                onTap: isDisabled
                    ? null
                    : () {
                        setState(() {
                          _metodoPago = method;
                        });
                      },
              );
            }).toList(),
          ),
        ),
        if (_selectedCliente == null) ...[
          const SizedBox(height: 8),
          Text(
            '💡 Para habilitar "Fiado", debes seleccionar un cliente en el Paso 1.',
            style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomSummary() {
    final isLastStep = _currentStep == 2;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                child: Text('Atrás', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isLastStep ? const Color(0xFF22C55E) : const Color(0xFF0EA5E9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_currentStep < 2) {
                    if (_currentStep == 1 && _cart.isEmpty) {
                      _showSnackbar('⚠️ Agrega al menos un producto para continuar');
                      return;
                    }
                    setState(() {
                      _currentStep++;
                    });
                  } else {
                    _finalizeSale();
                  }
                },
                child: Text(
                  isLastStep ? 'Finalizar Venta' : 'Siguiente',
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
