import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';
import '../../../services/sync_service.dart';
import '../../../utils/theme_controller.dart';
import '../debts/mobile_debts_screen.dart';
import '../../screens/quick_inquiry_screen.dart';
import '../../widgets/artic_image_cropper.dart';

class MobileMoreScreen extends StatefulWidget {
  const MobileMoreScreen({super.key});

  @override
  State<MobileMoreScreen> createState() => _MobileMoreScreenState();
}

class _MobileMoreScreenState extends State<MobileMoreScreen> {
  final DBService _dbService = DBService();
  final AuthService _authService = AuthService();

  void _cerrarSesion(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cerrar Sesión', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro que deseas cerrar sesión en el dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar', style: GoogleFonts.manrope(color: const Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(c, true),
            child: Text('Cerrar Sesión', style: GoogleFonts.manrope()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SyncService().stopPeriodicSync();
      await _authService.logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/mobile_login');
      }
    }
  }

  void _mostrarPerfil(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mi Perfil', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuario Activo:', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF64748B))),
            Text(_dbService.activeUserName ?? 'No especificado', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Text('Email del Negocio:', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF64748B))),
            Text(_authService.currentUser?.email ?? 'No especificado', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Text('ID del Negocio:', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF64748B))),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_authService.negocioId ?? 'No especificado', style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF64748B))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

  void _mostrarSeleccionTema(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tema Visual',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFF59E0B)),
              title: Text('Modo Claro', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () {
                ThemeController.instance.setMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_round_outlined, color: Color(0xFF0EA5E9)),
              title: Text('Modo Oscuro', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () {
                ThemeController.instance.setMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_brightness_outlined, color: Color(0xFF64748B)),
              title: Text('Tema del Sistema', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () {
                ThemeController.instance.setMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAndUploadAvatar() async {
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

      // Save to active user
      final activeId = _dbService.activeUserId;
      if (activeId != null) {
        await _dbService.updateUsuarioAvatar(activeId, base64String);
        setState(() {}); // reload UI
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Foto de perfil actualizada con éxito!')),
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

  @override
  Widget build(BuildContext context) {
    final employeeName = _dbService.activeUserName ?? 'Usuario';
    final businessEmail = _authService.currentUser?.email ?? 'Negocio';
    final avatarBase64 = _dbService.activeUserAvatar;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Más Opciones',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 20, color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _selectAndUploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                            ? MemoryImage(base64Decode(avatarBase64))
                            : null,
                        child: (avatarBase64 == null || avatarBase64.isEmpty)
                            ? Text(
                                employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'U',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0EA5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        businessEmail,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Menu Option List
          _buildMenuCard(
            context,
            icon: Icons.money_off,
            color: const Color(0xFFEF4444),
            title: 'Deudas Pendientes',
            subtitle: 'Administrar e ingresar cobros de deudas',
            textColor: textColor,
            subtitleColor: subtitleColor,
            cardColor: cardColor,
            borderColor: borderColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MobileDebtsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.palette_outlined,
            color: const Color(0xFFF59E0B),
            title: 'Tema Visual',
            subtitle: 'Alternar entre tema Claro, Oscuro o Sistema',
            textColor: textColor,
            subtitleColor: subtitleColor,
            cardColor: cardColor,
            borderColor: borderColor,
            onTap: () => _mostrarSeleccionTema(context),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.person_outline,
            color: const Color(0xFF0EA5E9),
            title: 'Mi Perfil',
            subtitle: 'Información del usuario y negocio activo',
            textColor: textColor,
            subtitleColor: subtitleColor,
            cardColor: cardColor,
            borderColor: borderColor,
            onTap: () => _mostrarPerfil(context),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.logout_outlined,
            color: const Color(0xFF64748B),
            title: 'Cerrar Sesión',
            subtitle: 'Cerrar sesión actual en el dispositivo',
            textColor: textColor,
            subtitleColor: subtitleColor,
            cardColor: cardColor,
            borderColor: borderColor,
            onTap: () => _cerrarSesion(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: subtitleColor,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}
