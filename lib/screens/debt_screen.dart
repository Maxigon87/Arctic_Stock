import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({Key? key}) : super(key: key);

  @override
  _DebtScreenState createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  late Future<List<Map<String, dynamic>>> _deudasFuture;
  List<Map<String, dynamic>> _deudasFiltradas = [];
  String _filtroEstado = "";
  Cliente? _clienteSeleccionado;
  List<Cliente> _clientes = [];

  @override
  void initState() {
    super.initState();
    _loadDeudas();
    _cargarClientes();
  }

  void _loadDeudas() {
    setState(() {
      _deudasFuture = DBService().getDeudas();
    });
  }

  Future<void> _cargarClientes() async {
    _clientes = await DBService().getClientes();
    setState(() {});
  }

  void _agregarClienteRapido() {
    final nombreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuevo Cliente"),
        content: TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(labelText: "Nombre")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              final existe = _clientes.any((c) => c.nombre == nombreCtrl.text);
              if (existe) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("⚠️ El cliente ya existe")),
                );
                return;
              }

              final nuevo = Cliente(nombre: nombreCtrl.text);
              final id = await DBService().insertCliente(nuevo);
              _clienteSeleccionado = Cliente(id: id, nombre: nombreCtrl.text);
              await _cargarClientes();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _showAddDeudaDialog() {
    double monto = 0;
    String estado = "Pendiente";
    String descripcion = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Registrar Deuda"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<Cliente>(
                      value: _clienteSeleccionado,
                      hint: const Text("Seleccionar cliente"),
                      isExpanded: true,
                      items: [
                        ..._clientes.map((c) =>
                            DropdownMenuItem(value: c, child: Text(c.nombre))),
                        const DropdownMenuItem(
                            value: null,
                            child: Text("➕ Agregar nuevo cliente")),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          _agregarClienteRapido();
                        } else {
                          setStateSB(() => _clienteSeleccionado = value);
                        }
                      },
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: "Monto"),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => monto = double.tryParse(val) ?? 0,
                    ),
                    DropdownButton<String>(
                      value: estado,
                      items: ["Pendiente", "Pagada"]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setStateSB(() => estado = val!),
                    ),
                    TextField(
                      decoration:
                          const InputDecoration(labelText: "Descripción"),
                      maxLines: 2,
                      onChanged: (val) => descripcion = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (_clienteSeleccionado == null || monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("⚠️ Selecciona cliente y monto válido")),
                      );
                      return;
                    }

                    await DBService().insertDeuda({
                      'clienteId': _clienteSeleccionado!.id,
                      'monto': monto,
                      'fecha': DateTime.now().toIso8601String(),
                      'estado': estado,
                      'descripcion': descripcion,
                    });

                    Navigator.pop(context);
                    _loadDeudas();
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deudas')),
      body: Column(
        children: [
          // 🔹 Buscador de cliente
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Buscar cliente...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) async {
                if (val.isEmpty) {
                  setState(() => _deudasFiltradas = []);
                } else {
                  final results = await DBService().buscarDeudas(cliente: val);
                  setState(() => _deudasFiltradas = results);
                }
              },
            ),
          ),

          // 🔹 Filtro por estado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _filtroEstado.isEmpty ? null : _filtroEstado,
              isExpanded: true,
              hint: const Text("Filtrar por estado"),
              items: ["Pendiente", "Pagada"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) async {
                _filtroEstado = val ?? "";
                if (_filtroEstado.isEmpty) {
                  setState(() => _deudasFiltradas = []);
                } else {
                  final results =
                      await DBService().buscarDeudas(estado: _filtroEstado);
                  setState(() => _deudasFiltradas = results);
                }
              },
            ),
          ),

          // 🔹 Lista de deudas
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _deudasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final deudas = _deudasFiltradas.isNotEmpty
                    ? _deudasFiltradas
                    : (snapshot.data ?? []);

                if (deudas.isEmpty) {
                  return const Center(
                      child: Text('No hay deudas registradas 💸'));
                }

                return ListView.builder(
                  itemCount: deudas.length,
                  itemBuilder: (context, index) {
                    final d = deudas[index];
                    return ListTile(
                      title: Text('${d['cliente']} - \$${d['monto']}'),
                      subtitle: Text(
                          'Estado: ${d['estado']}\n${d['descripcion'] ?? ''}'),
                      trailing: Text(d['fecha'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeudaDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
