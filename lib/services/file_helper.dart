import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelper {
  static const _rootFolder = 'Arctic stock';

  /// Obtiene (y crea si no existe) la carpeta raíz "Arctic stock" dentro de Documentos
  static Future<Directory> _getRootDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/$_rootFolder');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Obtiene (y crea si no existe) la carpeta donde se guardan las facturas de ventas
  static Future<Directory> getVentasDir() async {
    final root = await _getRootDir();
    final ventasDir = Directory('${root.path}/Arctic stock Ventas');
    if (!await ventasDir.exists()) {
      await ventasDir.create(recursive: true);
    }
    return ventasDir;
  }

  /// Obtiene (y crea si no existe) la carpeta donde se guardan los reportes (PDF/Excel)
  static Future<Directory> getReportesDir() async {
    final root = await _getRootDir();
    final reportesDir = Directory('${root.path}/Arctic stock Reportes');
    if (!await reportesDir.exists()) {
      await reportesDir.create(recursive: true);
    }
    return reportesDir;
  }

  /// Obtiene (y crea si no existe) la carpeta donde se guardan las exportaciones de catálogo
  static Future<Directory> getCatalogoDir() async {
    final root = await _getRootDir();
    final catalogoDir = Directory('${root.path}/Arctic stock Catalogo');
    if (!await catalogoDir.exists()) {
      await catalogoDir.create(recursive: true);
    }
    return catalogoDir;
  }

  /// Obtiene (y crea si no existe) la carpeta donde se guardan los respaldos
  static Future<Directory> getBackupsDir() async {
    final root = await _getRootDir();
    final backupsDir = Directory('${root.path}/Arctic Stock Respaldo');
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Devuelve todos los archivos de las carpetas de ventas y reportes
  static Future<List<FileSystemEntity>> getAllArchivos() async {
    final ventasDir = await getVentasDir();
    final reportesDir = await getReportesDir();
    final catalogoDir = await getCatalogoDir();

    final archivosVentas = ventasDir.existsSync() ? ventasDir.listSync() : [];
    final archivosReportes =
        reportesDir.existsSync() ? reportesDir.listSync() : [];
    final archivosCatalogo =
        catalogoDir.existsSync() ? catalogoDir.listSync() : [];

    return [...archivosVentas, ...archivosReportes, ...archivosCatalogo];
  }
}
