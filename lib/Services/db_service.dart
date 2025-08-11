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
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _createTables,
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) await _migrateToV2(db);
        },
        // ✅ Asegura la columna 'stock' al abrir la base
        onOpen: (db) async {
          await db
              .execute("PRAGMA foreign_keys = ON;"); // ✅ Asegura las FK activas
          await _ensureStockColumn(db); // ✅ Aquí se asegura la columna 'stock'
        },
      ),
    );
  }

  Future _migrateToV2(Database db) async {
    // columnas nuevas si no existen
    final cols = await db.rawQuery("PRAGMA table_info(productos);");
    bool hasCodigo = cols.any((c) => c['name'] == 'codigo');
    bool hasDescripcion = cols.any((c) => c['name'] == 'descripcion');
    bool hasCostoCompra = cols.any((c) => c['name'] == 'costo_compra');
    bool hasPrecioVenta = cols.any((c) => c['name'] == 'precio_venta');

    if (!hasCodigo) {
      await db.execute("ALTER TABLE productos ADD COLUMN codigo TEXT;");
      // índice único (permite NULL repetidos; si querés que sea obligatorio, validalo en UI/CRUD)
      await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo);");
    }
    if (!hasDescripcion) {
      await db.execute("ALTER TABLE productos ADD COLUMN descripcion TEXT;");
    }
    if (!hasCostoCompra) {
      await db.execute(
          "ALTER TABLE productos ADD COLUMN costo_compra REAL DEFAULT 0;");
    }
    if (!hasPrecioVenta) {
      await db.execute("ALTER TABLE productos ADD COLUMN precio_venta REAL;");
      // backfill desde 'precio' si existe
      final hasPrecioLegacy = cols.any((c) => c['name'] == 'precio');
      if (hasPrecioLegacy) {
        await db.execute(
            "UPDATE productos SET precio_venta = precio WHERE precio_venta IS NULL;");
      }
      // por si quedó null en algún caso
      await db.execute(
          "UPDATE productos SET precio_venta = COALESCE(precio_venta, 0);");
    }
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
      codigo TEXT UNIQUE,
      nombre TEXT NOT NULL,
      descripcion TEXT,
      precio_venta REAL NOT NULL CHECK(precio_venta > 0),
      costo_compra REAL DEFAULT 0 CHECK(costo_compra >= 0),
      stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
      categoria_id INTEGER,
      FOREIGN KEY (categoria_id) REFERENCES categorias(id)
    )
  ''');
    await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo);");

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

  Future<void> _ensureStockColumn(Database db) async {
    final res = await db.rawQuery("PRAGMA table_info(productos);");
    final hasStock = res.any((col) => col['name'] == 'stock');
    if (!hasStock) {
      await db
          .execute("ALTER TABLE productos ADD COLUMN stock INTEGER DEFAULT 0;");
    }
  }

  // ✅ CRUD (igual que antes, no cambia nada)
  Future<int> insertProducto(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('productos', {
      'codigo': data['codigo'], // ✅ nuevo campo
      'nombre': data['nombre'],
      'descripcion': data['descripcion'] ?? '', // ✅ nuevo campo
      'precio_venta': data['precio_venta'],
      'costo_compra': data['costo_compra'] ?? 0.0, // ✅ nuevo campo
      'stock': data['stock'] ?? 0,
      'categoria_id': data['categoria_id']
    });
    notifyDbChange();
    return id;
  }

  Future<int> updateProducto(Map<String, dynamic> data, int id) async {
    final db = await database;
    final count = await db.update(
      'productos',
      {
        'codigo': data['codigo'], // ✅ nuevo campo
        'nombre': data['nombre'],
        'descripcion': data['descripcion'] ?? '', // ✅ nuevo campo
        'precio_venta': data['precio_venta'],
        'costo_compra': data['costo_compra'] ?? 0.0, // ✅ nuevo campo
        'stock': data['stock'] ?? 0,
        'categoria_id': data['categoria_id']
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final id = await db.insert('ventas', {
      'clienteId': data['clienteId'], // ✅ puede ser null
      'fecha': data['fecha'],
      'metodoPago': data['metodoPago'],
      'total': data['total'],
    });
    notifyDbChange();
    return id;
  }

  Future<List<Map<String, dynamic>>> getVentas() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT v.id, v.fecha, v.metodoPago, v.total,
           COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre
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
          Coalesce(c.nombre, 'Consumidor Final') AS clienteNombre 
    FROM deudas d
    LEFT JOIN clientes c ON d.clienteId = c.id
    ORDER BY d.fecha DESC
  ''');
  }

  Future<int> insertVentaBase(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('ventas', {
      'clienteId': data['clienteId'], // ✅ puede ser null
      'fecha': data['fecha'],
      'metodoPago': data['metodoPago'],
      'total': data['total'],
    });
    notifyDbChange();
    return id;
  }

  Future<int> insertItemVenta(Map<String, dynamic> data) async {
    final db = await database;

    // ✅ Verificar stock antes de vender
    final producto = await db.query('productos',
        columns: ['stock'], where: 'id = ?', whereArgs: [data['productoId']]);

    final stockActual =
        (producto.isNotEmpty ? producto.first['stock'] as int : 0);

    if (stockActual < (data['cantidad'] ?? 1)) {
      throw Exception("Stock insuficiente para completar la venta");
    }

    // ✅ Si hay stock suficiente, inserta el item
    final id = await db.insert('items_venta', data);

    // ✅ Descuenta stock
    await db.rawUpdate('UPDATE productos SET stock = stock - ? WHERE id = ?',
        [data['cantidad'], data['productoId']]);

    notifyDbChange();
    return id;
  }

  /// ✅ Detalle de ítems de una venta con snapshot de precios y código
  Future<List<Map<String, dynamic>>> getItemsByVenta(int ventaId) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT 
      iv.cantidad,
      iv.subtotal,
      -- usa snapshot si existe; si no, cae al precio/costo actuales del producto
      COALESCE(iv.precio_unitario, p.precio_venta) AS precioUnitario,
      COALESCE(iv.costo_unitario,  p.costo_compra)  AS costoUnitario,
      p.nombre AS producto,
      p.codigo AS codigo
    FROM items_venta iv
    JOIN productos p ON iv.productoId = p.id
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
          Coalesce(c.nombre, 'Consumidor Final') AS clienteNombre 
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
           COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre
    FROM ventas v
    LEFT JOIN clientes c ON v.clienteId = c.id
    WHERE $where
    ORDER BY v.fecha DESC
  ''', args);
  }

  Future<List<Map<String, dynamic>>> buscarVentasAvanzado({
    int? clienteId,
    String? metodoPago,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;

    String where = "1=1";
    List<dynamic> args = [];

    if (clienteId != null) {
      where += " AND v.clienteId = ?";
      args.add(clienteId);
    }

    if (metodoPago != null && metodoPago.isNotEmpty) {
      where += " AND v.metodoPago = ?";
      args.add(metodoPago);
    }

    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    }

    return await db.rawQuery('''
    SELECT v.*, COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre
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
          COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre
    FROM deudas d
    LEFT JOIN clientes c ON d.clienteId = c.id
    WHERE $where
    ORDER BY d.fecha DESC
  ''', args);
  }

  // 🔹 Total ventas de un día
  Future<double> getTotalVentasDia(DateTime fecha,
      {int? categoriaId, DateTime? desde, DateTime? hasta}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    // Filtrar por fecha específica o rango
    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    } else {
      final dateStr = fecha.toIso8601String().substring(0, 10);
      where += " AND v.fecha LIKE ?";
      args.add("$dateStr%");
    }

    // Filtro por categoría
    String join = "";
    if (categoriaId != null) {
      join = "INNER JOIN items_venta iv ON v.id = iv.ventaId "
          "INNER JOIN productos p ON iv.productoId = p.id ";
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT SUM(v.total) as total
    FROM ventas v
    $join
    WHERE $where
  ''', args);

    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

// 🔹 Total ventas del mes
  Future<double> getTotalVentasMes(DateTime fecha,
      {int? categoriaId, DateTime? desde, DateTime? hasta}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    } else {
      final mes = fecha.month.toString().padLeft(2, '0');
      final anio = fecha.year.toString();
      where +=
          " AND strftime('%m', v.fecha) = ? AND strftime('%Y', v.fecha) = ?";
      args.add(mes);
      args.add(anio);
    }

    String join = "";
    if (categoriaId != null) {
      join = "INNER JOIN items_venta iv ON v.id = iv.ventaId "
          "INNER JOIN productos p ON iv.productoId = p.id ";
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT SUM(v.total) as total
    FROM ventas v
    $join
    WHERE $where
  ''', args);

    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

// 🔹 Total de deudas pendientes
  Future<double> getTotalDeudasPendientes({int? categoriaId}) async {
    final db = await database;
    String join = "";
    String where = "d.estado = 'Pendiente'";
    List<dynamic> args = [];

    if (categoriaId != null) {
      join = "INNER JOIN ventas v ON d.clienteId = v.clienteId "
          "INNER JOIN items_venta iv ON v.id = iv.ventaId "
          "INNER JOIN productos p ON iv.productoId = p.id ";
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT SUM(d.monto) as total
    FROM deudas d
    $join
    WHERE $where
  ''', args);

    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

// 🔹 Producto más vendido
  Future<String> getProductoMasVendido(
      {int? categoriaId, DateTime? desde, DateTime? hasta}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    }

    if (categoriaId != null) {
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT p.nombre, SUM(iv.cantidad) as totalVendida
    FROM items_venta iv
    INNER JOIN productos p ON iv.productoId = p.id
    INNER JOIN ventas v ON iv.ventaId = v.id
    WHERE $where
    GROUP BY p.nombre
    ORDER BY totalVendida DESC
    LIMIT 1
  ''', args);

    return res.isNotEmpty ? res.first['nombre'] as String : "Sin datos";
  }

  // 🔹 Ventas últimos 7 días
  Future<List<Map<String, dynamic>>> getVentasUltimos7Dias(
      {int? categoriaId}) async {
    final db = await database;
    String join = "";
    String where = "v.fecha >= date('now','-7 day')";
    List<dynamic> args = [];

    if (categoriaId != null) {
      join = "INNER JOIN items_venta iv ON v.id = iv.ventaId "
          "INNER JOIN productos p ON iv.productoId = p.id ";
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT strftime('%d', v.fecha) AS dia, SUM(v.total) AS total
    FROM ventas v
    $join
    WHERE $where
    GROUP BY dia
    ORDER BY dia ASC
  ''', args);

    return res
        .map((e) =>
            {'dia': e['dia'], 'total': (e['total'] as num?)?.toDouble() ?? 0})
        .toList();
  }

// 🔹 Distribución de métodos de pago (en %)
  Future<Map<String, double>> getDistribucionMetodosPago(
      {int? categoriaId}) async {
    final db = await database;
    String join = "";
    String where = "1=1";
    List<dynamic> args = [];

    if (categoriaId != null) {
      join = "INNER JOIN items_venta iv ON v.id = iv.ventaId "
          "INNER JOIN productos p ON iv.productoId = p.id ";
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT v.metodoPago, COUNT(*) as cantidad
    FROM ventas v
    $join
    WHERE $where
    GROUP BY v.metodoPago
  ''', args);

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
  Future<List<Map<String, dynamic>>> getProductos({
    String? search,
    int? categoriaId,
    bool soloAgotados = false, // ✅ nuevo parámetro
  }) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    if (search != null && search.isNotEmpty) {
      where += " AND p.nombre LIKE ?";
      args.add('%$search%');
      args.add('%$search%'); // ✅ para buscar en nombre y descripción
    }

    if (categoriaId != null) {
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    if (soloAgotados) {
      where += " AND p.stock <= 0"; // ✅ filtrar productos sin stock
    }

    return await db.rawQuery('''
    SELECT p.id, p.codigo, p.nombre, p.descripcion, p.precio_venta, p.costo_compra, p.stock, p.categoria_id, c.nombre AS categoria_nombre
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

  Future<List<Map<String, dynamic>>> buscarDeudasAvanzado({
    int? clienteId,
    String? estado,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;

    String where = "1=1";
    List<dynamic> args = [];

    if (clienteId != null) {
      where += " AND d.clienteId = ?";
      args.add(clienteId);
    }

    if (estado != null && estado.isNotEmpty) {
      where += " AND d.estado = ?";
      args.add(estado);
    }

    if (desde != null && hasta != null) {
      where += " AND d.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    }

    return await db.rawQuery('''
    SELECT d.id, d.monto, d.fecha, d.estado, d.descripcion,
          COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre
    FROM deudas d
    LEFT JOIN clientes c ON d.clienteId = c.id
    WHERE $where
    ORDER BY d.fecha DESC
  ''', args);
  }

  Future<List<Map<String, dynamic>>> getVentasFiltradasParaReporte({
    int? clienteId,
    String? metodoPago,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    return await buscarVentasAvanzado(
      clienteId: clienteId,
      metodoPago: metodoPago,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<List<Map<String, dynamic>>> getDeudasFiltradasParaReporte({
    int? clienteId,
    String? estado,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    return await buscarDeudasAvanzado(
      clienteId: clienteId,
      estado: estado,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<void> setStock(int productoId, int cantidad) async {
    final db = await database;
    await db.update('productos', {'stock': cantidad},
        where: 'id = ?', whereArgs: [productoId]);
    notifyDbChange();
  }

  Future<void> incrementarStock(int productoId, int cantidad) async {
    final db = await database;
    await db.rawUpdate('UPDATE productos SET stock = stock + ? WHERE id = ?',
        [cantidad, productoId]);
    notifyDbChange();
  }

  Future<void> decrementarStock(int productoId, int cantidad) async {
    final db = await database;
    await db.rawUpdate('UPDATE productos SET stock = stock - ? WHERE id = ?',
        [cantidad, productoId]);
    notifyDbChange();
  }

  Future<int> getProductosSinStockCount() async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT COUNT(*) AS cantidad FROM productos WHERE stock <= 0');
    return (res.isNotEmpty ? res.first['cantidad'] as int : 0);
  }

  /// ✅ Obtener un producto por ID
  Future<Map<String, dynamic>?> getProductoById(int productoId) async {
    final db = await database;
    final res = await db.rawQuery('''
    SELECT p.id, p.codigo, p.nombre, p.descripcion, p.precio_venta, p.costo_compra, p.stock, p.categoria_id, 
           c.nombre AS categoria_nombre
    FROM productos p
    LEFT JOIN categorias c ON p.categoria_id = c.id
    WHERE p.id = ?
    LIMIT 1
  ''', [productoId]);

    return res.isNotEmpty ? res.first : null;
  }

  /// Ganancia total por rango (opcional por categoría)
  Future<double> getGananciaTotal({
    DateTime? desde,
    DateTime? hasta,
    int? categoriaId,
  }) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    }

    if (categoriaId != null) {
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT SUM( (p.precio_venta - p.costo_compra) * iv.cantidad ) AS ganancia
    FROM items_venta iv
    INNER JOIN productos p ON iv.productoId = p.id
    INNER JOIN ventas v ON iv.ventaId = v.id
    WHERE $where
  ''', args);

    return (res.first['ganancia'] as num?)?.toDouble() ?? 0.0;
  }

  /// Ganancia desglosada por producto en un rango
  Future<List<Map<String, dynamic>>> getGananciaPorProducto({
    DateTime? desde,
    DateTime? hasta,
    int? categoriaId,
  }) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];

    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    }
    if (categoriaId != null) {
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }

    final res = await db.rawQuery('''
    SELECT p.id,
           p.codigo,
           p.nombre,
           p.categoria_id,
           SUM(iv.cantidad) AS cantidadVendida,
           SUM(iv.cantidad * p.precio_venta) AS ingreso,
           SUM(iv.cantidad * p.costo_compra) AS costo,
           SUM( (p.precio_venta - p.costo_compra) * iv.cantidad ) AS ganancia
    FROM items_venta iv
    INNER JOIN productos p ON iv.productoId = p.id
    INNER JOIN ventas v ON iv.ventaId = v.id
    WHERE $where
    GROUP BY p.id, p.codigo, p.nombre, p.categoria_id
    ORDER BY ganancia DESC
  ''', args);

    return res
        .map((e) => {
              'productoId': e['id'],
              'codigo': e['codigo'],
              'nombre': e['nombre'],
              'categoria_id': e['categoria_id'],
              'cantidadVendida': (e['cantidadVendida'] as num?)?.toInt() ?? 0,
              'ingreso': (e['ingreso'] as num?)?.toDouble() ?? 0.0,
              'costo': (e['costo'] as num?)?.toDouble() ?? 0.0,
              'ganancia': (e['ganancia'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();
  }

//Lector de barras FUTURA!!! 🧨🧨🎇🎇
  Future<Map<String, dynamic>?> getProductoByCodigo(String codigo) async {
    final db = await database;
    final res = await db.rawQuery('''
    SELECT p.*, c.nombre AS categoria_nombre
    FROM productos p
    LEFT JOIN categorias c ON p.categoria_id = c.id
    WHERE p.codigo = ?
    LIMIT 1
  ''', [codigo]);
    return res.isNotEmpty ? res.first : null;
  }
}
