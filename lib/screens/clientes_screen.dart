import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cliente.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../widgets/artic_empty_state.dart';
import 'dart:ui';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';
import '../widgets/artic_dialog.dart';

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
    final dniCtrl = TextEditingController(text: cliente?.dni ?? '');
    final telefonoCtrl = TextEditingController(text: cliente?.telefono ?? '');
    final emailCtrl = TextEditingController(text: cliente?.email ?? '');
    final direccionCtrl = TextEditingController(text: cliente?.direccion ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showArticDialog(
      context: context,
      builder: (_) => ArticDialogCard(
        title: cliente == null ? "Nuevo Cliente" : "Editar Cliente",
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

              final email = emailCtrl.text.trim();
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("⚠️ El correo no es válido")),
                );
                return;
              }
              final nuevo = Cliente(
                id: cliente?.id,
                nombre: nombreCtrl.text,
                dni: dniCtrl.text,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dniCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "DNI",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telefonoCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Teléfono",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: direccionCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Dirección",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCliente(int id) async {
    await DBService().deleteCliente(id);
    _loadClientes();
  }

  void _showClienteInfo(Cliente cliente) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    
    showArticDialog(
      context: context,
      builder: (ctx) {
        return ArticDialogCard(
          title: "Detalles del Cliente",
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DBService().getDeudasByCliente(cliente.id ?? 0),
            builder: (context, snapshot) {
              final deudas = snapshot.data ?? [];
              final deudasPendientes = deudas.where((d) => d['estado'] == 'Pendiente').toList();
              final totalDeuda = deudasPendientes.fold<double>(0.0, (sum, d) => sum + ((d['monto'] as num?)?.toDouble() ?? 0.0));

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Large Avatar & Name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.15) : const Color(0xFF0284C7).withOpacity(0.1),
                          child: Text(
                            cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : 'C',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cliente.nombre,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (cliente.dni != null && cliente.dni!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'DNI/CUIT: ${cliente.dni}',
                            style: TextStyle(
                              fontSize: 13,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // KPI Cards Row
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
                                "Deuda Activa",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrency(totalDeuda),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: totalDeuda > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
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
                                "Pendientes",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${deudasPendientes.length}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: deudasPendientes.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Contact Card Section
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
                          "Información de Contacto",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.phone_outlined, "Teléfono", cliente.telefono ?? "No especificado", isDark),
                        Divider(height: 20, color: borderColor),
                        _buildDetailRow(Icons.mail_outline_outlined, "Email", cliente.email ?? "No especificado", isDark),
                        Divider(height: 20, color: borderColor),
                        _buildDetailRow(Icons.location_on_outlined, "Dirección", cliente.direccion ?? "No especificada", isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Shortcuts Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildShortcutButton(
                          icon: Icons.email,
                          label: "Email",
                          color: const Color(0xFF0EA5E9),
                          isDark: isDark,
                          enabled: cliente.email != null && cliente.email!.isNotEmpty,
                          onTap: () async {
                            final Uri emailUri = Uri(
                              scheme: 'mailto',
                              path: cliente.email!,
                            );
                            try {
                              if (await canLaunchUrl(emailUri)) {
                                await launchUrl(emailUri);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("No se pudo abrir el cliente de correo")),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildShortcutButton(
                          icon: Icons.location_on,
                          label: "Dirección",
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                          enabled: cliente.direccion != null && cliente.direccion!.isNotEmpty,
                          onTap: () async {
                            final Uri mapsUri = Uri.parse(
                              "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cliente.direccion!)}"
                            );
                            try {
                              if (await canLaunchUrl(mapsUri)) {
                                await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("No se pudo abrir Google Maps")),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Debt/Account History Card Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Historial de Cuentas / Deudas",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              "${deudas.length} total",
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (deudas.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                "Este cliente no tiene deudas registradas.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: deudas.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final d = deudas[idx];
                                final idDeuda = d['id'] as int;
                                final m = (d['monto'] as num?)?.toDouble() ?? 0.0;
                                final est = d['estado'] ?? 'Pendiente';
                                final f = d['fecha']?.toString().split('T').first ?? '';
                                final desc = d['descripcion'] ?? '';
                                final isPaid = est == 'Pagada';

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  "Deuda #$idDeuda",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isPaid
                                                        ? Colors.green.withOpacity(0.12)
                                                        : Colors.amber.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: isPaid
                                                          ? Colors.green.withOpacity(0.25)
                                                          : Colors.amber.withOpacity(0.25),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isPaid ? "Pagada" : "Pendiente",
                                                    style: TextStyle(
                                                      color: isPaid ? Colors.green : Colors.amber,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              f,
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (desc.toString().isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                desc,
                                                style: TextStyle(
                                                  color: subtitleColor,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formatCurrency(m),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isPaid ? Colors.green : const Color(0xFFEF4444),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          IconButton(
                                            icon: Icon(
                                              isPaid ? Icons.undo : Icons.check_circle_outline,
                                              color: isPaid ? Colors.orange : Colors.green,
                                              size: 18,
                                            ),
                                            tooltip: isPaid ? "Volver a Deuda" : "Saldar Deuda",
                                            onPressed: () async {
                                              if (isPaid) {
                                                // Confirmación para volver a deuda
                                                final conf = await showArticDialog<bool>(
                                                  context: context,
                                                  builder: (c) => ArticDialogCard(
                                                    title: "Volver a Deuda",
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(c, false),
                                                        child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.orange,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        onPressed: () => Navigator.pop(c, true),
                                                        child: const Text("Sí, reactivar"),
                                                      ),
                                                    ],
                                                    child: Text(
                                                      "¿Seguro que desea reactivar esta deuda?",
                                                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                                    ),
                                                  ),
                                                );
                                                if (conf == true) {
                                                  await DBService().revertirDeudaAPendiente(idDeuda);
                                                  Navigator.pop(ctx);
                                                  _showClienteInfo(cliente);
                                                }
                                              } else {
                                                // Saldar deuda
                                                final conf = await showArticDialog<bool>(
                                                  context: context,
                                                  builder: (c) => ArticDialogCard(
                                                    title: "Saldar Deuda",
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(c, false),
                                                        child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        onPressed: () => Navigator.pop(c, true),
                                                        child: const Text("Sí, pagar"),
                                                      ),
                                                    ],
                                                    child: Text(
                                                      "¿Seguro que desea marcar esta deuda como Pagada?",
                                                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                                    ),
                                                  ),
                                                );
                                                if (conf == true) {
                                                  await DBService().markDeudaAsPagada(idDeuda, m);
                                                  Navigator.pop(ctx);
                                                  _showClienteInfo(cliente);
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final activeColor = enabled ? color : (isDark ? Colors.white24 : Colors.black12);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: activeColor, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
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
              "Clientes",
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
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Buscar cliente',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: clientes.isEmpty
                              ? ArticEmptyState(
                                  icon: Icons.people_outline,
                                  title: "Sin clientes",
                                  description: "Comienza registrando un cliente para gestionar sus cuentas y deudas.",
                                  buttonText: "Añadir primer cliente",
                                  onButtonPressed: () => _showClienteDialog(),
                                )
                              : filtrados.isEmpty
                                  ? Center(
                                      child: Text(
                                        "No se encontraron clientes",
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: filtrados.length,
                                      itemBuilder: (context, index) {
                                        final c = filtrados[index];
                                        return Card(
                                          elevation: 0,
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          color: isDark
                                              ? Colors.white.withOpacity(0.02)
                                              : Colors.white.withOpacity(0.45),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(
                                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                                              width: 1,
                                            ),
                                          ),
                                          child: ListTile(
                                            onTap: () => _showClienteInfo(c),
                                            title: Text(
                                              c.nombre,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            subtitle: Text(
                                              c.telefono ?? "",
                                              style: TextStyle(
                                                color: isDark ? Colors.white60 : Colors.black54,
                                                fontSize: 13,
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                                                  onPressed: () => _showClienteDialog(cliente: c),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                  onPressed: () => _deleteCliente(c.id!),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClienteDialog(),
        backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
