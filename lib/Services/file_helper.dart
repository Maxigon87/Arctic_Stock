import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelper {
  /// Obtiene (y crea si no existe) la carpeta donde se guardan las facturas de ventas
  static Future<Directory> getVentasDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final ventasDir = Directory('${dir.path}/JeremiasVentas');
    if (!await ventasDir.exists()) {
      await ventasDir.create(recursive: true);
    }
    return ventasDir;
  }

  /// Obtiene (y crea si no existe) la carpeta donde se guardan los reportes (PDF/Excel)
  static Future<Directory> getReportesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportesDir = Directory('${dir.path}/JeremiasReportes');
    if (!await reportesDir.exists()) {
      await reportesDir.create(recursive: true);
    }
    return reportesDir;
  }

  /// Obtiene (y crea si no existe) la carpeta donde se guardan los respaldos
  static Future<Directory> getBackupsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory('${dir.path}/JeremiasBackups');
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Devuelve todos los archivos de las carpetas de ventas y reportes
  static Future<List<FileSystemEntity>> getAllArchivos() async {
    final ventasDir = await getVentasDir();
    final reportesDir = await getReportesDir();

    final archivosVentas = ventasDir.existsSync() ? ventasDir.listSync() : [];
    final archivosReportes =
        reportesDir.existsSync() ? reportesDir.listSync() : [];

    return [...archivosVentas, ...archivosReportes];
  }
}
