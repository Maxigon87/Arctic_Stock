import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'db_service.dart';
import 'file_helper.dart';

class BackupService {
  /// Exporta un respaldo de la base de datos y la carpeta de assets a un ZIP.
  /// El archivo se guarda dentro de la carpeta de backups.
  static Future<File?> exportBackup() async {
    final dbPath = await DBService().getDbPath();
    final dbFile = File(dbPath);

    final backupsDir = await FileHelper.getBackupsDir();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipPath = p.join(backupsDir.path, 'backup_$timestamp.zip');

    final archive = Archive();

    if (await dbFile.exists()) {
      final bytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('jeremias.db', bytes.length, bytes));
    }

    final assetsDir = Directory('assets');
    if (await assetsDir.exists()) {
      for (final entity in assetsDir.listSync(recursive: true)) {
        if (entity is File) {
          final relPath = p.relative(entity.path, from: assetsDir.path);
          final data = await entity.readAsBytes();
          archive.addFile(
            ArchiveFile(p.join('assets', relPath), data.length, data),
          );
        }
      }
    }

    final zipData = ZipEncoder().encode(archive);
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData!);
    return zipFile;
  }
}
