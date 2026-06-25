import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'dart:ui' as ui;



import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

import 'package:file_picker/file_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';

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

  String _tipoTicket = 'ticket_58mm';



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    _users = await DBService().getUsuarios();

    _mode = ThemeController.instance.mode.value;

    final prefs = await SharedPreferences.getInstance();

    _tipoTicket = prefs.getString('tipo_ticket') ?? 'ticket_58mm';

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

  Future<void> _selectAndUploadActiveAvatar() async {

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



      if (!mounted) return;

      final croppedBytes = await showDialog<Uint8List>(

        context: context,

        barrierDismissible: false,

        builder: (context) => ArticImageCropperDialog(imageBytes: bytes!),

      );

      if (croppedBytes == null) return;



      final base64String = base64Encode(croppedBytes);



      final activeId = DBService().activeUserId;

      if (activeId != null) {

        await DBService().updateUsuarioAvatar(activeId, base64String);

        await _load();

        widget.onUsersChanged?.call();

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('¡Foto de perfil actualizada con éxito!')),

          );

        }

      } else {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('No hay usuario activo seleccionado')),

          );

        }

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Error al subir la imagen: $e')),

        );

      }

    }

  }



  Future<void> _deleteActiveAvatar() async {

    final activeId = DBService().activeUserId;

    if (activeId != null) {

      await DBService().updateUsuarioAvatar(activeId, null);

      await _load();

      widget.onUsersChanged?.call();

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Foto de perfil eliminada')),

        );

      }

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

    // Resumen Superior values
    final String activeUserText = DBService().activeUserName ?? "Ninguno";
    
    String ticketText = "Desconocido";
    if (_tipoTicket == 'pdf_normal') {
      ticketText = "A4 PDF";
    } else if (_tipoTicket == 'ticket_58mm') {
      ticketText = "58 mm";
    } else if (_tipoTicket == 'ticket_80mm') {
      ticketText = "80 mm";
    }

    String temaText = "Sistema";
    if (_mode == ThemeMode.light) {
      temaText = "Claro";
    } else if (_mode == ThemeMode.dark) {
      temaText = "Oscuro";
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Text(
              "Configuración",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Personaliza el funcionamiento, impresión y administración de Arctic Stock.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // --- RESUMEN SUPERIOR ---
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildResumenCard("👤 Usuario", activeUserText, Icons.person, isDark),
                _buildResumenCard("🖨 Ticket", ticketText, Icons.receipt_long, isDark),
                _buildResumenCard("🎨 Tema", temaText, Icons.palette, isDark),
              ],
            ),
            const SizedBox(height: 24),

            // --- SECCIONES DE CONFIGURACIÓN ---
            Expanded(
              child: ArticContainer(
                maxWidth: 800,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // 1. CUENTA Y USUARIOS
                    _buildSectionCard(
                      title: "Cuenta y Usuarios",
                      subtitle: "Administra los usuarios autorizados y la identidad visual.",
                      icon: Icons.person_outline,
                      isDark: isDark,
                      children: [
                        // Usuario Activo Sub-section
                        Row(
                          children: [
                            GestureDetector(
                              onTap: DBService().activeUserId != null ? _selectAndUploadActiveAvatar : null,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundColor: (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)).withOpacity(0.1),
                                      backgroundImage: DBService().activeUserAvatarBytes != null
                                          ? MemoryImage(DBService().activeUserAvatarBytes!)
                                          : null,
                                      child: DBService().activeUserAvatarBytes == null
                                          ? Icon(Icons.person, size: 36, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DBService().activeUserName ?? "Sin usuario activo",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: BorderSide(
                                            color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1),
                                          ),
                                        ),
                                        onPressed: DBService().activeUserId != null ? _selectAndUploadActiveAvatar : null,
                                        child: Text(
                                          "Cambiar foto",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (DBService().activeUserAvatarBytes != null) ...[
                                        const SizedBox(width: 10),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onPressed: _deleteActiveAvatar,
                                          child: const Text("Eliminar foto", style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white10 : Colors.black12),
                        const SizedBox(height: 20),
                        // Usuarios Autorizados Sub-section
                        Text(
                          "Usuarios autorizados:",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final u in _users)
                              InputChip(
                                label: Text(u['nombre'] as String),
                                labelStyle: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13,
                                ),
                                avatar: (() {
                                  final avatarBase64 = u['avatar'] as String?;
                                  if (avatarBase64 != null && avatarBase64.isNotEmpty) {
                                    return CircleAvatar(
                                      backgroundImage: MemoryImage(base64Decode(avatarBase64)),
                                    );
                                  }
                                  return Icon(Icons.person, size: 16, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7));
                                })(),
                                backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                side: BorderSide(
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                ),
                                onPressed: () => _renameUser(u),
                                onDeleted: () => _deleteUser(u['id'] as int),
                                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ActionChip(
                              label: const Text('Agregar'),
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              avatar: Icon(Icons.add, size: 14, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
                              backgroundColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.1) : const Color(0xFF0284C7).withOpacity(0.1),
                              side: BorderSide(color: isDark ? const Color(0xFF22D3EE).withOpacity(0.3) : const Color(0xFF0284C7).withOpacity(0.3)),
                              onPressed: _addUser,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 2. APARIENCIA
                    _buildSectionCard(
                      title: "Apariencia",
                      subtitle: "Personaliza la apariencia de Arctic Stock.",
                      icon: Icons.palette_outlined,
                      isDark: isDark,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.15) : const Color(0xFF0284C7).withOpacity(0.08),
                              selectedForegroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                              backgroundColor: Colors.transparent,
                              foregroundColor: isDark ? Colors.white60 : Colors.black54,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Sistema'),
                                icon: Icon(Icons.auto_mode, size: 16),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Claro'),
                                icon: Icon(Icons.light_mode, size: 16),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Oscuro'),
                                icon: Icon(Icons.dark_mode, size: 16),
                              ),
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

                    // 3. IMPRESIÓN
                    _buildSectionCard(
                      title: "Impresión",
                      subtitle: "Selecciona el formato predeterminado para imprimir y compartir comprobantes de venta.",
                      icon: Icons.print_outlined,
                      isDark: isDark,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useVertical = constraints.maxWidth < 600;
                            final cards = [
                              _buildPrintOptionCard(
                                value: 'pdf_normal',
                                title: 'PDF A4',
                                subtitle: 'Optimizado para PDF standard o impresoras de oficina.',
                                icon: Icons.picture_as_pdf_outlined,
                                isDark: isDark,
                                onTap: () async {
                                  setState(() => _tipoTicket = 'pdf_normal');
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('tipo_ticket', 'pdf_normal');
                                },
                              ),
                              _buildPrintOptionCard(
                                value: 'ticket_58mm',
                                title: 'Ticket 58 mm',
                                subtitle: 'Diseño compacto para impresoras térmicas de 58 mm.',
                                icon: Icons.receipt_long_outlined,
                                isDark: isDark,
                                onTap: () async {
                                  setState(() => _tipoTicket = 'ticket_58mm');
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('tipo_ticket', 'ticket_58mm');
                                },
                              ),
                              _buildPrintOptionCard(
                                value: 'ticket_80mm',
                                title: 'Ticket 80 mm',
                                subtitle: 'Diseño vertical para impresoras térmicas de 80 mm.',
                                icon: Icons.print_outlined,
                                isDark: isDark,
                                onTap: () async {
                                  setState(() => _tipoTicket = 'ticket_80mm');
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('tipo_ticket', 'ticket_80mm');
                                },
                              ),
                            ];

                            if (useVertical) {
                              return Column(
                                children: [
                                  cards[0],
                                  const SizedBox(height: 12),
                                  cards[1],
                                  const SizedBox(height: 12),
                                  cards[2],
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 16),
                                Expanded(child: cards[1]),
                                const SizedBox(width: 16),
                                Expanded(child: cards[2]),
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    // 4. DATOS Y RESPALDOS
                    _buildSectionCard(
                      title: "Datos y Respaldos",
                      subtitle: "Gestiona copias de seguridad e importación de catálogos.",
                      icon: Icons.storage_outlined,
                      isDark: isDark,
                      children: [
                        _buildDataActionTile(
                          icon: Icons.cloud_upload_outlined,
                          title: "Exportar Respaldo",
                          subtitle: "Crea una copia completa del sistema.",
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
                        _buildDataActionTile(
                          icon: Icons.cloud_download_outlined,
                          title: "Importar Respaldo",
                          subtitle: "Restaura la base de datos y archivos guardados anteriormente.",
                          isDark: isDark,
                          onTap: () async {
                            final ok = await showArticDialog<bool>(
                              context: context,
                              builder: (ctx) => ArticDialogCard(
                                title: 'Importar respaldo',
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Importar'),
                                  ),
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
                        _buildDataActionTile(
                          icon: Icons.inventory_2_outlined,
                          title: "Exportar Catálogo",
                          subtitle: "Exporta la lista de productos a un archivo Excel/CSV.",
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
                        _buildDataActionTile(
                          icon: Icons.download_outlined,
                          title: "Importar Catálogo",
                          subtitle: "Carga la lista de productos desde un archivo externo Excel/CSV.",
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sub-widgets de soporte para el rediseño ---

  Widget _buildResumenCard(String label, String value, IconData icon, bool isDark) {
    final cardBg = isDark ? Colors.white.withOpacity(0.03) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
    final accentColor = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    final cardBg = isDark ? Colors.white.withOpacity(0.02) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final accentColor = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPrintOptionCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSelected = _tipoTicket == value;
    final accentColor = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
    final borderColor = isSelected
        ? accentColor
        : (isDark ? Colors.white.withOpacity(0.1) : Colors.black12);
    final bg = isSelected
        ? (isDark ? const Color(0xFF22D3EE).withOpacity(0.08) : const Color(0xFF0284C7).withOpacity(0.05))
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? accentColor : (isDark ? Colors.white60 : Colors.black45),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final accentColor = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
    final hoverBg = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.01) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: hoverBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white30 : Colors.black26,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
