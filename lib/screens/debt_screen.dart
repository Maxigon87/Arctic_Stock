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

        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
        final textC = isDark ? Colors.white : const Color(0xFF0F172A);
        final subC = isDark ? Colors.white70 : const Color(0xFF64748B);

        Color statusColor = isPagada ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

        return ArticDialogCard(
          title: 'Detalle de Deuda',
          child: SizedBox(
            width: 480,
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
                              "Monto Deuda",
                              style: TextStyle(
                                fontSize: 11,
                                color: subC,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              monto,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isPagada ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
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
                              "Estado",
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
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
                              ),
                              child: Text(
                                estado,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
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

                // Resumen Card
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
                        "Información General",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textC,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDetailRow('Número de Deuda', '#$id', subC),
                      Divider(height: 20, color: borderColor),
                      _buildDialogDetailRow('Cliente', cliente, subC),
                      Divider(height: 20, color: borderColor),
                      _buildDialogDetailRow('Fecha Registro', fecha, subC),
                      Divider(height: 20, color: borderColor),
                      _buildDialogDetailRow('Descripción', descripcion.isNotEmpty ? descripcion : 'Sin descripción', subC),
                    ],
                  ),
                ),

                if (ventaId != null) ...[
                  const SizedBox(height: 16),
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
                          'Productos en la Venta',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textC,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
                                itemBuilder: (_, index) {
                                  final it = items[index];
                                  final cantidad = it['cantidad'];
                                  final producto = it['producto'] ?? '';
                                  final subtotal = _fmtMoneda(it['subtotal']);
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$cantidad x $producto',
                                          style: TextStyle(color: textC, fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        subtotal,
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                if (!isPagada)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () async {
                      await dbService.markDeudaAsPagada(
                          id, (deuda['monto'] as num).toDouble());
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _loadDeudas();
                    },
                    label: const Text('Saldar deuda', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () async {
                      await dbService.revertirDeudaAPendiente(id);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _loadDeudas();
                    },
                    label: const Text('Volver a deuda', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final conf = await showArticDialog<bool>(
                      context: context,
                      builder: (c) => ArticDialogCard(
                        title: "Eliminar Deuda",
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text("Eliminar"),
                          ),
                        ],
                        child: Text(
                          "¿Está seguro que desea eliminar esta deuda por $monto? Esta acción no se puede deshacer.",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                    if (conf == true) {
                      await dbService.deleteDeuda(id);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _loadDeudas();
                    }
                  },
                  label: const Text("Eliminar deuda", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
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
                                cardColor = Colors.green.withOpacity(0.08);
                                borderSide = BorderSide(
                                  color: Colors.green.withOpacity(isDark ? 0.3 : 0.4),
                                  width: 1,
                                );
                              } else if (highlight) {
                                cardColor = Colors.red.withOpacity(0.08);
                                borderSide = BorderSide(
                                  color: Colors.red.withOpacity(isDark ? 0.3 : 0.4),
                                  width: 1,
                                );
                              } else {
                                cardColor = isDark
                                    ? Colors.white.withOpacity(0.02)
                                    : Colors.white.withOpacity(0.45);
                                borderSide = BorderSide(
                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
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
