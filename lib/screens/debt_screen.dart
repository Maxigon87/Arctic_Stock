import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../widgets/artic_empty_state.dart';
import 'package:intl/intl.dart';
import '../widgets/artic_dialog.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  _DebtScreenState createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  late Future<List<Map<String, dynamic>>> _deudasFuture;
  List<Map<String, dynamic>> _deudasFiltradas = [];
  String _filtroEstado = "";
  Cliente? _clienteSeleccionado;
  List<Cliente> _clientes = [];
  String? estadoSeleccionado;
  DateTime? desde;
  DateTime? hasta;

  final dbService = DBService();

  String _fmtFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : iso;
  }

  String _fmtMoneda(dynamic v) {
    final n = (v as num?)?.toDouble() ?? 0;
    return NumberFormat.currency(locale: 'es_AR', symbol: r'$').format(n);
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showArticDialog(
      context: context,
      builder: (_) => ArticDialogCard(
        title: "Nuevo Cliente",
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
        child: TextField(
            controller: nombreCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Nombre",
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            )),
      ),
    );
  }

  void _showAddDeudaDialog() {
    double monto = 0;
    String estado = "Pendiente";
    String descripcion = "";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showArticDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return ArticDialogCard(
              title: "Registrar Deuda",
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Cliente>(
                    value: _clienteSeleccionado,
                    hint: const Text("Seleccionar cliente"),
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Monto",
                      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => monto = double.tryParse(val) ?? 0,
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: estado,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    items: ["Pendiente", "Pagada"]
                        .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setStateSB(() => estado = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Descripción",
                      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    maxLines: 2,
                    onChanged: (val) => descripcion = val,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
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

  Future<void> _verDetalleDeuda(Map<String, dynamic> deuda) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showArticDialog(
      context: context,
      builder: (ctx) {
        final cliente =
            (deuda['clienteNombre']?.toString().isNotEmpty ?? false)
                ? deuda['clienteNombre']
                : 'Consumidor Final';
        final monto = _fmtMoneda(deuda['monto']);
        final fecha = _fmtFecha(deuda['fecha']);
        final estado = deuda['estado'] ?? '';
        final descripcion = deuda['descripcion'] ?? '';
        final id = deuda['id'] as int;
        final int? ventaId = deuda['ventaId'] as int?;
        final isPagada = estado == 'Pagada';

        return ArticDialogCard(
          title: 'Deuda #$id',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fecha,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDetailBadge("Cliente: $cliente", isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7), isDark),
                  _buildDetailBadge("Estado: $estado", isPagada ? Colors.green : Colors.orange, isDark),
                  _buildDetailBadge("Monto: $monto", isPagada ? Colors.green : Colors.redAccent, isDark),
                ],
              ),
              const SizedBox(height: 16),
              if (descripcion.toString().isNotEmpty) ...[
                Text(
                  'Descripción',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (ventaId != null) ...[
                Text(
                  'Productos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: dbService.getItemsByVenta(ventaId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Text('Sin productos');
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final it = items[index];
                          final cantidad = it['cantidad'];
                          final producto = it['producto'] ?? '';
                          final subtotal = _fmtMoneda(it['subtotal']);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '$cantidad x $producto',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            ),
                            trailing: Text(
                              subtotal,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 12),
              if (!isPagada)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await dbService.markDeudaAsPagada(
                        id, (deuda['monto'] as num).toDouble());
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadDeudas();
                  },
                  child: const Text('Saldar deuda'),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await dbService.revertirDeudaAPendiente(id);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadDeudas();
                  },
                  child: const Text('Volver a deuda'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cargarDeudasFiltradas() async {
    setState(() {
      _deudasFuture = dbService.buscarDeudasAvanzado(
        clienteId: _clienteSeleccionado?.id,
        estado: estadoSeleccionado,
        desde: desde,
        hasta: hasta,
      );
    });
  }

  Widget _buildFiltros() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<Cliente>(
                hint: Text("Cliente"),
                value: _clienteSeleccionado,
                items: _clientes.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.nombre));
                }).toList(),
                onChanged: (value) {
                  setState(() => _clienteSeleccionado = value);
                  _cargarDeudasFiltradas();
                },
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                hint: Text("Estado"),
                value: estadoSeleccionado,
                items: ["Pendiente", "Pagada"].map((e) {
                  return DropdownMenuItem(value: e, child: Text(e));
                }).toList(),
                onChanged: (value) {
                  setState(() => estadoSeleccionado = value);
                  _cargarDeudasFiltradas();
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () async {
            final rango = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2022),
              lastDate: DateTime.now(),
            );
            if (rango != null) {
              setState(() {
                desde = rango.start;
                hasta = rango.end;
              });
              _cargarDeudasFiltradas();
            }
          },
          child: Text("Filtrar por Fecha"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Deudas",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ArticContainer(
                maxWidth: 1000,
                child: Column(
                  children: [
                    // 🔹 Buscador de cliente
                    TextField(
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Buscar cliente...",
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      onChanged: (val) async {
                        if (val.isEmpty) {
                          setState(() => _deudasFiltradas = []);
                        } else {
                          final results =
                              await DBService().buscarDeudas(cliente: val);
                          setState(() => _deudasFiltradas = results);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // 🔹 Filtro por estado
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _filtroEstado.isEmpty ? null : _filtroEstado,
                          isExpanded: true,
                          hint: Text(
                            "Filtrar por estado",
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: ["Pendiente", "Pagada"]
                              .map((e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ))
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
                    ),

                    const SizedBox(height: 16),

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
                            return ArticEmptyState(
                              icon: Icons.money_off,
                              title: "Sin deudas",
                              description: "No hay registros de deudas. Todo marcha al día en tus cuentas comerciales.",
                              buttonText: "Registrar deuda",
                              onButtonPressed: _showAddDeudaDialog,
                            );
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: deudas.length,
                            itemBuilder: (context, index) {
                              final d = deudas[index];
                              final count = d['pendientesCount'] as int? ?? 0;
                              final highlight = count > 3;
                              final isPagada = d['estado'] == 'Pagada';

                              Color cardColor;
                              BorderSide borderSide;

                              if (isPagada) {
                                cardColor = Colors.green.withValues(alpha: 0.08);
                                borderSide = BorderSide(
                                  color: Colors.green.withValues(alpha: isDark ? 0.3 : 0.4),
                                  width: 1,
                                );
                              } else if (highlight) {
                                cardColor = Colors.red.withValues(alpha: 0.08);
                                borderSide = BorderSide(
                                  color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.4),
                                  width: 1,
                                );
                              } else {
                                cardColor = isDark
                                    ? Colors.white.withValues(alpha: 0.02)
                                    : Colors.white.withValues(alpha: 0.45);
                                borderSide = BorderSide(
                                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                                  width: 1,
                                );
                              }

                              return Card(
                                color: cardColor,
                                surfaceTintColor: Colors.transparent,
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: borderSide,
                                ),
                                child: ListTile(
                                  onTap: () => _verDetalleDeuda(d),
                                  title: Text(
                                    '${d['clienteNombre'] ?? 'Consumidor Final'} - ${_fmtMoneda(d['monto'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: highlight && !isPagada
                                          ? Colors.redAccent
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Estado: ${d['estado']}\n${d['descripcion'] ?? ''}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  trailing: Text(
                                    _fmtFecha(d['fecha']),
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeudaDialog,
        backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
