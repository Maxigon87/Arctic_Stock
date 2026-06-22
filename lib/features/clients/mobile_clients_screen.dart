import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/cliente.dart';
import '../../../services/db_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/artic_dialog.dart';

class MobileClientsScreen extends StatefulWidget {
  const MobileClientsScreen({super.key});

  @override
  State<MobileClientsScreen> createState() => _MobileClientsScreenState();
}

class _MobileClientsScreenState extends State<MobileClientsScreen> {
  final DBService _dbService = DBService();
  late StreamSubscription _dbSub;

  List<Map<String, dynamic>> _clientes = [];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClientes();
    _dbSub = _dbService.onDatabaseChanged.listen((_) => _loadClientes());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _loadClientes() async {
    try {
      final db = await _dbService.database;
      final res = await db.rawQuery('''
        SELECT c.id, c.nombre, c.dni, c.telefono, c.email, c.direccion,
               COALESCE(d.total_deuda, 0.0) AS totalDeuda,
               v.ultima_compra AS ultimaCompra
        FROM clientes c
        LEFT JOIN (
          SELECT clienteId, SUM(monto) AS total_deuda
          FROM deudas
          WHERE estado = 'Pendiente'
          GROUP BY clienteId
        ) d ON c.id = d.clienteId
        LEFT JOIN (
          SELECT clienteId, MAX(fecha) AS ultima_compra
          FROM ventas
          GROUP BY clienteId
        ) v ON c.id = v.clienteId
        ORDER BY c.nombre ASC
      ''');

      if (mounted) {
        setState(() {
          _clientes = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddClienteDialog() {
    final nombreCtrl = TextEditingController();
    final dniCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final dialogSubtitleColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final dialogFillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    showArticDialog(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: 'Nuevo Cliente',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.manrope(color: dialogSubtitleColor)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () async {
              final name = nombreCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio')),
                );
                return;
              }
              final c = Cliente(
                nombre: name,
                dni: dniCtrl.text.trim(),
                telefono: telefonoCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                direccion: direccionCtrl.text.trim(),
              );
              await _dbService.insertCliente(c);
              Navigator.pop(ctx);
              _loadClientes();
            },
            child: Text('Guardar', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              style: GoogleFonts.manrope(color: dialogTextColor),
              decoration: InputDecoration(
                labelText: 'Nombre *',
                labelStyle: GoogleFonts.manrope(color: dialogSubtitleColor),
                filled: true,
                fillColor: dialogFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dniCtrl,
              style: GoogleFonts.manrope(color: dialogTextColor),
              decoration: InputDecoration(
                labelText: 'DNI / CUIT',
                labelStyle: GoogleFonts.manrope(color: dialogSubtitleColor),
                filled: true,
                fillColor: dialogFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telefonoCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.manrope(color: dialogTextColor),
              decoration: InputDecoration(
                labelText: 'Teléfono',
                labelStyle: GoogleFonts.manrope(color: dialogSubtitleColor),
                filled: true,
                fillColor: dialogFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.manrope(color: dialogTextColor),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: GoogleFonts.manrope(color: dialogSubtitleColor),
                filled: true,
                fillColor: dialogFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: direccionCtrl,
              style: GoogleFonts.manrope(color: dialogTextColor),
              decoration: InputDecoration(
                labelText: 'Dirección',
                labelStyle: GoogleFonts.manrope(color: dialogSubtitleColor),
                filled: true,
                fillColor: dialogFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClienteDetails(Map<String, dynamic> c) {
    final id = c['id'] as int;
    final nombre = c['nombre'] as String? ?? 'Cliente';
    final dni = c['dni'] as String? ?? '';
    final telefono = c['telefono'] as String? ?? '';
    final email = c['email'] as String? ?? '';
    final direccion = c['direccion'] as String? ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
    final handleColor = isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => FutureBuilder<List<Map<String, dynamic>>>(
          future: _dbService.getDeudasByCliente(id),
          builder: (context, snapshot) {
            final deudas = snapshot.data ?? [];
            final deudasPendientes = deudas.where((d) => d['estado'] == 'Pendiente').toList();
            final totalDeuda = deudasPendientes.fold<double>(0.0, (sum, d) => sum + ((d['monto'] as num?)?.toDouble() ?? 0.0));

            return Container(
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Pull Handle
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Large Avatar & Name
                        Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                                child: Text(
                                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                                  style: GoogleFonts.manrope(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                nombre,
                                style: GoogleFonts.manrope(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (dni.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'DNI/CUIT: $dni',
                                  style: GoogleFonts.manrope(fontSize: 13, color: subtitleColor),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // KPI Cards
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
                                      'Deuda Total',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatCurrency(totalDeuda),
                                      style: GoogleFonts.manrope(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
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
                                      'Deudas Pendientes',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${deudasPendientes.length}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: deudasPendientes.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Contact Info Section (independent card)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.contact_mail_outlined, color: Color(0xFF0EA5E9), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Información de contacto',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(Icons.phone_outlined, 'Teléfono', telefono.isNotEmpty ? telefono : 'No registrado'),
                              Divider(height: 24, color: borderColor),
                              _buildInfoRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'No registrado'),
                              Divider(height: 24, color: borderColor),
                              _buildInfoRow(Icons.location_on_outlined, 'Dirección', direccion.isNotEmpty ? direccion : 'No registrada'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.email_outlined,
                                label: 'Enviar Email',
                                color: const Color(0xFF0EA5E9),
                                enabled: email.isNotEmpty,
                                onTap: () async {
                                  final uri = Uri(scheme: 'mailto', path: email);
                                  try {
                                    await launchUrl(uri);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No se pudo abrir el cliente de email')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.map_outlined,
                                label: 'Ver Mapa',
                                color: const Color(0xFFF59E0B),
                                enabled: direccion.isNotEmpty,
                                onTap: () async {
                                  final uri = Uri.parse(
                                    "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion)}"
                                  );
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No se pudo abrir Google Maps')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Debt / History
                        Text(
                          'Deudas Activas',
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        _buildClientDebtsWidget(id),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
    final activeColor = enabled ? color : (isDark ? Colors.white38 : const Color(0xFF94A3B8));

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          children: [
            Icon(icon, color: activeColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: activeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? Colors.white60 : const Color(0xFF94A3B8);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(fontSize: 11, color: labelColor),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientDebtsWidget(int clienteId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white70 : const Color(0xFF64748B);
    final dateTextCol = isDark ? Colors.white54 : const Color(0xFF94A3B8);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dbService.getDeudasByCliente(clienteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
          ));
        }

        final deudas = (snapshot.data ?? []).where((d) => d['estado'] == 'Pendiente').toList();

        if (deudas.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Center(
              child: Text(
                'Sin deudas pendientes',
                style: GoogleFonts.manrope(color: subTextCol, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deudas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final d = deudas[index];
            final id = d['id'] as int;
            final monto = (d['monto'] as num?)?.toDouble() ?? 0.0;
            final fechaStr = d['fecha'] as String? ?? '';
            final desc = d['descripcion'] as String? ?? '';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Deuda #$id',
                              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: textCol),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hourglass_empty, size: 10, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pendiente',
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            desc,
                            style: GoogleFonts.manrope(fontSize: 12, color: subTextCol),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          fechaStr.split('T').first,
                          style: GoogleFonts.manrope(fontSize: 11, color: dateTextCol),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(monto),
                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final confirm = await showArticDialog<bool>(
                            context: context,
                            builder: (c) => ArticDialogCard(
                              title: 'Saldar Deuda',
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: Text('Cancelar', style: GoogleFonts.manrope(color: subTextCol)),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: Text('Confirmar Pago', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                              child: Text(
                                '¿Confirmas que deseas registrar el pago de esta deuda por ${formatCurrency(monto)}?',
                                style: GoogleFonts.manrope(color: textCol),
                              ),
                            ),
                          );

                          if (confirm == true) {
                            await _dbService.markDeudaAsPagada(id, monto);
                            Navigator.pop(context); // Close details sheet
                            _loadClientes();
                          }
                        },
                        child: Text(
                          'Pagar',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _clientes.where((c) {
      final name = _dbService.normalizeString(c['nombre'] as String? ?? '');
      final dni = _dbService.normalizeString(c['dni'] as String? ?? '');
      final query = _dbService.normalizeString(_searchQuery.trim());
      return name.contains(query) || dni.contains(query);
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final searchBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fieldFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Clientes',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 20, color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF0EA5E9)),
            onPressed: _showAddClienteDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : Column(
              children: [
                // Search Bar
                Container(
                  color: searchBgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      hintStyle: GoogleFonts.manrope(color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: fieldFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    style: GoogleFonts.manrope(fontSize: 14, color: textColor),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadClientes,
                    color: const Color(0xFF0EA5E9),
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 600;
                              if (isWide) {
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 3.2,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) => _buildClientCard(filtered[idx]),
                                );
                              } else {
                                return ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildClientCard(filtered[idx]),
                                );
                              }
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 60, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              'No se encontraron clientes',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ? 'Intenta con otros términos.' : 'Comienza creando un cliente con el botón superior.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> c) {
    final nombre = c['nombre'] as String? ?? 'Cliente';
    final debt = (c['totalDeuda'] as num?)?.toDouble() ?? 0.0;
    final rawUltimaCompra = c['ultimaCompra'] as String?;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String lastPurchaseText = 'Sin compras';
    if (rawUltimaCompra != null) {
      try {
        final date = DateTime.parse(rawUltimaCompra);
        lastPurchaseText = DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {}
    }

    return InkWell(
      onTap: () => _showClienteDetails(c),
      borderRadius: BorderRadius.circular(16),
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.08),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nombre,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Última compra: $lastPurchaseText',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (debt > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatCurrency(debt),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Deuda',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Al día',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF22C55E),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
