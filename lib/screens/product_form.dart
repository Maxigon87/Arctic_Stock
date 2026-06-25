import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:artic_stock/services/db_service.dart'; // <- ajusta si tu ruta/case es distinto
import 'package:artic_stock/widgets/artic_background.dart';
import 'package:artic_stock/widgets/artic_container.dart';
import 'package:artic_stock/widgets/artic_dialog.dart';
import '../widgets/artic_barcode_scanner.dart';
import '../utils/currency_formatter.dart';
import '../services/image_service.dart';
import '../widgets/artic_cached_image.dart';

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? initial; // null = crear, con datos = editar
  const ProductForm({super.key, this.initial});

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();

  final _codigoCtrl = TextEditingController();

  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  int? _categoriaId;
  List<Map<String, dynamic>> _categorias = [];
  bool _saving = false;
  Uint8List? _selectedImageBytes;
  bool _clearImage = false;

  Future<void> _pickImage() async {
    final bytes = await ImageService().pickImage(context);
    if (bytes != null) {
      final processed = await ImageService().processImage(bytes);
      if (processed != null) {
        setState(() {
          _selectedImageBytes = processed;
          _clearImage = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategorias();

    // preload si es edición
    final i = widget.initial;
    if (i != null) {
      _codigoCtrl.text = (i['codigo'] ?? '').toString();
      _nombreCtrl.text = (i['nombre'] ?? '').toString();
      _descCtrl.text = (i['descripcion'] ?? '').toString();
      _costoCtrl.text = _numToStr(i['costo_compra']);
      _precioCtrl.text = _numToStr(i['precio_venta']);
      _stockCtrl.text = (i['stock'] ?? 0).toString();
      _categoriaId = i['categoria_id'] as int?;
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();

    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  String _numToStr(dynamic n) {
    if (n == null) return '';
    if (n is num) return formatNumber(n);
    final parsed = double.tryParse(n.toString());
    return parsed != null ? formatNumber(parsed) : '';
  }

  double _toDouble(String s) {
    // acepta coma o punto, espacios, y quita separadores de miles
    s = s
        .trim()
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  Future<void> _loadCategorias() async {
    final cats = await DBService().getCategorias();
    if (!mounted) return;
    setState(() => _categorias = cats);
  }

  Future<void> _mostrarDialogoNuevaCategoria() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nombre = await showArticDialog<String>(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: 'Nueva Categoría',
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
        child: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Nombre de la categoría',
            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );

    if (nombre != null && nombre.trim().isNotEmpty) {
      final id = await DBService().insertCategoria(nombre.trim());
      final cats = await DBService().getCategorias();
      if (!mounted) return;
      setState(() {
        _categorias = cats;
        _categoriaId = id;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final costo = _toDouble(_costoCtrl.text);
    final precio = _toDouble(_precioCtrl.text);

    // Aviso si vende con pérdida
    if (precio < costo) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final continuar = await showArticDialog<bool>(
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
                child: const Text('Guardar igual')),
          ],
          child: Text(
            'El precio de venta es menor que el costo de compra.\n¿Querés guardar igual?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      );
      if (continuar != true) return;
    }

    final data = {
      'codigo':
          _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
      'codigoBarras': null,
      'nombre': _nombreCtrl.text.trim(),
      'descripcion':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'costo_compra': costo,
      'precio_venta': precio,
      'stock': int.tryParse(_stockCtrl.text) ??
          (widget.initial?['stock'] ?? 0),
      'categoria_id': _categoriaId,
      'imageUrl': _clearImage ? null : (widget.initial?['imageUrl']),
    };

    setState(() => _saving = true);
    try {
      int productId;
      if (widget.initial == null) {
        productId = await DBService().insertProducto(data);
      } else {
        productId = widget.initial!['id'] as int;
        await DBService().updateProducto(data, productId);
      }

      if (_selectedImageBytes != null) {
        final downloadUrl = await ImageService().uploadProductImage(productId, _selectedImageBytes!);
        if (downloadUrl != null) {
          final db = await DBService().database;
          await db.rawUpdate(
            'UPDATE productos SET imageUrl = ?, synced = 0, last_updated = ? WHERE id = ?',
            [downloadUrl, DateTime.now().toIso8601String(), productId],
          );
          DBService().notifyDbChange();
        }
      } else if (_clearImage) {
        final db = await DBService().database;
        await db.rawUpdate(
          'UPDATE productos SET imageUrl = NULL, synced = 0, last_updated = ? WHERE id = ?',
          [DateTime.now().toIso8601String(), productId],
        );
        DBService().notifyDbChange();
      }

      if (mounted) Navigator.pop(context, true); // devuelve true para refrescar
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('UNIQUE constraint failed') &&
          (msg.contains('productos.codigo') ||
              msg.contains('idx_productos_codigo'))) {
        _showSnack('Código ya usado.');
      } else {
        _showSnack('Error al guardar: $msg');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String txt) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    // preview utilidad por unidad
    final costo = _toDouble(_costoCtrl.text);
    final precio = _toDouble(_precioCtrl.text);
    final utilidad = (precio - costo);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ArticBackground(
          child: ArticContainer(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _selectedImageBytes != null
                                ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                : (!_clearImage && widget.initial?['imageUrl'] != null)
                                    ? ArticCachedImage(
                                        imageUrl: widget.initial!['imageUrl'],
                                        width: 150,
                                        height: 150,
                                        borderRadius: 16,
                                      )
                                    : Container(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF1F5F9),
                                        child: Center(
                                          child: Icon(
                                            Icons.add_a_photo_outlined,
                                            size: 40,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                        if (_selectedImageBytes != null || (!_clearImage && widget.initial?['imageUrl'] != null))
                          Positioned(
                            right: -4,
                            top: -4,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.redAccent,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _selectedImageBytes = null;
                                    _clearImage = true;
                                  });
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera, size: 16, color: Color(0xFF0EA5E9)),
                      label: Text(
                        (_selectedImageBytes != null || (!_clearImage && widget.initial?['imageUrl'] != null))
                            ? 'Cambiar Imagen'
                            : 'Subir Imagen',
                        style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigoCtrl,
                decoration: InputDecoration(
                  labelText: 'Código de Barras',
                  hintText: 'Escanea o escribe el código de barras...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: const Color(0xFF0EA5E9)),
                    onPressed: () async {
                      final barcodeResult = await Navigator.push<String?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ArticBarcodeScanner(),
                        ),
                      );
                      if (barcodeResult != null && barcodeResult.isNotEmpty) {
                        setState(() {
                          _codigoCtrl.text = barcodeResult;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nombre requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costoCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Costo de compra *'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                      ],
                      validator: (v) {
                        final n = _toDouble(v ?? '');
                        if (n <= 0) return 'Costo > 0';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _precioCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Precio de venta *'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                      ],
                      validator: (v) {
                        final n = _toDouble(v ?? '');
                        if (n <= 0) return 'Precio > 0';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                // 👈 Campo de stock
                controller: _stockCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Stock inicial'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim()) ?? 0;
                  if (n < 0) return 'Stock no puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _categoriaId,
                      items: _categorias
                          .map((c) => DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['nombre'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoriaId = v),
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _mostrarDialogoNuevaCategoria();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Utilidad por unidad'),
                subtitle: Text(formatCurrency(utilidad)),
                trailing: Icon(
                  utilidad < 0
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  color: utilidad < 0 ? Colors.amber : null,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(isEdit ? 'Guardar cambios' : 'Crear producto'),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
