import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart' show ConflictAlgorithm;

import 'db_service.dart';
import 'file_helper.dart';

class BackupService {
  /// Exporta un respaldo con ventas, ganancias, clientes, información del
  /// dashboard y deudas. No se incluyen los productos porque existe una
  /// opción dedicada para ello.
  /// El archivo se guarda dentro de la carpeta de backups.
  static Future<File?> exportBackup() async {
    final db = await DBService().database;

    final clientes = await db.query('clientes');
    final deudas = await db.query('deudas');

    final ventasRaw = await db.query('ventas');
    final ventas = <Map<String, dynamic>>[];
    for (final v in ventasRaw) {
      final items = await db
          .query('items_venta', where: 'ventaId = ?', whereArgs: [v['id']]);
      final itemsSinProductoId = items
          .map((e) => Map<String, dynamic>.from(e)..remove('productoId'))
          .toList();
      ventas.add({...v, 'items': itemsSinProductoId});
    }

    final dbService = DBService();
    final ahora = DateTime.now();
    DateTime _inicioDia(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _finDia(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59);
    DateTime _inicioMes(DateTime d) => DateTime(d.year, d.month, 1);
    DateTime _finMes(DateTime d) =>
        DateTime(d.year, d.month + 1, 0, 23, 59, 59);

    final ventasHoy = await dbService.getTotalVentasDia(ahora);
    final ventasMes = await dbService.getTotalVentasMes(ahora);
    final gananciaHoy = await dbService.getGananciaTotal(
      desde: _inicioDia(ahora),
      hasta: _finDia(ahora),
    );
    final gananciaMes = await dbService.getGananciaTotal(
      desde: _inicioMes(ahora),
      hasta: _finMes(ahora),
    );
    final gananciaTotal = await dbService.getGananciaTotal();
    final deudasPendientes = await dbService.getTotalDeudasPendientes();
    final productoTop = await dbService.getProductoMasVendido();
    final ventasDias = await dbService.getVentasUltimos7Dias();
    final metodosPago = await dbService.getDistribucionMetodosPago();
    final productosSinStock = await dbService.getProductosSinStockCount();

    final dashboard = {
      'ventasHoy': ventasHoy,
      'ventasMes': ventasMes,
      'gananciaHoy': gananciaHoy,
      'gananciaMes': gananciaMes,
      'deudasPendientes': deudasPendientes,
      'productoTop': productoTop,
      'ventasDias': ventasDias,
      'metodosPago': metodosPago,
      'productosSinStock': productosSinStock,
    };

    final ganancias = {
      'gananciaHoy': gananciaHoy,
      'gananciaMes': gananciaMes,
      'gananciaTotal': gananciaTotal,
    };

    final backupsDir = await FileHelper.getBackupsDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipPath = p.join(backupsDir.path, 'backup_$timestamp.zip');

    final archive = Archive()
      ..addFile(ArchiveFile(
          'clientes.json',
          utf8.encode(jsonEncode(clientes)).length,
          utf8.encode(jsonEncode(clientes))))
      ..addFile(ArchiveFile(
          'deudas.json',
          utf8.encode(jsonEncode(deudas)).length,
          utf8.encode(jsonEncode(deudas))))
      ..addFile(ArchiveFile(
          'ventas.json',
          utf8.encode(jsonEncode(ventas)).length,
          utf8.encode(jsonEncode(ventas))))
      ..addFile(ArchiveFile(
          'dashboard.json',
          utf8.encode(jsonEncode(dashboard)).length,
          utf8.encode(jsonEncode(dashboard))))
      ..addFile(ArchiveFile(
          'ganancias.json',
          utf8.encode(jsonEncode(ganancias)).length,
          utf8.encode(jsonEncode(ganancias))));

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
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    List<dynamic>? clientes;
    List<dynamic>? ventas;
    List<dynamic>? deudas;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final content = utf8.decode(entry.content as List<int>);
      switch (entry.name) {
        case 'clientes.json':
          clientes = jsonDecode(content);
          break;
        case 'ventas.json':
          ventas = jsonDecode(content);
          break;
        case 'deudas.json':
          deudas = jsonDecode(content);
          break;
      }
    }

    final dbService = DBService();
    final db = await dbService.database;

    await db.transaction((txn) async {
      await txn.delete('items_venta');
      await txn.delete('ventas');
      await txn.delete('clientes');
      await txn.delete('deudas');

      if (clientes != null) {
        for (final c in clientes.cast<Map<String, dynamic>>()) {
          await txn.insert('clientes', c,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (ventas != null) {
        for (final v in ventas.cast<Map<String, dynamic>>()) {
          final items =
              (v['items'] as List? ?? []).cast<Map<String, dynamic>>();
          final ventaMap = Map<String, dynamic>.from(v)..remove('items');
          await txn.insert('ventas', ventaMap,
              conflictAlgorithm: ConflictAlgorithm.replace);
          for (final item in items) {
            await txn.insert('items_venta', item,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (deudas != null) {
        for (final d in deudas.cast<Map<String, dynamic>>()) {
          await txn.insert('deudas', d,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    dbService.notifyDbChange();
  }
}
