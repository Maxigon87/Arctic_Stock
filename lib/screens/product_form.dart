import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ArticStock/services/db_service.dart'; // <- ajusta si tu ruta/case es distinto

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
  final _stockCtrl = TextEditingController(); // 👈 NUEVO

  int? _categoriaId;
  List<Map<String, dynamic>> _categorias = [];
  bool _saving = false;

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
      _stockCtrl.text = (i['stock'] ?? 0).toString(); // 👈 inicializa stock
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
    _stockCtrl.dispose(); // 👈 libera
    super.dispose();
  }

  String _numToStr(dynamic n) {
    if (n == null) return '';
    if (n is num) return n.toStringAsFixed(2);
    final parsed = double.tryParse(n.toString());
    return parsed?.toStringAsFixed(2) ?? '';
  }

  double _toDouble(String s) {
    // acepta coma o punto y quita separadores de miles
    s = s.trim().replaceAll('.', '').replaceAll(',', '.');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  Future<void> _loadCategorias() async {
    final cats = await DBService().getCategorias();
    if (!mounted) return;
    setState(() => _categorias = cats);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final costo = _toDouble(_costoCtrl.text);
    final precio = _toDouble(_precioCtrl.text);

    // Aviso si vende con pérdida
    if (precio < costo) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Atención'),
          content: const Text(
              'El precio de venta es menor que el costo de compra.\n¿Querés guardar igual?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar igual')),
          ],
        ),
      );
      if (continuar != true) return;
    }

    final data = {
      'codigo':
          _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
      'nombre': _nombreCtrl.text.trim(),
      'descripcion':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'costo_compra': costo,
      'precio_venta': precio,
      'stock': int.tryParse(_stockCtrl.text) ??
          (widget.initial?['stock'] ?? 0), // 👈 guarda stock
      'categoria_id': _categoriaId,
    };

    setState(() => _saving = true);
    try {
      if (widget.initial == null) {
        await DBService().insertProducto(data);
      } else {
        await DBService().updateProducto(data, widget.initial!['id'] as int);
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código (único)',
                hintText: 'EJ: ABC-123',
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
            DropdownButtonFormField<int>(
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
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Utilidad por unidad'),
              subtitle: Text(utilidad.toStringAsFixed(2)),
              trailing: Icon(
                utilidad < 0 ? Icons.warning_amber : Icons.check_circle_outline,
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
    );
  }
}
