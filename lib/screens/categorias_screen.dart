import 'package:flutter/material.dart';
import '../Services/db_service.dart';

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

  Future<void> _editarCategoria(int id) async {
    final nuevo = await _mostrarDialogoEditar();
    if (nuevo != null && nuevo.isNotEmpty) {
      await db.updateCategoria(id, nuevo);
      _cargarCategorias();
    }
  }

  Future<String?> _mostrarDialogoEditar() async {
    String nuevoNombre = "";
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar Categoría"),
        content: TextField(onChanged: (v) => nuevoNombre = v),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(context, nuevoNombre),
              child: Text("Guardar")),
        ],
      ),
    );
  }

  Future<void> _eliminarCategoria(int id) async {
    await db.deleteCategoria(id);
    _cargarCategorias();
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
                          onPressed: () => _editarCategoria(c['id']),
                          icon: Icon(Icons.edit)),
                      IconButton(
                          onPressed: () => _eliminarCategoria(c['id']),
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
