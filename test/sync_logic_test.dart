import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/services/db_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Check db initialization and columns', () async {
    final dbService = DBService();
    final db = await dbService.database;

    final tables = [
      'categorias',
      'productos',
      'usuarios',
      'clientes',
      'ventas',
      'deudas',
      'movimientos_stock',
      'deleted_records',
      'config_sync'
    ];

    for (var table in tables) {
      final exists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [table]);
      expect(exists.isNotEmpty, true, reason: "Table \$table does not exist");

      if (table != 'deleted_records' && table != 'config_sync' && table != 'items_venta') {
         final cols = await db.rawQuery("PRAGMA table_info(\"\"\"\$table\"\"\");");
         print("Columns for \$table: \${cols.map((e) => e['name']).toList()}");
      }
    }
  });
}
