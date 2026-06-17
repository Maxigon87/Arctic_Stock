import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:confetti/confetti.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../screens/product_list_screen.dart';
import '../screens/quick_inquiry_screen.dart';
import '../services/file_helper.dart';
import '../utils/file_namer.dart';
import '../utils/currency_formatter.dart';
import '../widgets/artic_dialog.dart';
import '../widgets/artic_barcode_scanner.dart';
import 'dart:async' as dart_async;
import 'dart:async';

class SalesScreen extends StatefulWidget {
  final bool startNewSale;
  const SalesScreen({super.key, this.startNewSale = false});

  @override
  State<SalesScreen> createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
  final dbService = DBService();
  dart_async.Timer? _debounce;

  // Filtros de búsqueda de ventas
  Cliente? _clienteSeleccionado;
  String? metodoSeleccionado;
  DateTime? desde;
  DateTime? hasta;
  List<Cliente> _clientes = [];
  String _sortBy = 'fecha_desc';

  final _productoCtrl = TextEditingController();
  bool _aplicarDescuento = false;
  String _tipoDescuento = 'percentage'; // 'percentage' o 'fixed'
  final TextEditingController _descuentoCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _debounce?.cancel();
    _productoCtrl.dispose();
    _descuentoCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // 🛒 Carrito (usa snapshots)
  // Keys: productoId, nombre, codigo, cantidad, precioUnit, costoUnit, subtotal
  final List<Map<String, dynamic>> _carrito = [];

  late Future<List<Map<String, dynamic>>> _ventasFuture;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _ventasFuture = dbService.getVentas(orderBy: _sortBy);
    _cargarClientes();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 500));
    if (widget.startNewSale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        abrirCarrito();
      });
    }
  }

  Widget _buildDetailBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _verDetalleVenta(int ventaId) async {
    try {
      final header = await dbService.getVentaById(ventaId);
      final items = await dbService.getItemsByVenta(ventaId);

      if (!mounted) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      showArticDialog(
        context: context,
        builder: (ctx) {
          final cliente =
              (header?['clienteNombre']?.toString().isNotEmpty ?? false)
                  ? header!['clienteNombre']
                  : 'Consumidor Final';
          final vendedor =
              (header?['usuarioNombre']?.toString().isNotEmpty ?? false)
                  ? header!['usuarioNombre']
                  : '—';
          final total = (header?['total'] as num?)?.toDouble() ?? 0.0;
          final subtotal = (header?['subtotal'] as num?)?.toDouble() ?? total;
          final descuento = (header?['descuento'] as num?)?.toDouble() ?? 0.0;
          final fechaRaw = header?['fecha'] as String?;
          String formattedDate = '';
          if (fechaRaw != null) {
            try {
              final parsed = DateTime.parse(fechaRaw);
              formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
            } catch (_) {
              formattedDate = fechaRaw.split('T').first;
            }
          }
          final metodo = header?['metodoPago'] ?? '—';

          final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
          final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
          final textC = isDark ? Colors.white : const Color(0xFF0F172A);
          final subC = isDark ? Colors.white70 : const Color(0xFF64748B);

          Color methodColor = const Color(0xFF0EA5E9);
          if (metodo.toString().toLowerCase().contains('efectivo')) {
            methodColor = const Color(0xFF22C55E);
          } else if (metodo.toString().toLowerCase().contains('tarjeta') || metodo.toString().toLowerCase().contains('débito') || metodo.toString().toLowerCase().contains('crédito')) {
            methodColor = const Color(0xFFF59E0B);
          } else if (metodo.toString().toLowerCase().contains('fiado')) {
            methodColor = const Color(0xFFEF4444);
          }

          return ArticDialogCard(
            title: "Comprobante de Venta",
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.blueAccent),
                tooltip: 'Compartir comprobante',
                onPressed: () =>
                    _compartirComprobante(header!, items),
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Colors.green),
                tooltip: 'Guardar comprobante',
                onPressed: () =>
                    _guardarComprobante(header!, items),
              ),
              IconButton(
                icon: Icon(Icons.print, color: isDark ? Colors.white70 : Colors.black54),
                tooltip: 'Imprimir comprobante',
                onPressed: () =>
                    _imprimirComprobante(header!, items),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cerrar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
              ),
            ],
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Metric Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Cobrado",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subC,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatCurrency(total),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Método de Pago",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subC,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: methodColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: methodColor.withOpacity(0.25), width: 1),
                                ),
                                child: Text(
                                  metodo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: methodColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Transaction Resumen Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Resumen de Transacción",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textC,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDetailRow('Número de Venta', '#$ventaId', subC),
                        Divider(height: 20, color: borderColor),
                        _buildDialogDetailRow('Cliente', cliente, subC),
                        Divider(height: 20, color: borderColor),
                        _buildDialogDetailRow('Vendedor', vendedor, subC),
                        Divider(height: 20, color: borderColor),
                        _buildDialogDetailRow('Fecha y Hora', formattedDate, subC),
                        if (descuento > 0) ...[
                          Divider(height: 20, color: borderColor),
                          _buildDialogDetailRow('Subtotal', formatCurrency(subtotal), subC),
                          Divider(height: 20, color: borderColor),
                          _buildDialogDetailRow('Descuento', '-${formatCurrency(descuento)}', const Color(0xFFEF4444)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Products Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Detalle de Productos",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textC,
                          ),
                        ),
                        const SizedBox(height: 12),
                        items.isEmpty
                            ? const Center(child: Text("Sin ítems"))
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
                                  itemBuilder: (_, i) {
                                    final it = items[i];
                                    final nombre = it['producto'] ?? 'Producto';
                                    final codigo =
                                        (it['codigo']?.toString().isNotEmpty ?? false)
                                            ? " · Cód: ${it['codigo']}"
                                            : "";
                                    final cant = (it['cantidad'] as num?)?.toInt() ?? 0;
                                    final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
                                    final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);

                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nombre,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: textC,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Cant: $cant · P. Unit: ${formatCurrency(pu)}$codigo",
                                                style: TextStyle(color: subC, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          formatCurrency(sub),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textC,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo cargar el detalle: $e")),
      );
    }
  }

  Widget _buildDialogDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Future<Uint8List> _generarPdfComprobante(
      Map<String, dynamic> header, List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();
    const lineWidth = 32;
    final logoData =
        await rootBundle.load('assets/logo/logo_sin_titulo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    String _repeat(String char, int times) => List.filled(times, char).join();

    List<String> _wrap(String text) {
      final lines = <String>[];
      for (var i = 0; i < text.length; i += lineWidth) {
        final end = (i + lineWidth < text.length) ? i + lineWidth : text.length;
        lines.add(text.substring(i, end));
      }
      return lines;
    }

    void _addWrapped(List<String> target, String text) {
      target.addAll(_wrap(text));
    }

    void _addCentered(List<String> target, String text) {
      for (final line in _wrap(text)) {
        final pad = ((lineWidth - line.length) / 2).floor();
        target.add("${_repeat(' ', pad)}$line");
      }
    }

    void _addTwoCols(List<String> target, String left, String right) {
      if (left.length + right.length > lineWidth) {
        final parts = _wrap(left);
        target.addAll(parts.take(parts.length - 1));
        _addTwoCols(target, parts.last, right);
      } else {
        final spaces = lineWidth - left.length - right.length;
        target.add("$left${_repeat(' ', spaces)}$right");
      }
    }

    final ventaId = header['id'] as int? ?? 0;
    final fecha = header['fecha']?.toString().split('T').first ?? '';
    final cliente = (header['clienteNombre']?.toString().isNotEmpty ?? false)
        ? header['clienteNombre']
        : 'Consumidor Final';
    final vendedor = (header['usuarioNombre']?.toString().isNotEmpty ?? false)
        ? header['usuarioNombre']
        : '—';
    final metodo = header['metodoPago'] ?? '—';
    final total = (header['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (header['subtotal'] as num?)?.toDouble() ?? total;
    final descuento = (header['descuento'] as num?)?.toDouble() ?? 0.0;

    final linesOut = <String>[];
    _addCentered(linesOut, 'Venta #$ventaId');
    _addCentered(linesOut, fecha);
    _addWrapped(linesOut, 'Cliente: $cliente');
    _addWrapped(linesOut, 'Vendedor: $vendedor');
    _addWrapped(linesOut, 'Método: $metodo');
    linesOut.add(_repeat('-', lineWidth));
    _addCentered(linesOut, 'PRODUCTOS');
    linesOut.add(_repeat('-', lineWidth));

    for (final it in items) {
      final nombre = (it['producto'] ?? '').toString();
      final cant = (it['cantidad'] as num?)?.toInt() ?? 0;
      final pu = (it['precioUnitario'] as num?)?.toDouble() ?? 0.0;
      final sub = (it['subtotal'] as num?)?.toDouble() ?? (pu * cant);

      _addWrapped(linesOut, nombre);
      _addTwoCols(linesOut, '${cant} x ${formatCurrency(pu)}',
          formatCurrency(sub));
      linesOut.add('');
    }

    linesOut.add(_repeat('-', lineWidth));
    if (descuento > 0) {
      _addTwoCols(linesOut, 'SUBTOTAL', formatCurrency(subtotal));
      _addTwoCols(linesOut, 'DESCUENTO', '-${formatCurrency(descuento)}');
    }
    _addTwoCols(linesOut, 'TOTAL', formatCurrency(total));
    linesOut.add(_repeat('-', lineWidth));

    final font = pw.Font.courier();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.all(5),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Center(child: pw.Image(logoImage, width: 40)),
            pw.SizedBox(height: 5),
            pw.Text(
              linesOut.join('\n'),
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> _guardarComprobante(
      Map<String, dynamic> header, List<Map<String, dynamic>> items) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Permiso de almacenamiento denegado')),
          );
          return;
        }
      }

      final bytes = await _generarPdfComprobante(header, items);
      final dir = await FileHelper.getVentasDir();
      final ventaId = header['id'] as int? ?? 0;
      final cliente = header['clienteNombre']?.toString() ??
          'Consumidor Final';
      final file = File(
          '${dir.path}/${FileNamer.factura(ventaId, cliente)}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comprobante guardado en ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar comprobante: $e')),
      );
    }
  }

  Future<void> _compartirComprobante(
      Map<String, dynamic> header, List<Map<String, dynamic>> items) async {
    final bytes = await _generarPdfComprobante(header, items);
    final dir = await FileHelper.getVentasDir();
    final ventaId = header['id'] as int? ?? 0;
    final cliente = header['clienteNombre']?.toString() ?? 'Consumidor Final';
    final file = File('${dir.path}/${FileNamer.factura(ventaId, cliente)}');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _imprimirComprobante(
      Map<String, dynamic> header, List<Map<String, dynamic>> items) async {
    final bytes = await _generarPdfComprobante(header, items);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> _cargarClientes() async {
    final clientes = await dbService.getClientes();
    setState(() => _clientes = clientes);
  }

  Future<void> _cargarVentasFiltradas() async {
    final q = _productoCtrl.text.trim();
    setState(() {
      _ventasFuture = dbService.buscarVentasAvanzado(
        clienteId: _clienteSeleccionado?.id,
        metodoPago: metodoSeleccionado,
        desde: desde,
        hasta: hasta,
        productoQuery: q.isEmpty ? null : q,
        orderBy: _sortBy,
      );
    });
  }

  // --- Helpers carrito / stock ------------------------------------------------

  Future<int> _stockDisponible(int productoId) async {
    final p = await dbService.getProductoById(productoId);
    return (p?['stock'] as num?)?.toInt() ?? 0;
  }

  TextInputFormatter _maxStockFormatter(
      int Function() stockProvider, BuildContext context) {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) return newValue;
      final value = int.tryParse(newValue.text);
      if (value == null) return oldValue;
      final max = stockProvider();
      if (value > max) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solo hay $max unidades disponibles')),
        );
        return oldValue;
      }
      return newValue;
    });
  }

  Future<bool> _confirmarPerdidaDialog(double precio, double costo) async {
    if (precio >= costo) return true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showArticDialog<bool>(
      context: context,
      builder: (_) => ArticDialogCard(
        title: '⚠️ Atención',
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Continuar')),
        ],
        child: Text(
          'Este producto se venderá con pérdida.\n'
          'Precio: ${formatCurrency(precio)} | Costo: ${formatCurrency(costo)}',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> agregarAlCarrito(Map<String, dynamic> producto) async {
    final int id = producto['id'] as int;
    final int stock = await _stockDisponible(id);
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ Este producto no tiene stock disponible")),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController cantCtrl = TextEditingController(text: '1');
    final int? cantidad = await showArticDialog<int>(
      context: context,
      builder: (ctx) {
        return ArticDialogCard(
          title: 'Cantidad',
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                onPressed: () =>
                    Navigator.pop(ctx, int.tryParse(cantCtrl.text) ?? 0),
                child: const Text('Agregar')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Ingresa la cantidad a vender (máx. $stock):", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 12),
              TextField(
                controller: cantCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _maxStockFormatter(() => stock, context),
                ],
                decoration: const InputDecoration(
                  labelText: "Cantidad",
                ),
              ),
            ],
          ),
        );
      },
    );
    if (cantidad == null) return;

    final int cant = cantidad;
    if (cant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad inválida')),
      );
      return;
    }
    if (cant > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solo hay $stock unidades disponibles')),
      );
      return;
    }

    final double precio = (producto['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final double costo = (producto['costo_compra'] as num?)?.toDouble() ?? 0.0;

    // Warning si vende con pérdida (solo al primer agregado)
    if (!await _confirmarPerdidaDialog(precio, costo)) return;

    setState(() {
      final idx = _carrito.indexWhere((e) => e['productoId'] == id);
      if (idx == -1) {
        _carrito.add({
          'productoId': id,
          'nombre': producto['nombre'],
          'codigo': producto['codigo'],
          'precioUnit': precio,
          'costoUnit': costo,
          'cantidad': cant,
          'subtotal': precio * cant,
          'stockDisponible': stock,
        });
      } else {
        final actual = _carrito[idx]['cantidad'] as int;
        if (actual + cant > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Solo hay $stock unidades disponibles')),
          );
        } else {
          _carrito[idx]['cantidad'] = actual + cant;
          _carrito[idx]['subtotal'] = precio * (actual + cant);
          _carrito[idx]['stockDisponible'] = stock;
        }
      }
    });
  }

  // --- BottomSheet carrito ----------------------------------------------------
  Future<void> abrirCarrito() async {
    bool clienteConDeudas = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _aplicarDescuento = false;
    _tipoDescuento = 'percentage';
    _descuentoCtrl.text = '0';

    // Query active products once before showing dialog
    final allProds = await dbService.getStockProductos();
    final activeProducts = allProds.where((p) => (p['activo'] as num?)?.toInt() != 0).toList();

    // Local state variables for the dialog
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    String selectedPaymentButton = metodoSeleccionado ?? 'Efectivo';
    if (selectedPaymentButton == 'Tarjeta') {
      selectedPaymentButton = 'Débito';
    } else if (selectedPaymentButton == 'Fiado') {
      selectedPaymentButton = 'Cuenta Corriente';
    }

    showArticDialog(
      context: context,
      maxWidth: 1100,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final double subtotalCarrito = _carrito.fold<double>(
            0.0,
            (sum, p) => sum + (p['subtotal'] as num).toDouble(),
          );

          final double valDesc = double.tryParse(_descuentoCtrl.text) ?? 0.0;
          bool hasDiscountError = false;
          String discountErrorMsg = '';

          if (_aplicarDescuento) {
            if (valDesc < 0) {
              hasDiscountError = true;
              discountErrorMsg = 'El descuento no puede ser negativo';
            } else if (_tipoDescuento == 'percentage' && valDesc > 100) {
              hasDiscountError = true;
              discountErrorMsg = 'El porcentaje no puede superar el 100%';
            } else {
              double calcDiscount = 0.0;
              if (_tipoDescuento == 'percentage') {
                calcDiscount = subtotalCarrito * (valDesc / 100.0);
              } else {
                calcDiscount = valDesc;
              }
              if (calcDiscount > subtotalCarrito) {
                hasDiscountError = true;
                discountErrorMsg = 'El descuento no puede superar el subtotal';
              }
            }
          }

          double descuentoMonto = 0.0;
          if (_aplicarDescuento && !hasDiscountError) {
            if (_tipoDescuento == 'percentage') {
              descuentoMonto = subtotalCarrito * (valDesc / 100.0);
            } else {
              descuentoMonto = valDesc;
            }
          }
          final double totalCarrito = subtotalCarrito - descuentoMonto;

          final bool hayStockSuficiente = _carrito.isNotEmpty &&
              _carrito.every((p) =>
                  (p['cantidad'] as int) <=
                  ((p['stockDisponible'] as int?) ?? 0));

          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
          final primaryColor = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
          final cardBgColor = isDark ? const Color(0xFF1E293B).withOpacity(0.4) : Colors.white.withOpacity(0.7);
          final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

          return ArticDialogCard(
            title: null,
            child: SizedBox(
              width: 1050,
              height: 700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_outlined, color: primaryColor, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            "Nueva Venta",
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: subtextColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1),
                  const SizedBox(height: 8),

                  // --- BODY ---
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Cart / Search / Table)
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Search Input field with dropdown Stack
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: searchCtrl,
                                          style: TextStyle(color: textColor, fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText: "Buscar producto por nombre, código o código de barras...",
                                            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.black38),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: borderColor),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            final query = val.trim().toLowerCase();
                                            setLocalState(() {
                                              if (query.isEmpty) {
                                                searchResults = [];
                                              } else {
                                                searchResults = activeProducts.where((p) {
                                                  final nombre = (p['nombre']?.toString() ?? '').toLowerCase();
                                                  final codigo = (p['codigo']?.toString() ?? '').toLowerCase();
                                                  final barcode = (p['codigoBarras']?.toString() ?? '').toLowerCase();
                                                  return nombre.contains(query) || codigo.contains(query) || barcode.contains(query);
                                                }).toList();
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text("Agregar Producto", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final producto = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ProductListScreen(selectMode: true),
                                            ),
                                          );
                                          if (producto != null) {
                                            await agregarAlCarrito(producto);
                                            setLocalState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  // Live Search Dropdown
                                  if (searchResults.isNotEmpty)
                                    Positioned(
                                      top: 45,
                                      left: 0,
                                      right: 185, // align with the search input
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        child: Container(
                                          constraints: const BoxConstraints(maxHeight: 250),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: borderColor),
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: searchResults.length,
                                            itemBuilder: (context, idx) {
                                              final prod = searchResults[idx];
                                              final pName = prod['nombre'] ?? '';
                                              final pCode = prod['codigo'] ?? '';
                                              final pPrice = (prod['precio_venta'] as num?)?.toDouble() ?? 0.0;
                                              final pStock = (prod['stock'] as num?)?.toInt() ?? 0;
                                              return ListTile(
                                                dense: true,
                                                title: Text(pName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                                subtitle: Text("Cod: $pCode | Stock: $pStock | ${formatCurrency(pPrice)}", style: TextStyle(color: subtextColor)),
                                                trailing: const Icon(Icons.add, size: 16),
                                                onTap: () async {
                                                  await agregarAlCarrito(prod);
                                                  searchCtrl.clear();
                                                  setLocalState(() {
                                                    searchResults.clear();
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Cart Table Title Row
                              Row(
                                children: [
                                  Text(
                                    "Carrito de compras",
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${_carrito.length} productos",
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Cart Table Header
                              Row(
                                children: [
                                  Expanded(flex: 4, child: Text("Producto", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor))),
                                  Expanded(flex: 2, child: Text("Precio", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor), textAlign: TextAlign.right)),
                                  Expanded(flex: 3, child: Text("Cantidad", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor), textAlign: TextAlign.center)),
                                  Expanded(flex: 2, child: Text("Subtotal", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor), textAlign: TextAlign.right)),
                                  Expanded(flex: 1, child: const SizedBox()), // delete spacing
                                ],
                              ),
                              const Divider(height: 16),

                              // Cart Items List
                              Expanded(
                                child: _carrito.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.shopping_cart_outlined, size: 48, color: subtextColor.withOpacity(0.5)),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Carrito vacío",
                                              style: TextStyle(color: subtextColor, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: _carrito.length,
                                        itemBuilder: (context, i) {
                                          final p = _carrito[i];
                                          final double precioUnit = (p['precioUnit'] as num).toDouble();
                                          final double costoUnit = (p['costoUnit'] as num).toDouble();
                                          final int cantidad = (p['cantidad'] as num).toInt();
                                          final double subtotal = (p['subtotal'] as num).toDouble();
                                          final int stockDisponible = (p['stockDisponible'] as num?)?.toInt() ?? 999;

                                          return Column(
                                            children: [
                                              Row(
                                                children: [
                                                  // Producto (image + name + code)
                                                  Expanded(
                                                    flex: 4,
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration: BoxDecoration(
                                                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.white60 : Colors.black45, size: 20),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                p['nombre']?.toString() ?? '',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  color: textColor,
                                                                  fontSize: 13,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                p['codigo']?.toString() ?? 'Sin código',
                                                                style: TextStyle(
                                                                  color: subtextColor,
                                                                  fontSize: 11,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Precio
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      formatCurrency(precioUnit),
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),

                                                  // Cantidad
                                                  Expanded(
                                                    flex: 3,
                                                    child: Center(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          border: Border.all(color: borderColor),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.remove, size: 14),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                              onPressed: cantidad > 1
                                                                  ? () {
                                                                      setLocalState(() {
                                                                        p['cantidad'] = cantidad - 1;
                                                                        p['subtotal'] = precioUnit * (cantidad - 1);
                                                                      });
                                                                    }
                                                                  : null,
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                border: Border(
                                                                  left: BorderSide(color: borderColor),
                                                                  right: BorderSide(color: borderColor),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                cantidad.toString(),
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  color: textColor,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.add, size: 14),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                              onPressed: cantidad < stockDisponible
                                                                  ? () {
                                                                      setLocalState(() {
                                                                        p['cantidad'] = cantidad + 1;
                                                                        p['subtotal'] = precioUnit * (cantidad + 1);
                                                                      });
                                                                    }
                                                                  : () {
                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                        SnackBar(content: Text('Solo hay $stockDisponible unidades disponibles')),
                                                                      );
                                                                    },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  // Subtotal
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      formatCurrency(subtotal),
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: textColor,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),

                                                  // Trash Icon
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                                        onPressed: () => setLocalState(() => _carrito.removeAt(i)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 12),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 12),

                              // Scan Barcode Button
                              InkWell(
                                onTap: () async {
                                  final barcodeResult = await Navigator.push<String?>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ArticBarcodeScanner(),
                                    ),
                                  );
                                  if (barcodeResult != null && barcodeResult.isNotEmpty) {
                                    final found = activeProducts.firstWhere(
                                      (p) => p['codigoBarras']?.toString() == barcodeResult || p['codigo']?.toString() == barcodeResult,
                                      orElse: () => {},
                                    );
                                    if (found.isNotEmpty) {
                                      await agregarAlCarrito(found);
                                      setLocalState(() {});
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('No se encontró ningún producto con el código: $barcodeResult')),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.3),
                                      style: BorderStyle.solid,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: primaryColor.withOpacity(0.02),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        "Escanear código de barras",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Bottom Stats Cards
                              Row(
                                children: [
                                  Expanded(child: _buildBottomKpiCard(context, Icons.shopping_cart_outlined, const Color(0xFF10B981), "${_carrito.length}", "Productos")),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildBottomKpiCard(context, Icons.attach_money_rounded, Colors.blue, formatCurrency(subtotalCarrito), "Subtotal")),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildBottomKpiCard(context, Icons.local_offer_outlined, Colors.redAccent, formatCurrency(descuentoMonto), "Descuento")),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Consejo Notice
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Consejo: Podés escanear productos o buscarlos para agregarlos más rápido.",
                                      style: TextStyle(fontSize: 11, color: subtextColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 24),
                        VerticalDivider(width: 1, color: borderColor),
                        const SizedBox(width: 24),

                        // Right Column (Checkout: Client / Payment / Discount / Totals / Action Buttons)
                        Expanded(
                          flex: 8,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // --- CLIENT CARD ---
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline_rounded, color: subtextColor, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Cliente",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: subtextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<Cliente?>(
                                        value: _clienteSeleccionado,
                                        hint: const Text("Consumidor Final"),
                                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        style: TextStyle(color: textColor, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: borderColor),
                                          ),
                                        ),
                                        items: [
                                          const DropdownMenuItem<Cliente?>(
                                            value: null,
                                            child: Text("Consumidor Final"),
                                          ),
                                          ..._clientes.map(
                                            (c) => DropdownMenuItem<Cliente?>(
                                              value: c,
                                              child: Text(c.nombre),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) async {
                                          setLocalState(() => _clienteSeleccionado = value);
                                          if (value != null && value.id != null) {
                                            final count = await dbService.countDeudasCliente(value.id!);
                                            final muchas = count > 1;
                                            setLocalState(() => clienteConDeudas = muchas);
                                            if (muchas) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('El cliente tiene múltiples deudas pendientes'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } else {
                                            setLocalState(() => clienteConDeudas = false);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                        label: const Text("Agregar cliente", style: TextStyle(fontSize: 12)),
                                        onPressed: () async {
                                          final nuevo = await _showNuevoClienteDialog();
                                          if (nuevo != null) {
                                            setState(() => _clientes.add(nuevo));
                                            setLocalState(() => _clienteSeleccionado = nuevo);
                                          }
                                        },
                                      ),
                                      if (clienteConDeudas)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.warning, color: Colors.red, size: 16),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'El cliente tiene múltiples deudas',
                                                  style: TextStyle(color: Colors.red, fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // --- PAYMENT METHODS ---
                                Text(
                                  "Método de pago",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: subtextColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildPaymentButton(context, 'Efectivo', Icons.payments_outlined, selectedPaymentButton == 'Efectivo', setLocalState)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildPaymentButton(context, 'Débito', Icons.credit_card_outlined, selectedPaymentButton == 'Débito', setLocalState)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildPaymentButton(context, 'Crédito', Icons.credit_card_outlined, selectedPaymentButton == 'Crédito', setLocalState)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildPaymentButton(context, 'Transferencia', Icons.account_balance_outlined, selectedPaymentButton == 'Transferencia', setLocalState)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildPaymentButton(context, 'Cuenta Corriente', Icons.book_outlined, selectedPaymentButton == 'Cuenta Corriente', setLocalState)),
                                    const SizedBox(width: 8),
                                    const Expanded(child: SizedBox()),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // --- DISCOUNT SECTION ---
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Descuento",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: subtextColor,
                                      ),
                                    ),
                                    Switch(
                                      value: _aplicarDescuento,
                                      activeColor: primaryColor,
                                      onChanged: (val) {
                                        setLocalState(() {
                                          _aplicarDescuento = val;
                                          if (!_aplicarDescuento) {
                                            _descuentoCtrl.text = '0';
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                if (_aplicarDescuento) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Radio<String>(
                                        value: 'percentage',
                                        groupValue: _tipoDescuento,
                                        activeColor: primaryColor,
                                        onChanged: (val) {
                                          if (val != null) {
                                            setLocalState(() {
                                              _tipoDescuento = val;
                                              _descuentoCtrl.text = '0';
                                            });
                                          }
                                        },
                                      ),
                                      Text("Porcentaje", style: TextStyle(color: textColor, fontSize: 12)),
                                      const SizedBox(width: 16),
                                      Radio<String>(
                                        value: 'fixed',
                                        groupValue: _tipoDescuento,
                                        activeColor: primaryColor,
                                        onChanged: (val) {
                                          if (val != null) {
                                            setLocalState(() {
                                              _tipoDescuento = val;
                                              _descuentoCtrl.text = '0';
                                            });
                                          }
                                        },
                                      ),
                                      Text("Monto Fijo", style: TextStyle(color: textColor, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _descuentoCtrl,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: "Valor",
                                      labelStyle: TextStyle(fontSize: 12, color: subtextColor),
                                      prefixText: _tipoDescuento == 'fixed' ? "\$ " : null,
                                      suffixText: _tipoDescuento == 'percentage' ? " %" : null,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (val) => setLocalState(() {}),
                                  ),
                                  if (hasDiscountError) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      discountErrorMsg,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  if (_tipoDescuento == 'percentage') ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [5, 10, 15, 20].map((percent) {
                                        final isSelected = double.tryParse(_descuentoCtrl.text) == percent;
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                            child: ChoiceChip(
                                              label: Text("$percent%", style: TextStyle(fontSize: 11, color: isSelected ? (isDark ? const Color(0xFF0F172A) : Colors.white) : textColor)),
                                              selected: isSelected,
                                              selectedColor: primaryColor,
                                              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setLocalState(() {
                                                    _descuentoCtrl.text = percent.toString();
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 20),

                                // --- SUMMARY CARD ---
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Subtotal", style: TextStyle(color: subtextColor, fontSize: 12)),
                                          Text(formatCurrency(subtotalCarrito), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      if (_aplicarDescuento && descuentoMonto > 0) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _tipoDescuento == 'percentage' ? "Descuento (${_descuentoCtrl.text}%)" : "Descuento",
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                            ),
                                            Text(
                                              "-${formatCurrency(descuentoMonto)}",
                                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Divider(),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("TOTAL", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            formatCurrency(totalCarrito),
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF22C55E),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_aplicarDescuento && descuentoMonto > 0) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  "Ahorrás ${formatCurrency(descuentoMonto)} con este descuento",
                                                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // --- OBSERVACIONES ---
                                TextFormField(
                                  maxLines: 2,
                                  style: TextStyle(color: textColor, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: "Observaciones (opcional)",
                                    labelStyle: TextStyle(color: subtextColor, fontSize: 12),
                                    hintText: "Escribí una nota para esta venta...",
                                    hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.all(10),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // --- ACTIONS ---
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text("Confirmar Venta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: (hayStockSuficiente && !hasDiscountError && _carrito.isNotEmpty)
                                      ? () {
                                          Navigator.pop(ctx);
                                          _confirmarVenta();
                                        }
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: subtextColor,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancelar", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentButton(
    BuildContext context,
    String label,
    IconData icon,
    bool isSelected,
    StateSetter setLocalState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isSelected
        ? (isDark ? const Color(0xFF0284C7).withOpacity(0.25) : const Color(0xFF0284C7).withOpacity(0.08))
        : Colors.transparent;
    final activeBorder = isSelected
        ? (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06));
    final activeText = isSelected
        ? (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
        : (isDark ? Colors.white70 : Colors.black87);

    return InkWell(
      onTap: () {
        setLocalState(() {
          if (label == 'Efectivo') {
            metodoSeleccionado = 'Efectivo';
          } else if (label == 'Débito' || label == 'Crédito') {
            metodoSeleccionado = 'Tarjeta';
          } else if (label == 'Transferencia') {
            metodoSeleccionado = 'Transferencia';
          } else if (label == 'Cuenta Corriente') {
            metodoSeleccionado = 'Fiado';
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: activeBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activeBorder, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: activeText, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: activeText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomKpiCard(
    BuildContext context,
    IconData icon,
    Color iconColor,
    String value,
    String label,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // --- Confirmar venta --------------------------------------------------------

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ El carrito está vacío")),
      );
      return;
    }

    if (metodoSeleccionado == 'Fiado' && _clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ No puedes fiar sin cliente")),
      );
      return;
    }

    // Verificación de stock actual (por si cambió mientras armabas el carrito)
    final productosAgotados = <String>[];
    for (var item in _carrito) {
      final producto = await dbService.getProductoById(item['productoId']);
      if (producto == null) {
        productosAgotados
            .add("Producto desconocido (ID: ${item['productoId']})");
        continue;
      }
      final stock = (producto['stock'] as num?)?.toInt() ?? 0;
      final req = (item['cantidad'] as num).toInt();
      if (stock < req) {
        productosAgotados
            .add("${producto['nombre']} (Stock: $stock / Necesita: $req)");
      }
    }
    if (productosAgotados.isNotEmpty) {
      _mostrarAlertaStockInsuficiente(productosAgotados);
      return;
    }

    final double subtotal =
        _carrito.fold(0.0, (sum, i) => sum + (i['subtotal'] as num).toDouble());

    double valDesc = 0.0;
    String? discountType;
    double discountAmount = 0.0;

    if (_aplicarDescuento) {
      valDesc = double.tryParse(_descuentoCtrl.text) ?? 0.0;
      discountType = _tipoDescuento; // 'percentage' o 'fixed'
      if (_tipoDescuento == 'percentage') {
        discountAmount = subtotal * (valDesc / 100.0);
      } else {
        discountAmount = valDesc;
      }
      if (discountAmount > subtotal) {
        discountAmount = subtotal;
      }
      if (discountAmount < 0) {
        discountAmount = 0;
      }
    }
    final double total = subtotal - discountAmount;

    try {
      final ventaId = await dbService.insertVentaBase({
        'clienteId': _clienteSeleccionado?.id,
        'fecha': DateTime.now().toIso8601String(),
        'metodoPago': metodoSeleccionado ?? 'Efectivo',
        'subtotal': subtotal,
        'discountType': discountType,
        'discountValue': valDesc,
        'discountAmount': discountAmount,
        'descuento': discountAmount,
        'total': total,
      });

      for (var i in _carrito) {
        await dbService.insertItemVenta({
          'ventaId': ventaId,
          'productoId': i['productoId'],
          'cantidad': i['cantidad'],
          'precio_unitario': (i['precioUnit'] as num).toDouble(), // snapshot
          'costo_unitario': (i['costoUnit'] as num).toDouble(), // snapshot
          'subtotal': (i['subtotal'] as num).toDouble(),
          // snapshots de texto son opcionales: el trigger y el método ya los cubren
          // 'producto_nombre': i['nombre'],
          // 'producto_codigo': i['codigo'],
        });
      }

      if (metodoSeleccionado == 'Fiado' && _clienteSeleccionado != null) {
        await dbService.insertDeuda({
          'clienteId': _clienteSeleccionado!.id,
          'monto': total,
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'Pendiente',
          'descripcion': 'Venta fiada',
          'ventaId': ventaId,
        });
      }

      setState(() {
        _carrito.clear();
      });

      // Refrescar listado con los filtros actuales
      await _cargarVentasFiltradas();

      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Venta registrada correctamente!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: ${e.toString()}")),
      );
    }
  }

  // --- UI de filtros y lista de ventas ---------------------------------------

  Widget _buildFiltros(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Cliente?>(
                    hint: Text("Cliente (Todos)", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                    value: _clienteSeleccionado,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: [
                      const DropdownMenuItem<Cliente?>(
                          value: null, child: Text("Todos los Clientes", style: TextStyle(fontSize: 13))),
                      ..._clientes.map((c) => DropdownMenuItem<Cliente?>(
                          value: c, child: Text(c.nombre, style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (value) {
                      setState(() => _clienteSeleccionado = value);
                      _cargarVentasFiltradas();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
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
                    hint: Text("Método de Pago", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                    value: metodoSeleccionado,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: ["Todos", "Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                        .map((m) => DropdownMenuItem<String>(
                              value: m == "Todos" ? null : m,
                              child: Text(m, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => metodoSeleccionado = value);
                      _cargarVentasFiltradas();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.black12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(
                desde != null && hasta != null
                    ? "${DateFormat('dd/MM').format(desde!)} - ${DateFormat('dd/MM').format(hasta!)}"
                    : "Fecha",
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () async {
                final rango = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2022),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark
                            ? const ColorScheme.dark(
                                primary: Color(0xFF22D3EE),
                                onPrimary: Color(0xFF0F172A),
                                surface: Color(0xFF1E293B),
                                onSurface: Colors.white,
                              )
                            : const ColorScheme.light(
                                primary: Color(0xFF0284C7),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Color(0xFF0F172A),
                              ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (rango != null) {
                  setState(() {
                    desde = DateTime(rango.start.year, rango.start.month,
                        rango.start.day, 0, 0, 0, 0);
                    hasta = DateTime(rango.end.year, rango.end.month, rango.end.day,
                        23, 59, 59, 999);
                  });
                  _cargarVentasFiltradas();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _productoCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Buscar producto por nombre o código...',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black54),
                  isDense: true,
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = dart_async.Timer(
                    const Duration(milliseconds: 350),
                    _cargarVentasFiltradas,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
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
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'fecha_desc', child: Text("Fecha: Más Recientes", style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'fecha_asc', child: Text("Fecha: Más Antiguas", style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'total_desc', child: Text("Total: Mayor a Menor", style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'total_asc', child: Text("Total: Menor a Mayor", style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                      _cargarVentasFiltradas();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableHeader(bool isDark) {
    final textColor = isDark ? Colors.white60 : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text("Venta", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12))),
          Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12))),
          Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12))),
          Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text("Estado / Acciones", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12)))),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> v, bool isEven, bool isDark) {
    final id = v['id'] as int;
    final fechaRaw = v['fecha']?.toString().split('T').first ?? '';
    final cliente = (v['clienteNombre']?.toString().isNotEmpty ?? false)
        ? v['clienteNombre']
        : 'Consumidor Final';
    final total = (v['total'] as num?)?.toDouble() ?? 0.0;
    final metodo = v['metodoPago'] ?? 'Efectivo';
    final isFiado = metodo == 'Fiado';

    Color rowColor = Colors.transparent;
    if (!isEven) {
      rowColor = isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01);
    }

    final isPaid = !isFiado;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "#$id",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  fechaRaw,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: isDark ? const Color(0xFF0284C7).withOpacity(0.2) : const Color(0xFF0284C7).withOpacity(0.1),
                  child: Text(
                    cliente[0].toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cliente,
                    style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metodo,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withOpacity(0.1)
                        : Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? "Pago" : "Pendiente",
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.visibility, color: isDark ? Colors.white70 : Colors.black54, size: 16),
                  onPressed: () => _verDetalleVenta(id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Ventas y Facturación",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ArticContainer(
                    maxWidth: 620,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFiltros(isDark),
                        const SizedBox(height: 16),
                        _buildTableHeader(isDark),
                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _ventasFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(child: Text("Error: ${snapshot.error}"));
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(child: Text("No hay ventas registradas"));
                              }
                              final ventas = snapshot.data!;
                              return ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: ventas.length,
                                itemBuilder: (context, index) {
                                  final v = ventas[index];
                                  return _buildTableRow(v, index % 2 == 0, isDark);
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
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 10,
              emissionFrequency: 0.05,
              maxBlastForce: 8,
              minBlastForce: 2,
              gravity: 0.1,
              colors: const [Colors.teal, Colors.blueGrey],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: abrirCarrito,
        backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  // --- Utilidades varias ------------------------------------------------------

  Future<Cliente?> _showNuevoClienteDialog() async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showArticDialog<Cliente>(
      context: context,
      builder: (ctx) {
        return ArticDialogCard(
          title: "Nuevo Cliente",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final nuevoCliente =
                    Cliente(nombre: nombre, telefono: telefonoCtrl.text.trim());
                final id = await dbService.insertCliente(nuevoCliente);
                Navigator.pop(
                    ctx,
                    Cliente(
                        id: id,
                        nombre: nombre,
                        telefono: telefonoCtrl.text.trim()));
              },
              child: const Text("Guardar"),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Nombre",
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Teléfono",
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarAlertaStockInsuficiente(List<String> productos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showArticDialog(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: "⚠️ Stock insuficiente",
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido"),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "No se puede procesar la venta. Revisa estos productos:",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 10),
            ...productos.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(
                "• $p",
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
