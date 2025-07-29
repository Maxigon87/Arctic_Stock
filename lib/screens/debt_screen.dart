import 'package:flutter/material.dart';
import '../services/db_service.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({Key? key}) : super(key: key);

  @override
  _DebtScreenState createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  late Future<List<Map<String, dynamic>>> _deudasFuture;

  @override
  void initState() {
    super.initState();
    _loadDeudas();
  }

  void _loadDeudas() {
    setState(() {
      _deudasFuture = DBService().getDeudas();
    });
  }

  void _showAddDeudaDialog() {
    String cliente = "";
    double monto = 0;
    String metodoPago = "Pendiente";
    String descripcion = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Registrar Deuda"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: "Cliente"),
                      onChanged: (val) => cliente = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: "Monto"),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => monto = double.tryParse(val) ?? 0,
                    ),
                    DropdownButton<String>(
                      value: metodoPago,
                      items:
                          ["Pendiente", "Efectivo", "Transferencia", "Tarjeta"]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => metodoPago = val!),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Descripción",
                      ),
                      maxLines: 2,
                      onChanged: (val) => descripcion = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (cliente.isEmpty || monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Cliente y monto son obligatorios"),
                        ),
                      );
                      return;
                    }

                    await DBService().insertDeuda({
                      'cliente': cliente,
                      'monto': monto,
                      'fecha': DateTime.now().toIso8601String(),
                      'metodoPago': metodoPago,
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _deudasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final deudas = snapshot.data ?? [];
          if (deudas.isEmpty) {
            return const Center(child: Text('No hay deudas registradas 💸'));
          }
          return ListView.builder(
            itemCount: deudas.length,
            itemBuilder: (context, index) {
              final d = deudas[index];
              return ListTile(
                title: Text('${d['cliente']} - \$${d['monto']}'),
                subtitle: Text(
                  'Pago: ${d['metodoPago'] ?? 'Pendiente'}\n${d['descripcion'] ?? ''}',
                ),
                trailing: Text(d['fecha'] ?? ''),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeudaDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
