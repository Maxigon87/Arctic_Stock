import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/cliente.dart';
import 'dart:async';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();
  // 🔹 StreamController para notificar cambios
  final StreamController<void> _dbChangeController =
      StreamController.broadcast();

// 🔹 Getter para que otros escuchen
  Stream<void> get onDatabaseChanged => _dbChangeController.stream;

// 🔹 Método para emitir eventos
  void notifyDbChange() => _dbChangeController.add(null);

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
    CREATE TABLE categorias (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL UNIQUE
    )
  ''');

    await db.execute('''
    CREATE TABLE productos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      precio REAL NOT NULL,
      categoria_id INTEGER,
      FOREIGN KEY (categoria_id) REFERENCES categorias(id)
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
    return await db.insert('productos', {
      'nombre': data['nombre'],
      'precio': data['precio'],
      'categoria_id': data['categoria_id']
    });
  }

  Future<int> updateProducto(Map<String, dynamic> data, int id) async {
    final db = await database;
    final count = await db.update(
        'productos',
        {
          'nombre': data['nombre'],
          'precio': data['precio'],
          'categoria_id': data['categoria_id']
        },
        where: 'id = ?',
        whereArgs: [id]);
    notifyDbChange();
    return count;
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    final count =
        await db.delete('productos', where: 'id = ?', whereArgs: [id]);
    notifyDbChange(); // ✅ notifica
    return count;
  }

  Future<int> insertVenta(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('ventas', data);
    notifyDbChange(); // ✅ avisa al Dashboard
    return id;
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
    final id = await db.insert('deudas', data);
    notifyDbChange(); // ✅ avisa a los gráficos y listas
    return id;
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
    final id = await db.insert('ventas', {
      'clienteId': data['clienteId'],
      'fecha': data['fecha'],
      'metodoPago': data['metodoPago'],
      'total': data['total'],
    });
    notifyDbChange(); // ✅ agregado
    return id;
  }

  Future<int> insertItemVenta(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('items_venta', data);
    notifyDbChange(); // ✅ notifica al Dashboard y otras pantallas
    return id;
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
    notifyDbChange(); // ✅ afecta reportes, debe avisar
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
    final count = await db.update('clientes', cliente.toMap(),
        where: 'id = ?', whereArgs: [cliente.id]);
    notifyDbChange(); // ✅ avisa cambio
    return count;
  }

// Eliminar cliente
  Future<int> deleteCliente(int id) async {
    final db = await database;
    final count = await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
    notifyDbChange(); // ✅ avisa que cambió la lista de clientes
    return count;
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

  // 🔹 Total ventas de un día
  Future<double> getTotalVentasDia(DateTime fecha) async {
    final db = await database;
    final dateStr = fecha.toIso8601String().substring(0, 10);
    final res = await db.rawQuery(
      "SELECT SUM(total) as total FROM ventas WHERE fecha LIKE ?",
      ["$dateStr%"],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0;
  }

// 🔹 Total ventas del mes
  Future<double> getTotalVentasMes(DateTime fecha) async {
    final db = await database;
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final res = await db.rawQuery(
      "SELECT SUM(total) as total FROM ventas WHERE strftime('%m', fecha) = ? AND strftime('%Y', fecha) = ?",
      [mes, anio],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0;
  }

// 🔹 Total de deudas pendientes
  Future<double> getTotalDeudasPendientes() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT SUM(monto) as total FROM deudas WHERE estado = 'Pendiente'",
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0;
  }

// 🔹 Producto más vendido
  Future<String> getProductoMasVendido() async {
    final db = await database;
    final res = await db.rawQuery('''
    SELECT p.nombre, SUM(iv.cantidad) as totalVendida
    FROM items_venta iv
    INNER JOIN productos p ON iv.productoId = p.id
    GROUP BY p.nombre
    ORDER BY totalVendida DESC
    LIMIT 1
  ''');
    return res.isNotEmpty ? res.first['nombre'] as String : "Sin datos";
  }

  // 🔹 Ventas últimos 7 días
  Future<List<Map<String, dynamic>>> getVentasUltimos7Dias() async {
    final db = await database;
    final res = await db.rawQuery('''
    SELECT strftime('%d', fecha) AS dia, SUM(total) AS total
    FROM ventas
    WHERE fecha >= date('now','-7 day')
    GROUP BY dia
    ORDER BY dia ASC
  ''');

    return res
        .map((e) =>
            {'dia': e['dia'], 'total': (e['total'] as num?)?.toDouble() ?? 0})
        .toList();
  }

// 🔹 Distribución de métodos de pago (en %)
  Future<Map<String, double>> getDistribucionMetodosPago() async {
    final db = await database;
    final res = await db.rawQuery('''
    SELECT metodoPago, COUNT(*) as cantidad
    FROM ventas
    GROUP BY metodoPago
  ''');

    double total = res.fold(0, (sum, e) => sum + (e['cantidad'] as int));
    Map<String, double> distribucion = {};
    for (var e in res) {
      distribucion[e['metodoPago'] as String] =
          ((e['cantidad'] as int) / total) * 100;
    }
    return distribucion;
  }

  // Crear tabla categorias y agregar categoria_id a productos
  Future<void> createTables(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS categorias (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL UNIQUE
    )
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS productos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      precio REAL NOT NULL,
      stock INTEGER NOT NULL,
      categoria_id INTEGER,
      FOREIGN KEY (categoria_id) REFERENCES categorias(id)
    )
  ''');
  }

  // Obtener todas las categorías
  Future<List<Map<String, dynamic>>> getCategorias() async {
    final db = await database;
    return await db.query('categorias', orderBy: 'nombre ASC');
  }

// Insertar nueva categoría
  Future<int> insertCategoria(String nombre) async {
    final db = await database;
    return await db.insert('categorias', {'nombre': nombre});
  }

// Obtener productos con filtro por categoría y búsqueda
  Future<List<Map<String, dynamic>>> getProductos(
      {String? search, int? categoriaId}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    if (search != null && search.isNotEmpty) {
      where += " AND p.nombre LIKE ?";
      args.add('%$search%');
    }
    if (categoriaId != null) {
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    return await db.rawQuery('''
    SELECT p.id, p.nombre, p.precio, p.categoria_id, c.nombre AS categoria_nombre
    FROM productos p
    LEFT JOIN categorias c ON p.categoria_id = c.id
    WHERE $where
    ORDER BY p.nombre ASC
  ''', args);
  }

  Future<List<Map<String, dynamic>>> getAllCategorias() async {
    final db = await database;
    return await db.query('categorias', orderBy: 'nombre ASC');
  }

  Future<int> addCategoria(String nombre) async {
    final db = await database;
    return await db.insert('categorias', {'nombre': nombre});
  }

  Future<int> updateCategoria(int id, String nombre) async {
    final db = await database;
    return await db.update('categorias', {'nombre': nombre},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategoria(int id) async {
    final db = await database;
    return await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }
}
