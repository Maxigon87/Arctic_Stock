import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/cliente.dart';

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
  CREATE TABLE clientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    telefono TEXT,
    email TEXT,
    direccion TEXT
  )
''');

    await db.execute('''
  CREATE TABLE ventas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    clienteId INTEGER,
    fecha TEXT NOT NULL,
    metodoPago TEXT NOT NULL,
    total REAL NOT NULL,
    FOREIGN KEY (clienteId) REFERENCES clientes(id)
  )
''');

    await db.execute('''
  CREATE TABLE deudas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    clienteId INTEGER,
    monto REAL NOT NULL,
    fecha TEXT NOT NULL,
    estado TEXT NOT NULL,
    descripcion TEXT,
    FOREIGN KEY (clienteId) REFERENCES clientes(id)
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
    return await db.rawQuery('''
    SELECT v.id, v.fecha, v.metodoPago, v.total,
           c.nombre AS cliente
    FROM ventas v
    LEFT JOIN clientes c ON v.clienteId = c.id
    ORDER BY v.fecha DESC
  ''');
  }

  Future<int> insertDeuda(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('deudas', {
      'clienteId': data['clienteId'],
      'monto': data['monto'],
      'fecha': data['fecha'],
      'estado': data['estado'],
      'descripcion': data['descripcion'],
    });
  }

  Future<List<Map<String, dynamic>>> getDeudas() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT d.id, d.monto, d.fecha, d.estado, d.descripcion,
           c.nombre AS cliente
    FROM deudas d
    LEFT JOIN clientes c ON d.clienteId = c.id
    ORDER BY d.fecha DESC
  ''');
  }

  Future<int> insertVentaBase(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('ventas', {
      'clienteId': data['clienteId'],
      'fecha': data['fecha'],
      'metodoPago': data['metodoPago'],
      'total': data['total'],
    });
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

  // Insertar cliente
  Future<int> insertCliente(Cliente cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente.toMap());
  }

// Obtener todos los clientes
  Future<List<Cliente>> getClientes() async {
    final db = await database;
    final res = await db.query('clientes');
    return res.map((e) => Cliente.fromMap(e)).toList();
  }

// Actualizar cliente
  Future<int> updateCliente(Cliente cliente) async {
    final db = await database;
    return await db.update('clientes', cliente.toMap(),
        where: 'id = ?', whereArgs: [cliente.id]);
  }

// Eliminar cliente
  Future<int> deleteCliente(int id) async {
    final db = await database;
    return await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getVentaById(int ventaId) async {
    final db = await database;
    final res = await db.rawQuery('''
    SELECT v.id, v.fecha, v.metodoPago, v.total,
           c.nombre AS cliente
    FROM ventas v
    LEFT JOIN clientes c ON v.clienteId = c.id
    WHERE v.id = ?
    LIMIT 1
  ''', [ventaId]);

    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> buscarVentas({
    String? cliente,
    String? metodoPago,
    String? fecha,
  }) async {
    final db = await database;

    String where = "1=1";
    List<dynamic> args = [];

    if (cliente != null && cliente.isNotEmpty) {
      where += " AND c.nombre LIKE ?";
      args.add('%$cliente%');
    }

    if (metodoPago != null && metodoPago.isNotEmpty) {
      where += " AND v.metodoPago = ?";
      args.add(metodoPago);
    }

    if (fecha != null && fecha.isNotEmpty) {
      where += " AND v.fecha LIKE ?";
      args.add('$fecha%');
    }

    return await db.rawQuery('''
    SELECT v.id, v.fecha, v.metodoPago, v.total,
           COALESCE(c.nombre, 'Sin asignar') AS cliente
    FROM ventas v
    LEFT JOIN clientes c ON v.clienteId = c.id
    WHERE $where
    ORDER BY v.fecha DESC
  ''', args);
  }

  Future<List<Map<String, dynamic>>> buscarDeudas({
    String? cliente,
    String? estado,
    String? fecha,
  }) async {
    final db = await database;

    // 🔹 Construcción dinámica del WHERE
    String where = "1=1";
    List<dynamic> args = [];

    if (cliente != null && cliente.isNotEmpty) {
      where += " AND c.nombre LIKE ?";
      args.add('%$cliente%');
    }

    if (estado != null && estado.isNotEmpty) {
      where += " AND d.estado = ?";
      args.add(estado);
    }

    if (fecha != null && fecha.isNotEmpty) {
      where += " AND d.fecha LIKE ?";
      args.add('$fecha%');
    }

    // 🔹 Consulta con JOIN a clientes
    return await db.rawQuery('''
    SELECT d.id, d.monto, d.fecha, d.estado, d.descripcion,
           COALESCE(c.nombre, 'Sin asignar') AS cliente
    FROM deudas d
    LEFT JOIN clientes c ON d.clienteId = c.id
    WHERE $where
    ORDER BY d.fecha DESC
  ''', args);
  }
}
