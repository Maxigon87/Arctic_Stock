import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';
import '../services/file_helper.dart';

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content:
            const Text('¿Estás seguro de que deseas eliminar este archivo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
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
      String titulo, List<FileSystemEntity> archivos) {
    if (archivos.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      ...archivos.map((f) => _buildArchivoCard(f as File)).toList(),
    ];
  }

  Widget _buildArchivoCard(File file) {
    final name = file.path.split('/').last;
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          name.endsWith('.pdf')
              ? Icons.picture_as_pdf
              : Icons.insert_drive_file,
          color: Colors.cyanAccent,
        ),
        title:
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          file.path,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        onTap: () => _abrirArchivo(file),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.blue),
              onPressed: () => _compartirArchivo(file),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _borrarArchivo(file),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Archivos')),
      body: ArticBackground(
        child: ArticContainer(
          child: _todoVacio
              ? const Center(child: Text('No hay archivos guardados'))
              : ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ..._buildSection('Reportes del mes', archivosReportes),
                    ..._buildSection('Catálogo', archivosCatalogo),
                    ..._buildSection('Ventas', archivosVentas),
                    ..._buildSection('Productos', archivosProductos),
                  ],
                ),
        ),
      ),
    );
  }
}

