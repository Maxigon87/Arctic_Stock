import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
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

  /// Importa un respaldo desde un archivo ZIP seleccionado por el usuario.
  static Future<void> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final zipPath = result.files.single.path;
    if (zipPath == null) return;

    final zipFile = File(zipPath);
    final dbService = DBService();
    final dbPath = await dbService.getDbPath();
    final dbFile = File(dbPath);

    final backupsDir = await FileHelper.getBackupsDir();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final preZipPath =
        p.join(backupsDir.path, 'backup_${timestamp}_preRestore.zip');

    final preArchive = Archive();
    if (await dbFile.exists()) {
      final bytes = await dbFile.readAsBytes();
      preArchive.addFile(ArchiveFile('jeremias.db', bytes.length, bytes));
      final preData = ZipEncoder().encode(preArchive);
      if (preData != null) {
        await File(preZipPath).writeAsBytes(preData);
      }
    }

    await dbService.close();

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final assetsDir = Directory('assets');
    if (await assetsDir.exists()) {
      await assetsDir.delete(recursive: true);
    }

    for (final entry in archive) {
      final outPath = entry.name;
      if (entry.isFile) {
        final data = entry.content as List<int>;
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    await dbService.reopen();
  }
}
