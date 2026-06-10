import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../widgets/artic_empty_state.dart';
import '../services/file_helper.dart';
import '../widgets/artic_dialog.dart';

class HistorialArchivosScreen extends StatefulWidget {
  const HistorialArchivosScreen({super.key});

  @override
  _HistorialArchivosScreenState createState() =>
      _HistorialArchivosScreenState();
}

class _HistorialArchivosScreenState extends State<HistorialArchivosScreen> {
  List<FileSystemEntity> archivosVentas = [];
  List<FileSystemEntity> archivosReportes = [];
  List<FileSystemEntity> archivosCatalogo = [];
  List<FileSystemEntity> archivosProductos = [];

  @override
  void initState() {
    super.initState();
    _cargarArchivos();
  }

  Future<void> _cargarArchivos() async {
    final ventasDir = await FileHelper.getVentasDir();
    final reportesDir = await FileHelper.getReportesDir();
    final catalogoDir = await FileHelper.getCatalogoDir();

    if (!mounted) return;


    final List<FileSystemEntity> ventas =
        ventasDir.existsSync() ? ventasDir.listSync() : <FileSystemEntity>[];
    final List<FileSystemEntity> reportesAll =
        reportesDir.existsSync() ? reportesDir.listSync() : <FileSystemEntity>[];
    final List<FileSystemEntity> reportes = reportesAll
        .where((FileSystemEntity f) {

          final name = f.path.split('/').last;
          return name.startsWith('reporte_') &&
              !name.startsWith('reporte_productos_');
        })
        .toList();
    final List<FileSystemEntity> productos = reportesAll
        .where((FileSystemEntity f) =>
            f.path.split('/').last.startsWith('reporte_productos_'))
        .toList();
    final List<FileSystemEntity> catalogo =
        catalogoDir.existsSync() ? catalogoDir.listSync() : <FileSystemEntity>[];

    if (!mounted) return;

    if (!mounted) return;

    setState(() {
      archivosVentas = ventas;
      archivosReportes = reportes;
      archivosCatalogo = catalogo;
      archivosProductos = productos;
    });
  }

  void _abrirArchivo(File file) {
    OpenFilex.open(file.path);
  }

  void _compartirArchivo(File file) {
    Share.shareXFiles([XFile(file.path)]);
  }

  void _borrarArchivo(File file) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showArticDialog<bool>(
      context: context,
      builder: (_) => ArticDialogCard(
        title: 'Eliminar archivo',
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
        child: Text(
          '¿Estás seguro de que deseas eliminar este archivo?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );

    if (confirm == true) {
      await file.delete();
      _cargarArchivos();
    }
  }

  bool get _todoVacio =>
      archivosVentas.isEmpty &&
      archivosReportes.isEmpty &&
      archivosCatalogo.isEmpty &&
      archivosProductos.isEmpty;

  List<Widget> _buildSection(
      BuildContext context, String titulo, List<FileSystemEntity> archivos, bool isDark) {
    if (archivos.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
          ),
        ),
      ),
      ...archivos.map((f) => _buildArchivoCard(context, f as File, isDark)).toList(),
    ];
  }

  Widget _buildArchivoCard(BuildContext context, File file, bool isDark) {
    final name = file.path.split('/').last;
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
        leading: Icon(
          name.endsWith('.pdf')
              ? Icons.picture_as_pdf
              : Icons.insert_drive_file,
          color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          file.path,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _abrirArchivo(file),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.blueAccent),
              onPressed: () => _compartirArchivo(file),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _borrarArchivo(file),
            ),
          ],
        ),
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
              "Historial de Archivos",
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
                child: _todoVacio
                    ? ArticEmptyState(
                        icon: Icons.folder_open_outlined,
                        title: "Sin archivos",
                        description: "Aún no se han generado facturas, catálogos o reportes PDF en el sistema.",
                        buttonText: "Actualizar historial",
                        onButtonPressed: _cargarArchivos,
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          ..._buildSection(context, 'Reportes del mes', archivosReportes, isDark),
                          ..._buildSection(context, 'Catálogo', archivosCatalogo, isDark),
                          ..._buildSection(context, 'Ventas', archivosVentas, isDark),
                          ..._buildSection(context, 'Productos', archivosProductos, isDark),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

