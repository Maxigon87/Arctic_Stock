import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/db_service.dart';
import '../services/backup_service.dart';
import '../services/catalog_service.dart';
import '../utils/theme_controller.dart';
import '../widgets/artic_container.dart';
import '../widgets/artic_dialog.dart';
import '../widgets/artic_image_cropper.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onUsersChanged;
  const SettingsScreen({super.key, this.onUsersChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _users = [];
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _users = await DBService().getUsuarios();
    _mode = ThemeController.instance.mode.value;
    if (mounted) setState(() {});
  }

  Future<void> _addUser() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? avatarBase64;

    final ok = await showArticDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => ArticDialogCard(
          title: 'Nuevo usuario',
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (result == null) return;
                    final file = result.files.first;
                    Uint8List? bytes = file.bytes;
                    if (bytes == null && file.path != null) {
                      bytes = await File(file.path!).readAsBytes();
                    }
                    if (bytes == null) return;

                    final croppedBytes = await showDialog<Uint8List>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => ArticImageCropperDialog(imageBytes: bytes!),
                    );
                    if (croppedBytes != null) {
                      setDialogState(() {
                        avatarBase64 = base64Encode(croppedBytes);
                      });
                    }
                  } catch (_) {}
                },
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)).withOpacity(0.1),
                  backgroundImage: (avatarBase64 != null && avatarBase64!.isNotEmpty)
                      ? MemoryImage(base64Decode(avatarBase64!))
                      : null,
                  child: (avatarBase64 == null || avatarBase64!.isEmpty)
                      ? Icon(Icons.camera_alt, size: 28, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
            ],
          ),
        ),
      ),
    );

    final name = controller.text.trim();
    if (ok == true && name.isNotEmpty) {
      await DBService().insertUsuario(name, avatar: avatarBase64);
      await _load();
      widget.onUsersChanged?.call();
    }
  }

  Future<void> _renameUser(Map u) async {
    final controller = TextEditingController(text: u['nombre'] as String);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? avatarBase64 = u['avatar'] as String?;

    final ok = await showArticDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => ArticDialogCard(
          title: 'Editar usuario',
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (result == null) return;
                    final file = result.files.first;
                    Uint8List? bytes = file.bytes;
                    if (bytes == null && file.path != null) {
                      bytes = await File(file.path!).readAsBytes();
                    }
                    if (bytes == null) return;

                    final croppedBytes = await showDialog<Uint8List>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => ArticImageCropperDialog(imageBytes: bytes!),
                    );
                    if (croppedBytes != null) {
                      setDialogState(() {
                        avatarBase64 = base64Encode(croppedBytes);
                      });
                    }
                  } catch (_) {}
                },
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)).withOpacity(0.1),
                  backgroundImage: (avatarBase64 != null && avatarBase64!.isNotEmpty)
                      ? MemoryImage(base64Decode(avatarBase64!))
                      : null,
                  child: (avatarBase64 == null || avatarBase64!.isEmpty)
                      ? Icon(Icons.camera_alt, size: 28, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
            ],
          ),
        ),
      ),
    );

    final name = controller.text.trim();
    if (ok == true && name.isNotEmpty) {
      await DBService().updateUsuario(u['id'] as int, name, avatar: avatarBase64);
      await _load();
      widget.onUsersChanged?.call();
    }
  }

  Future<void> _deleteUser(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showArticDialog<bool>(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: 'Eliminar usuario',
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
        child: Text(
          'Las ventas de este usuario quedarán sin asignar. ¿Continuar?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
    if (ok == true) {
      await DBService().deleteUsuario(id);
      await _load();
      widget.onUsersChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Configuración",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ArticContainer(
                maxWidth: 800,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionHeader("Gestión de Usuarios", Icons.people, isDark),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Administra los usuarios autorizados para registrar ventas en esta terminal.",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final u in _users)
                                InputChip(
                                  label: Text(u['nombre'] as String),
                                  labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  avatar: (() {
                                    final avatarBase64 = u['avatar'] as String?;
                                    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
                                      return CircleAvatar(
                                        backgroundImage: MemoryImage(base64Decode(avatarBase64)),
                                      );
                                    }
                                    return Icon(Icons.person, size: 16, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7));
                                  })(),
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                                  onPressed: () => _renameUser(u),
                                  onDeleted: () => _deleteUser(u['id'] as int),
                                  deleteIcon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                ),
                              ActionChip(
                                label: const Text('Agregar usuario'),
                                labelStyle: TextStyle(color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                avatar: Icon(Icons.person_add_alt_1, size: 16, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                                backgroundColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.1) : const Color(0xFF0284C7).withOpacity(0.1),
                                side: BorderSide(color: isDark ? const Color(0xFF22D3EE).withOpacity(0.3) : const Color(0xFF0284C7).withOpacity(0.3)),
                                onPressed: _addUser,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionHeader("Personalización", Icons.palette, isDark),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selecciona el tema visual de la aplicación.",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: SegmentedButton<ThemeMode>(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return isDark ? const Color(0xFF22D3EE).withOpacity(0.2) : const Color(0xFF0284C7).withOpacity(0.1);
                                  }
                                  return Colors.transparent;
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
                                  }
                                  return isDark ? Colors.white70 : Colors.black87;
                                }),
                              ),
                              segments: const [
                                ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text('Sistema'),
                                    icon: Icon(Icons.auto_mode)),
                                ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text('Claro'),
                                    icon: Icon(Icons.light_mode)),
                                ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text('Oscuro'),
                                    icon: Icon(Icons.dark_mode)),
                              ],
                              selected: <ThemeMode>{_mode},
                              onSelectionChanged: (s) async {
                                final m = s.first;
                                setState(() => _mode = m);
                                await ThemeController.instance.setMode(m);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionHeader("Copia de Seguridad y Datos", Icons.storage, isDark),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSettingTile(
                            icon: Icons.backup_outlined,
                            title: "Exportar Respaldo",
                            subtitle: "Crea una copia de seguridad completa del sistema",
                            isDark: isDark,
                            onTap: () async {
                              final file = await BackupService.exportBackup();
                              if (file != null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Respaldo guardado: ${file.path}')),
                                );
                                await Share.shareXFiles([XFile(file.path)]);
                              }
                            },
                          ),
                          _buildDivider(isDark),
                          _buildSettingTile(
                            icon: Icons.restore,
                            title: "Importar Respaldo",
                            subtitle: "Restaura la base de datos y archivos guardados anteriormente",
                            isDark: isDark,
                            onTap: () async {
                              final ok = await showArticDialog<bool>(
                                context: context,
                                builder: (ctx) => ArticDialogCard(
                                  title: 'Importar respaldo',
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Importar')),
                                  ],
                                  child: Text(
                                    'Se reemplazará la base de datos y los assets actuales. ¿Continuar?',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              );
                              if (ok == true) {
                                await BackupService.importBackup();
                                await _load();
                                widget.onUsersChanged?.call();
                              }
                            },
                          ),
                          _buildDivider(isDark),
                          _buildSettingTile(
                            icon: Icons.inventory_2_outlined,
                            title: "Exportar Catálogo",
                            subtitle: "Exporta la lista de productos a un archivo Excel/CSV",
                            isDark: isDark,
                            onTap: () async {
                              final file = await CatalogService.exportProductos();
                              if (file != null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Catálogo guardado: ${file.path}')),
                                );
                                await Share.shareXFiles([XFile(file.path)], text: '📦 Catálogo de productos');
                              }
                            },
                          ),
                          _buildDivider(isDark),
                          _buildSettingTile(
                            icon: Icons.download_outlined,
                            title: "Importar Catálogo",
                            subtitle: "Carga la lista de productos desde un archivo externo Excel/CSV",
                            isDark: isDark,
                            onTap: () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['xlsx', 'csv'],
                              );
                              if (result == null || result.files.isEmpty) return;
                              final path = result.files.single.path;
                              if (path == null) return;
                              final ok = await showArticDialog<bool>(
                                context: context,
                                builder: (ctx) => ArticDialogCard(
                                  title: 'Importar catálogo',
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Importar')),
                                  ],
                                  child: Text(
                                    'Se cargarán los productos desde el archivo seleccionado. ¿Deseas continuar?',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              );
                              if (ok == true) {
                                await CatalogService.importProductos(File(path));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Catálogo importado')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.black54,
          fontSize: 12,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white30 : Colors.black26),
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
      indent: 16,
      endIndent: 16,
    );
  }
}
