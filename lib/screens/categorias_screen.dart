import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../widgets/artic_dialog.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final db = DBService();
  final TextEditingController _nombreCtrl = TextEditingController();
  List<Map<String, dynamic>> categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final data = await db.getCategorias();
    setState(() => categorias = data);
  }

  Future<void> _agregarCategoria() async {
    if (_nombreCtrl.text.isEmpty) return;
    await db.insertCategoria(_nombreCtrl.text);
    _nombreCtrl.clear();
    _cargarCategorias();
  }

  Future<void> _editarCategoria(int id, String currentName) async {
    final nuevo = await _mostrarDialogoEditar(currentName);
    if (nuevo != null && nuevo.isNotEmpty) {
      await db.updateCategoria(id, nuevo);
      _cargarCategorias();
    }
  }

  Future<String?> _mostrarDialogoEditar(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showArticDialog<String>(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: "Editar Categoría",
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text("Guardar")),
        ],
        child: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: "Nombre de la categoría",
            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarCategoria(int id, String name) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conf = await showArticDialog<bool>(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: "Eliminar Categoría",
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Eliminar")),
        ],
        child: Text(
          "¿Seguro que deseas eliminar la categoría '$name'? Esta acción no se puede deshacer.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
    if (conf == true) {
      await db.deleteCategoria(id);
      _cargarCategorias();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Categorías")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _nombreCtrl,
                        decoration:
                            InputDecoration(labelText: "Nueva categoría"))),
                IconButton(onPressed: _agregarCategoria, icon: Icon(Icons.add)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categorias.length,
              itemBuilder: (context, i) {
                final c = categorias[i];
                return ListTile(
                  title: Text(c['nombre']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () => _editarCategoria(c['id'], c['nombre']),
                          icon: Icon(Icons.edit)),
                      IconButton(
                          onPressed: () => _eliminarCategoria(c['id'], c['nombre']),
                          icon: Icon(Icons.delete, color: Colors.red)),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
