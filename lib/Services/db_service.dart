import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    // ✅ Inicializa soporte FFI en Windows/Linux
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'jeremias.db');

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _createTables),
    );
  }

  Future _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ventas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente TEXT,
        fecha TEXT,
        metodoPago TEXT,
        total REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE deudas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT,
        metodoPago TEXT,
        descripcion TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE items_venta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ventaId INTEGER,
        productoId INTEGER,
        cantidad INTEGER,
        subtotal REAL,
        FOREIGN KEY (ventaId) REFERENCES ventas (id),
        FOREIGN KEY (productoId) REFERENCES productos (id)
  )
''');
  }

  // ✅ CRUD (igual que antes, no cambia nada)
  Future<int> insertProducto(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('productos', data);
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final db = await database;
    return await db.query('productos');
  }

  Future<int> updateProducto(Map<String, dynamic> data, int id) async {
    final db = await database;
    return await db.update('productos', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertVenta(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('ventas', data);
  }

  Future<List<Map<String, dynamic>>> getVentas() async {
    final db = await database;
    final List<Map<String, dynamic>> ventas = await db.query('ventas');
    return ventas;
  }

  Future<int> insertDeuda(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('deudas', data);
  }

  Future<List<Map<String, dynamic>>> getDeudas() async {
    final db = await database;
    final List<Map<String, dynamic>> deudas = await db.query('deudas');
    return deudas;
  }

  Future<int> insertVentaBase(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('ventas', data);
  }

  Future<int> insertItemVenta(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('items_venta', data);
  }

  Future<List<Map<String, dynamic>>> getItemsByVenta(int ventaId) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT iv.cantidad, iv.subtotal, p.nombre AS producto, p.precio AS precioUnitario
    FROM items_venta iv
    INNER JOIN productos p ON iv.productoId = p.id
    WHERE iv.ventaId = ?
  ''',
      [ventaId],
    );
  }

  Future<void> updateVentaTotal(int ventaId, double total) async {
    final db = await database;
    await db.update(
      'ventas',
      {'total': total},
      where: 'id = ?',
      whereArgs: [ventaId],
    );
  }

  Future<List<Map<String, dynamic>>> getStockProductos() async {
    final db = await database;
    return await db.query('productos');
  }

  Future<List<Map<String, dynamic>>> getVentasDelMes(String mes) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT * FROM ventas
    WHERE strftime('%m', fecha) = ? 
  ''',
      [mes],
    );
  }

  Future<List<Map<String, dynamic>>> getDeudasDelMes(String mes) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT * FROM deudas
    WHERE strftime('%m', fecha) = ? 
  ''',
      [mes],
    );
  }
}
