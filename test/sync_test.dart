import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:artic_stock/services/db_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Test db connection', () async {
    final dbService = DBService();
    final db = await dbService.database;
    expect(db.isOpen, true);
  });
}
