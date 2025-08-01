import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_container.dart';

import '../services/file_helper.dart';
import '../utils/file_namer.dart';

class HistorialArchivosScreen extends StatefulWidget {
  const HistorialArchivosScreen({Key? key}) : super(key: key);

  @override
  _HistorialArchivosScreenState createState() =>
      _HistorialArchivosScreenState();
}

class _HistorialArchivosScreenState extends State<HistorialArchivosScreen> {
  List<FileSystemEntity> archivos = [];

  @override
  void initState() {
    super.initState();
    _cargarArchivos();
  }

  Future<void> _cargarArchivos() async {
    final ventasDir = await FileHelper.getVentasDir();
    final reportesDir = await FileHelper.getReportesDir();

    final archivosVentas = ventasDir.listSync();
    final archivosReportes = reportesDir.listSync();

    setState(() {
      archivos = [...archivosVentas, ...archivosReportes];
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
        title: const Text("Eliminar archivo"),
        content:
            const Text("¿Estás seguro de que deseas eliminar este archivo?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirm == true) {
      await file.delete();
      _cargarArchivos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial de Archivos")),
      body: ArticBackground(
        child: ArticContainer(
          child: archivos.isEmpty
              ? const Center(child: Text("No hay archivos guardados"))
              : ListView.builder(
                  shrinkWrap: true, // ✅ importante para que no rompa layout
                  physics: const BouncingScrollPhysics(),
                  itemCount: archivos.length,
                  itemBuilder: (_, i) {
                    final file = archivos[i] as File;
                    final name = file.path.split('/').last;

                    return Card(
                      // ✅ ahora con estilo de tarjeta
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
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(file.path,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12)),
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
                  },
                ),
        ),
      ),
    );
  }
}
