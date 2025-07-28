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
        productoId INTEGER,
        cantidad INTEGER,
        total REAL,
        fecha TEXT,
        FOREIGN KEY (productoId) REFERENCES productos (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE deudas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT
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
    return await db.query('ventas');
  }

  Future<int> insertDeuda(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('deudas', data);
  }

  Future<List<Map<String, dynamic>>> getDeudas() async {
    final db = await database;
    return await db.query('deudas');
  }
}
