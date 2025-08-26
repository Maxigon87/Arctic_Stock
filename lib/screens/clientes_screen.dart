import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  late Future<List<Cliente>> _clientesFuture;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  void _loadClientes() {
    setState(() {
      _clientesFuture = DBService().getClientes();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showClienteDialog({Cliente? cliente}) {
    final nombreCtrl = TextEditingController(text: cliente?.nombre ?? '');
    final telefonoCtrl = TextEditingController(text: cliente?.telefono ?? '');
    final emailCtrl = TextEditingController(text: cliente?.email ?? '');
    final direccionCtrl = TextEditingController(text: cliente?.direccion ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(cliente == null ? "Nuevo Cliente" : "Editar Cliente"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: "Nombre")),
              TextField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: "Teléfono")),
              TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email")),
              TextField(
                  controller: direccionCtrl,
                  decoration: const InputDecoration(labelText: "Dirección")),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("⚠️ El nombre es obligatorio")),
                );
                return;
              }

              final lista = await DBService().getClientes();
              final existe = lista.any((c) =>
                  c.nombre.toLowerCase() == nombreCtrl.text.toLowerCase() &&
                  c.id != cliente?.id);

              if (existe) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("⚠️ Ya existe un cliente con ese nombre")),
                );
                return;
              }

              final nuevo = Cliente(
                id: cliente?.id,
                nombre: nombreCtrl.text,
                telefono: telefonoCtrl.text,
                email: emailCtrl.text,
                direccion: direccionCtrl.text,
              );

              if (cliente == null) {
                await DBService().insertCliente(nuevo);
              } else {
                await DBService().updateCliente(nuevo);
              }

              Navigator.pop(context);
              _loadClientes();
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCliente(int id) async {
    await DBService().deleteCliente(id);
    _loadClientes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Clientes")),
      body: ArticBackground(
        child: ArticContainer(
          child: FutureBuilder<List<Cliente>>(
            future: _clientesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final clientes = snapshot.data ?? [];
              final filtrados = clientes
                  .where((c) =>
                      c.nombre.toLowerCase().contains(_search.toLowerCase()))
                  .toList();

              return Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar cliente',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: clientes.isEmpty
                        ? const Center(
                            child: Text("No hay clientes registrados"),
                          )
                        : filtrados.isEmpty
                            ? const Center(
                                child:
                                    Text("No se encontraron clientes"),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: filtrados.length,
                                itemBuilder: (context, index) {
                                  final c = filtrados[index];
                                  return Card(
                                    elevation: 3,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: ListTile(
                                      title: Text(c.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(c.telefono ?? "",
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.7),
                                              fontSize: 13)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.orange),
                                            onPressed: () =>
                                                _showClienteDialog(
                                                    cliente: c),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteCliente(c.id!),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClienteDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
