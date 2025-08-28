import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../Services/db_service.dart';
import '../Services/backup_service.dart';
import '../Services/catalog_service.dart';
import '../utils/theme_controller.dart';

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo usuario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    final name = controller.text.trim();
    if (ok == true && name.isNotEmpty) {
      await DBService().insertUsuario(name);
      await _load();
      widget.onUsersChanged?.call();
    }
  }

  Future<void> _renameUser(Map u) async {
    final controller = TextEditingController(text: u['nombre'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar usuario'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    final name = controller.text.trim();
    if (ok == true && name.isNotEmpty) {
      await DBService().updateUsuario(u['id'] as int, name);
      await _load();
      widget.onUsersChanged?.call();
    }
  }

  Future<void> _deleteUser(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: const Text(
            'Las ventas de este usuario quedarán sin asignar. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Usuarios', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final u in _users)
              InputChip(
                label: Text(u['nombre'] as String),
                avatar: const Icon(Icons.person, size: 18),
                onPressed: () => _renameUser(u),
                onDeleted: () => _deleteUser(u['id'] as int),
                deleteIcon: const Icon(Icons.delete_outline),
              ),
            ActionChip(
              label: const Text('Agregar usuario'),
              avatar: const Icon(Icons.person_add_alt_1),
              onPressed: _addUser,
            ),
          ],
        ),
        const Divider(height: 32),
        Text('Tema', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
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
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Exportar respaldo'),
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
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: const Text('Exportar catálogo de productos'),
          onTap: () async {
            final file = await CatalogService.exportProductos();
            if (file != null) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ Catálogo guardado: ${file.path}')),
              );
              await Share.shareXFiles([XFile(file.path)],
                  text: '📦 Catálogo de productos');
            }
          },
        ),
        Tooltip(
          message:
              'El formato válido es el mismo generado por la exportación de catálogo.',
          child: ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Importar catálogo de productos'),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['xlsx', 'csv'],
              );
              if (result == null || result.files.isEmpty) return;
              final path = result.files.single.path;
              if (path == null) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Importar catálogo'),
                  content: const Text(
                      'Se cargarán los productos desde el archivo seleccionado. El formato válido es el mismo generado por la exportación de catálogo. ¿Deseas continuar?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Importar')),
                  ],
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
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Importar respaldo'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Importar respaldo'),
                content: const Text(
                    'Se reemplazará la base de datos y los assets actuales. ¿Continuar?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Importar')),
                ],
              ),
            );
            if (ok == true) {
              await BackupService.importBackup();
              await _load();
              widget.onUsersChanged?.call();
            }
          },
        ),
      ],
    );
  }
}
