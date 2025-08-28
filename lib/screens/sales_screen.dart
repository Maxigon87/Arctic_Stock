import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:confetti/confetti.dart';
import '../models/cliente.dart';
import '../Services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../screens/product_list_screen.dart';
import '../Services/file_helper.dart';
import '../utils/file_namer.dart';
import '../utils/currency_formatter.dart';
import 'dart:async' as dart_async;
import 'dart:async';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final dbService = DBService();
  dart_async.Timer? _debounce;

  // Filtros de búsqueda de ventas
  Cliente? _clienteSeleccionado;
  String? metodoSeleccionado;
  DateTime? desde;
  DateTime? hasta;
  List<Cliente> _clientes = [];

  final _productoCtrl = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _productoCtrl.dispose();
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
    _ventasFuture = dbService.getVentas();
    _cargarClientes();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 500));
  }

  Future<void> _verDetalleVenta(int ventaId) async {
    try {
      // header (cliente, vendedor, total, fecha, etc.)
      final header = await dbService.getVentaById(ventaId);
      // ítems de la venta
      final items = await dbService.getItemsByVenta(ventaId);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scroll) {
              final cliente =
                  (header?['clienteNombre']?.toString().isNotEmpty ?? false)
                      ? header!['clienteNombre']
                      : 'Consumidor Final';
              final vendedor =
                  (header?['usuarioNombre']?.toString().isNotEmpty ?? false)
                      ? header!['usuarioNombre']
                      : '—';
              final total = (header?['total'] as num?)?.toDouble() ?? 0.0;
              final fecha =
                  (header?['fecha']?.toString().split('T').first) ?? '';

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.receipt_long),
                          const SizedBox(width: 8),
                          Text("Venta #$ventaId",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(fecha,
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Chip(label: Text("Cliente: $cliente")),
                          Chip(label: Text("Vendedor: $vendedor")),
                          Chip(
                              label: Text(
                                  "Método: ${header?['metodoPago'] ?? '—'}")),
                          Chip(label: Text("Total: ${formatCurrency(total)}")),
                        ],
                      ),

                      const SizedBox(height: 10),
                      const Divider(),

                      const Text("Productos",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Lista de items
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text("Sin ítems"))
                            : ListView.builder(
                                controller: scroll,
                                itemCount: items.length,
                                itemBuilder: (_, i) {
                                  final it = items[i];
                                  final nombre = it['producto'] ?? 'Producto';
                                  final codigo =
                                      (it['codigo']?.toString().isNotEmpty ??
                                              false)
                                          ? " · Código: ${it['codigo']}"
                                          : "";
                                  final cant =
                                      (it['cantidad'] as num?)?.toInt() ?? 0;
                                  final pu = (it['precioUnitario'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final cu = (it['costoUnitario'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final sub =
                                      (it['subtotal'] as num?)?.toDouble() ??
                                          (pu * cant);

                                  return ListTile(
                                    dense: true,
                                    title: Text("$nombre"),
                                    subtitle: Text(
                                      "Cant: $cant · PU: ${formatCurrency(pu)} · Costo: ${formatCurrency(cu)}$codigo",
                                    ),
                                    trailing: Text(formatCurrency(sub),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  );
                                },
                              ),
                      ),

                      const Divider(),

                      // Total y acciones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Text("TOTAL: ${formatCurrency(total)}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              )),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share),
                                tooltip: 'Compartir comprobante',
                                onPressed: () =>
                                    _compartirComprobante(header!, items),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download),
                                tooltip: 'Guardar comprobante',
                                onPressed: () =>
                                    _guardarComprobante(header!, items),
                              ),
                              IconButton(
                                icon: const Icon(Icons.print),
                                tooltip: 'Imprimir comprobante',
                                onPressed: () =>
                                    _imprimirComprobante(header!, items),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cerrar"),
                              ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
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
      );
    });
  }

  // --- Helpers carrito / stock ------------------------------------------------

  Future<int> _stockDisponible(int productoId) async {
    final p = await dbService.getProductoById(productoId);
    return (p?['stock'] as num?)?.toInt() ?? 0;
  }

  Future<bool> _confirmarPerdidaDialog(double precio, double costo) async {
    if (precio >= costo) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atención'),
        content: Text(
          'Este producto se venderá con pérdida.\n'
          'Precio: ${formatCurrency(precio)} | Costo: ${formatCurrency(costo)}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Continuar')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _agregarAlCarrito(Map<String, dynamic> producto) async {
    final int id = producto['id'] as int;
    final int stock = await _stockDisponible(id);
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ Este producto no tiene stock disponible")),
      );
      return;
    }
    final TextEditingController cantCtrl = TextEditingController(text: '1');
    final int? cantidad = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cantidad'),
          content: TextField(
            controller: cantCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, int.tryParse(cantCtrl.text) ?? 0),
                child: const Text('Agregar')),
          ],
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
        }
      }
    });
  }

  // --- BottomSheet carrito ----------------------------------------------------
  void _abrirCarrito() {
    bool clienteConDeudas = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scroll) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              final double totalCarrito = _carrito.fold<double>(
                0.0,
                (sum, p) => sum + (p['subtotal'] as num).toDouble(),
              );

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "🛒 Nueva Venta",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Cliente
                    DropdownButtonFormField<Cliente?>(
                      value: _clienteSeleccionado,
                      hint: const Text("Cliente (opcional)"),
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
                          final count =
                              await dbService.countDeudasCliente(value.id!);
                          final muchas = count > 1;
                          setLocalState(() => clienteConDeudas = muchas);
                          if (muchas) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'El cliente tiene múltiples deudas pendientes'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          setLocalState(() => clienteConDeudas = false);
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.person_add, color: Colors.teal),
                      label: const Text("Agregar Cliente"),
                      onPressed: () async {
                        final nuevo = await _showNuevoClienteDialog();
                        if (nuevo != null) {
                          setState(() => _clientes.add(nuevo));
                          setLocalState(() => _clienteSeleccionado = nuevo);
                        }
                      },
                    ),

                    if (clienteConDeudas)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'El cliente tiene múltiples deudas pendientes',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Método de pago
                    DropdownButtonFormField<String>(
                      value: metodoSeleccionado ?? "Efectivo",
                      hint: const Text("Método de Pago"),
                      items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => metodoSeleccionado = value),
                    ),

                    const SizedBox(height: 15),

                    // Lista del carrito
                    Expanded(
                      child: _carrito.isEmpty
                          ? const Center(child: Text("Carrito vacío"))
                          : ListView.builder(
                              controller: scroll,
                              itemCount: _carrito.length,
                              itemBuilder: (_, i) {
                                final p = _carrito[i];
                                final double precioUnit =
                                    (p['precioUnit'] as num).toDouble();
                                final double costoUnit =
                                    (p['costoUnit'] as num).toDouble();
                                final int cantidad =
                                    (p['cantidad'] as num).toInt();
                                final double subtotal =
                                    (p['subtotal'] as num).toDouble();
                                final bool conPerdida = precioUnit < costoUnit;

                                return Column(
                                  children: [
                                    ListTile(
                                      title:
                                          Text(p['nombre']?.toString() ?? ''),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ((p['codigo']
                                                  ?.toString()
                                                  .isNotEmpty ??
                                              false))
                                            Text('Código: ${p['codigo']}'),
                                          Text(
                                            "Precio: ${formatCurrency(precioUnit)}  |  Costo: ${formatCurrency(costoUnit)}",
                                            style: TextStyle(
                                              color: conPerdida
                                                  ? Colors.red
                                                  : null,
                                              fontWeight: conPerdida
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),

                                          // --- Cantidad editable ---
                                          Row(
                                            children: [
                                              const Text('Cant:'),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 70,
                                                child: TextFormField(
                                                  initialValue:
                                                      cantidad.toString(),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  textAlign: TextAlign.center,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                          isDense: true),
                                                  onChanged: (value) async {
                                                    final nuevaCantidad =
                                                        int.tryParse(value) ??
                                                            0;

                                                    if (nuevaCantidad <= 0) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                'Cantidad inválida')),
                                                      );
                                                      setLocalState(() {
                                                        final actual =
                                                            (p['cantidad']
                                                                    as num)
                                                                .toInt();
                                                        final precio =
                                                            (p['precioUnit']
                                                                    as num)
                                                                .toDouble();
                                                        p['cantidad'] = actual;
                                                        p['subtotal'] =
                                                            precio * actual;
                                                      });
                                                      return;
                                                    }

                                                    final stock =
                                                        await _stockDisponible(
                                                            p['productoId']
                                                                as int);
                                                    if (nuevaCantidad > stock) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                'Solo hay $stock unidades disponibles')),
                                                      );
                                                      setLocalState(() {
                                                        final actual =
                                                            (p['cantidad']
                                                                    as num)
                                                                .toInt();
                                                        final precio =
                                                            (p['precioUnit']
                                                                    as num)
                                                                .toDouble();
                                                        p['cantidad'] = actual;
                                                        p['subtotal'] =
                                                            precio * actual;
                                                      });
                                                      return;
                                                    }

                                                    final precio =
                                                        (p['precioUnit'] as num)
                                                            .toDouble();
                                                    setLocalState(() {
                                                      p['cantidad'] =
                                                          nuevaCantidad;
                                                      p['subtotal'] = precio *
                                                          nuevaCantidad;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),

                                          Text("Subtotal: ${formatCurrency(subtotal)}"),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => setLocalState(
                                            () => _carrito.removeAt(i)),
                                      ),
                                    ),
                                    if (i < _carrito.length - 1)
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 4),
                                        child: Divider(
                                            thickness: 1, color: Colors.grey),
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),

                    // TOTAL
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.centerRight,
                      child: Text(
                        "TOTAL: ${formatCurrency(totalCarrito)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),

                    // Agregar producto
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Agregar Producto"),
                      onPressed: () async {
                        final producto = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProductListScreen(selectMode: true),
                          ),
                        );
                        if (producto != null) {
                          await _agregarAlCarrito(producto);
                          setLocalState(() {}); // refrescar sheet
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    // Confirmar venta
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Confirmar Venta"),
                      onPressed: _confirmarVenta,
                    ),
                  ],
                ),
              );
            },
          );
        },
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

    final double total =
        _carrito.fold(0.0, (sum, i) => sum + (i['subtotal'] as num).toDouble());

    try {
      final ventaId = await dbService.insertVentaBase({
        'clienteId': _clienteSeleccionado?.id,
        'fecha': DateTime.now().toIso8601String(),
        'metodoPago': metodoSeleccionado ?? 'Efectivo',
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
      Navigator.pop(context); // cierra el bottom sheet

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

  Widget _buildFiltros() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<Cliente?>(
                hint: const Text("Cliente (opcional)"),
                value: _clienteSeleccionado,
                items: [
                  const DropdownMenuItem<Cliente?>(
                      value: null, child: Text("Consumidor Final")),
                  ..._clientes.map((c) => DropdownMenuItem<Cliente?>(
                      value: c, child: Text(c.nombre))),
                ],
                onChanged: (value) {
                  setState(() => _clienteSeleccionado = value);
                  _cargarVentasFiltradas();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                hint: const Text("Método de Pago"),
                value: metodoSeleccionado,
                items: ["Efectivo", "Tarjeta", "Transferencia", "Fiado"]
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  setState(() => metodoSeleccionado = value);
                  _cargarVentasFiltradas();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () async {
            final rango = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2022),
              lastDate: DateTime.now(),
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
          child: const Text("Filtrar por Fecha"),
        ),
        const SizedBox(height: 10),

        // 👇 Campo de búsqueda de productos
        TextField(
          controller: _productoCtrl,
          decoration: const InputDecoration(
            labelText: 'Buscar producto por nombre o código',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = dart_async.Timer(
              const Duration(milliseconds: 350),
              _cargarVentasFiltradas,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ventas")),
      body: Stack(
        children: [
          ArticBackground(
            child: ArticContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              _buildFiltros(),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ventasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No hay ventas"));
                    }
                    final ventas = snapshot.data!;
                    return ListView.builder(
                      itemCount: ventas.length,
                      itemBuilder: (context, index) {
                        final v = ventas[index];
                        final cliente =
                            (v['clienteNombre']?.toString().isNotEmpty ?? false)
                                ? v['clienteNombre']
                                : 'Consumidor Final';
                        final vendedor =
                            (v['usuarioNombre']?.toString().isNotEmpty ?? false)
                                ? v['usuarioNombre']
                                : '—';

                        return Card(
                          child: ListTile(
                              title: Text("Venta #${v['id']} - $cliente"),
                              subtitle: Text(
                                "Total: ${formatCurrency(v['total'])} · "
                                "Método: ${v['metodoPago']} · "
                                "Vendedor: $vendedor",
                              ),
                              trailing:
                                  Text(v['fecha'].toString().split('T').first),
                              onTap: () => _verDetalleVenta(v['id']) as int),
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
        onPressed: _abrirCarrito,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  // --- Utilidades varias ------------------------------------------------------

  Future<Cliente?> _showNuevoClienteDialog() async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();

    return showDialog<Cliente>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Nuevo Cliente"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: "Nombre")),
              TextField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: "Teléfono")),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar")),
            ElevatedButton(
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
        );
      },
    );
  }

  void _mostrarAlertaStockInsuficiente(List<String> productos) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚠️ Stock insuficiente"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "No se puede procesar la venta. Revisa estos productos:"),
            const SizedBox(height: 10),
            ...productos.map((p) => Text("• $p")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }
}
