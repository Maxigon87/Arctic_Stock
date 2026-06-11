import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/services/db_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Check that DB has necessary components for Firebase Sync and modifications trigger sync', () async {
    final dbService = DBService();
    final db = await dbService.database;

    // clean up any existing products
    await db.delete('productos');

    // Insert a product and ensure 'firebase_id', 'last_updated', and 'synced' are managed.
    final id = await dbService.insertProducto({
      'codigo': 'TEST01',
      'nombre': 'Test Prod',
      'precio_venta': 100.0,
      'costo_compra': 50.0,
      'stock': 10,
    });

    var prod = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    expect(prod.isNotEmpty, true);
    expect(prod.first['synced'], 0);
    expect(prod.first['last_updated'], isNotNull);

    // Simulate sync
    await db.update('productos', {'synced': 1, 'last_updated': '2023-01-01T00:00:00.000Z'}, where: 'id = ?', whereArgs: [id]);

    prod = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    expect(prod.first['synced'], 1);

    // Update product and ensure it marks as unsynced
    await dbService.updateProducto({
      'codigo': 'TEST01',
      'nombre': 'Test Prod Modified',
      'precio_venta': 120.0,
      'costo_compra': 60.0,
      'stock': 15,
      'categoria_id': null,
    }, id);

    prod = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    expect(prod.first['synced'], 0);
    final lastUpdated = DateTime.parse(prod.first['last_updated'] as String);
    expect(lastUpdated.isAfter(DateTime(2023)), true);
  });
}
