import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/cliente.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  final StreamController<void> _dbChangeController =
      StreamController.broadcast();
  Stream<void> get onDatabaseChanged => _dbChangeController.stream;
  void notifyDbChange() => _dbChangeController.add(null);

  static Database? _db;

  /// Cierra la conexión actual a la base de datos.
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// Reinicia la conexión para asegurar que se utilice la nueva base.
  Future<void> reopen() async {
    await close();
    await database;
    notifyDbChange();
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    // Inicializar sqflite FFI para escritorio
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolveDbPath();

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 16,
        onCreate: _createTables,
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) await _migrateToV2(db);
          if (oldV < 3) await _migrateItemsVentaV3(db);
          if (oldV < 6) await _hardenProductConstraintsV4(db);
          if (oldV < 6) await _migrateToV6(db);
          if (oldV < 7) await _migrateToV7(db);
          if (oldV < 8) await _migrateToV8(db);
          if (oldV < 9) await _migrateToV9(db);
          if (oldV < 10) await _migrateUsersV10(db);
          if (oldV < 11) await _migrateMovimientosV11(db);
          if (oldV < 12) await _migrateDeudasVentaIdV12(db);
          if (oldV < 13) await _migrateClientesDniV13(db);
          if (oldV < 14) await _migrateToHybridV14(db);
          if (oldV < 15) await _migrateToV15(db);
          if (oldV < 16) await _migrateToV16(db);
        },
        onOpen: (db) async {
          await db.execute("PRAGMA foreign_keys = ON;");
          await db.execute('''
            CREATE TABLE IF NOT EXISTS carrito_temporal (
              id INTEGER PRIMARY KEY,
              data TEXT
            )
          ''');
          try {
            await db.rawQuery("PRAGMA journal_mode = WAL;");
          } catch (_) {}
          try {
            await db.rawQuery("PRAGMA synchronous = NORMAL;");
          } catch (_) {}
          try {
            await db.rawQuery("PRAGMA temp_store = MEMORY;");
          } catch (_) {}

          // Blindar base en caso de DB parcial/rota
          await _ensureBaseIntegrity(db);

          // Índices críticos (idempotentes)
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_items_venta_productoId ON items_venta(productoId);");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_ventas_userId ON ventas(userId);");

          await _ensureStockColumn(db);
          await _createItemVentaTriggersV8(db);

          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_movs_fecha ON movimientos_stock(fecha);");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_movs_tipo ON movimientos_stock(tipo);");

          if (!await _columnExists(db, 'usuarios', 'avatar')) {
            await db.execute("ALTER TABLE usuarios ADD COLUMN avatar TEXT;");
          }
          if (!await _columnExists(db, 'productos', 'imageUrl')) {
            await db.execute("ALTER TABLE productos ADD COLUMN imageUrl TEXT;");
          }
        },
      ),
    );
  }

  /// Resuelve la ruta donde se almacenará la base de datos según la plataforma.
  /// Respeta cualquier ruta establecida mediante [databaseFactory.setDatabasesPath].
  Future<String> _resolveDbPath() async {
    // Si se configuró explícitamente una ruta, utilizarla
    final overridePath = await databaseFactory.getDatabasesPath();
    if (overridePath.isNotEmpty && overridePath != '.' && overridePath != '/') {
      final dir = Directory(overridePath);
      final exeDir = Directory(p.dirname(Platform.resolvedExecutable));
      final insideExe =
          p.isWithin(exeDir.path, p.normalize(p.absolute(overridePath)));
      if (!insideExe && await _isWritable(dir)) {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return p.join(dir.path, 'arctic_stock.db');
      }
    }

    Directory dir;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      dir = Directory(p.join(appData, 'ArcticStock'));
    } else if (Platform.isAndroid) {
      dir = await getApplicationDocumentsDirectory();
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      dir = Directory(p.join(home, '.local', 'share', 'ArcticStock'));
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      dir = Directory(
          p.join(home, 'Library', 'Application Support', 'ArcticStock'));
    } else {
      dir = Directory.current;
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return p.join(dir.path, 'arctic_stock.db');
  }

  Future<bool> _isWritable(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(p.join(dir.path, '.dirtest'));
      await testFile.writeAsString('');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Devuelve la ruta al archivo de base de datos
  Future<String> getDbPath() async {
    final db = await database;
    return db.path;
  }

  // ======= CREATE ALL TABLES =======
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
        codigoBarras TEXT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        precio_venta REAL NOT NULL CHECK(precio_venta >= 0),
        costo_compra REAL NOT NULL DEFAULT 0 CHECK(costo_compra >= 0),
        stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
        categoria_id INTEGER,
        activo INTEGER NOT NULL DEFAULT 1,
        imageUrl TEXT,
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
      )
    ''');

    await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_codigoBarras ON productos(codigoBarras);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos(nombre);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_descripcion ON productos(descripcion);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo);");

    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        dni TEXT,
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
        subtotal REAL,
        descuento REAL,
        discountType TEXT,
        discountValue REAL,
        discountAmount REAL,
        userId INTEGER,
        FOREIGN KEY (clienteId) REFERENCES clientes(id),
        FOREIGN KEY (userId) REFERENCES usuarios(id)
      )
    ''');

    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_clienteId ON ventas(clienteId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_metodoPago ON ventas(metodoPago);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_userId ON ventas(userId);");

    await db.execute('''
      CREATE TABLE deudas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        descripcion TEXT,
        fechaPago TEXT,
        ventaId INTEGER,
        FOREIGN KEY (clienteId) REFERENCES clientes(id),
        FOREIGN KEY (ventaId) REFERENCES ventas(id)
      )
    ''');

    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_deudas_ventaId ON deudas(ventaId);");

    await db.execute('''
      CREATE TABLE items_venta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ventaId INTEGER NOT NULL,
        productoId INTEGER,
        cantidad INTEGER NOT NULL CHECK(cantidad > 0),
        precio_unitario REAL NOT NULL DEFAULT 0 CHECK(precio_unitario >= 0),
        costo_unitario  REAL NOT NULL DEFAULT 0 CHECK(costo_unitario  >= 0),
        subtotal        REAL NOT NULL DEFAULT 0 CHECK(subtotal       >= 0),
        producto_nombre TEXT,
        producto_descripcion TEXT,
        producto_codigo TEXT,
        FOREIGN KEY (ventaId)   REFERENCES ventas(id)     ON DELETE CASCADE,
        FOREIGN KEY (productoId) REFERENCES productos(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_items_venta_ventaId ON items_venta(ventaId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_items_venta_productoId ON items_venta(productoId);");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS carrito_temporal (
        id INTEGER PRIMARY KEY,
        data TEXT
      )
    ''');

    await _createItemVentaTriggersV8(db);
  }

  // ======= ENSURE BASE (para DBs viejas/rotas) =======
  Future<void> _ensureBaseIntegrity(Database db) async {
    await _ensureTableExists(db, 'categorias', '''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await _ensureTableExists(db, 'productos', '''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo TEXT UNIQUE,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        precio_venta REAL NOT NULL CHECK(precio_venta >= 0),
        costo_compra REAL NOT NULL DEFAULT 0 CHECK(costo_compra >= 0),
        stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
        categoria_id INTEGER,
        activo INTEGER NOT NULL DEFAULT 1,
        imageUrl TEXT
      )
    ''');

    await _ensureTableExists(db, 'usuarios', '''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        color TEXT
      )
    ''');

    await _ensureTableExists(db, 'clientes', '''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        dni TEXT,
        telefono TEXT,
        email TEXT,
        direccion TEXT
      )
    ''');

    await _ensureTableExists(db, 'ventas', '''
      CREATE TABLE ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER,
        fecha TEXT NOT NULL,
        metodoPago TEXT NOT NULL,
        total REAL NOT NULL,
        subtotal REAL,
        descuento REAL,
        userId INTEGER
      )
    ''');

    await _ensureTableExists(db, 'deudas', '''
      CREATE TABLE deudas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        descripcion TEXT,
        fechaPago TEXT,
        ventaId INTEGER,
        FOREIGN KEY (clienteId) REFERENCES clientes(id),
        FOREIGN KEY (ventaId) REFERENCES ventas(id)
      )
    ''');

    await _ensureTableExists(db, 'items_venta', '''
      CREATE TABLE items_venta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ventaId INTEGER NOT NULL,
        productoId INTEGER,
        cantidad INTEGER NOT NULL CHECK(cantidad > 0),
        precio_unitario REAL NOT NULL DEFAULT 0 CHECK(precio_unitario >= 0),
        costo_unitario  REAL NOT NULL DEFAULT 0 CHECK(costo_unitario  >= 0),
        subtotal        REAL NOT NULL DEFAULT 0 CHECK(subtotal       >= 0),
        producto_nombre TEXT,
        producto_descripcion TEXT,
        producto_codigo TEXT
      )
    ''');

    await db.execute('''
  CREATE TABLE IF NOT EXISTS movimientos_stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT NOT NULL,
    productoId INTEGER NOT NULL,
    tipo TEXT NOT NULL,                -- 'ingreso' | 'egreso' | 'ajuste' | 'alta_producto'
    cantidad INTEGER NOT NULL,
    nota TEXT,
    producto_nombre TEXT,              -- snapshot opcional
    producto_codigo TEXT,              -- snapshot opcional
    FOREIGN KEY (productoId) REFERENCES productos(id) ON DELETE CASCADE
  )
''');

    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_movs_fecha ON movimientos_stock(fecha);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_movs_tipo ON movimientos_stock(tipo);");

    await _ensureColumnExists(db, 'productos', 'activo',
        "ALTER TABLE productos ADD COLUMN activo INTEGER NOT NULL DEFAULT 1;");
    await _ensureColumnExists(db, 'productos', 'codigoBarras',
        "ALTER TABLE productos ADD COLUMN codigoBarras TEXT;");
    await _ensureColumnExists(db, 'ventas', 'userId',
        "ALTER TABLE ventas ADD COLUMN userId INTEGER;");
    await _ensureColumnExists(db, 'ventas', 'subtotal',
        "ALTER TABLE ventas ADD COLUMN subtotal REAL;");
    await _ensureColumnExists(db, 'ventas', 'descuento',
        "ALTER TABLE ventas ADD COLUMN descuento REAL;");
    await _ensureColumnExists(db, 'deudas', 'fechaPago',
        "ALTER TABLE deudas ADD COLUMN fechaPago TEXT;");
    await _ensureColumnExists(db, 'deudas', 'ventaId',
        "ALTER TABLE deudas ADD COLUMN ventaId INTEGER;");

    // índices idempotentes
    await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_codigoBarras ON productos(codigoBarras);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos(nombre);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_descripcion ON productos(descripcion);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_clienteId ON ventas(clienteId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_metodoPago ON ventas(metodoPago);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_userId ON ventas(userId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_items_venta_ventaId ON items_venta(ventaId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_items_venta_productoId ON items_venta(productoId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_deudas_ventaId ON deudas(ventaId);");

    // Garantizar columnas de sincronización híbrida
    final syncTables = [
      'categorias',
      'productos',
      'usuarios',
      'clientes',
      'ventas',
      'deudas',
      'movimientos_stock'
    ];

    for (final table in syncTables) {
      await _ensureColumnExists(db, table, 'firebase_id', "ALTER TABLE $table ADD COLUMN firebase_id TEXT;");
      await _ensureColumnExists(db, table, 'last_updated', "ALTER TABLE $table ADD COLUMN last_updated TEXT;");
      await _ensureColumnExists(db, table, 'synced', "ALTER TABLE $table ADD COLUMN synced INTEGER DEFAULT 1;");
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        firebase_id TEXT NOT NULL,
        deleted_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS config_sync (
        negocioId TEXT PRIMARY KEY,
        ownerEmail TEXT,
        last_sync_timestamp TEXT
      )
    ''');
  }

  Future<bool> _tableExists(Database db, String name) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [name],
    );
    return res.isNotEmpty;
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final res = await db.rawQuery("PRAGMA table_info($table);");
    return res.any((c) => c['name'] == column);
  }

  Future<void> _ensureTableExists(
      Database db, String name, String createSql) async {
    if (!await _tableExists(db, name)) {
      await db.execute(createSql);
    }
  }

  Future<void> _ensureColumnExists(
      Database db, String table, String column, String alterSql) async {
    if (await _tableExists(db, table) &&
        !await _columnExists(db, table, column)) {
      await db.execute(alterSql);
    }
  }

  Future<void> _ensureStockColumn(Database db) async {
    if (!await _columnExists(db, 'productos', 'stock')) {
      await db
          .execute("ALTER TABLE productos ADD COLUMN stock INTEGER DEFAULT 0;");
    }
  }

  // ======= MIGRACIONES EXISTENTES =======
  Future _migrateToV2(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(productos);");
    bool hasCodigo = cols.any((c) => c['name'] == 'codigo');
    bool hasDescripcion = cols.any((c) => c['name'] == 'descripcion');
    bool hasCostoCompra = cols.any((c) => c['name'] == 'costo_compra');
    bool hasPrecioVenta = cols.any((c) => c['name'] == 'precio_venta');

    if (!hasCodigo) {
      await db.execute("ALTER TABLE productos ADD COLUMN codigo TEXT;");
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
      final hasPrecioLegacy = cols.any((c) => c['name'] == 'precio');
      if (hasPrecioLegacy) {
        await db.execute(
            "UPDATE productos SET precio_venta = precio WHERE precio_venta IS NULL;");
      }
      await db.execute(
          "UPDATE productos SET precio_venta = COALESCE(precio_venta, 0);");
    }
  }

  Future<void> _migrateItemsVentaV3(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(items_venta);");
    final hasPU = cols.any((c) => c['name'] == 'precio_unitario');
    final hasCU = cols.any((c) => c['name'] == 'costo_unitario');

    if (!hasPU) {
      await db
          .execute("ALTER TABLE items_venta ADD COLUMN precio_unitario REAL;");
    }
    if (!hasCU) {
      await db.execute(
          "ALTER TABLE items_venta ADD COLUMN costo_unitario REAL DEFAULT 0;");
    }

    await db.execute('''
      UPDATE items_venta
      SET 
        precio_unitario = COALESCE(
          precio_unitario,
          CASE 
            WHEN cantidad IS NOT NULL AND cantidad > 0 AND subtotal IS NOT NULL THEN subtotal / cantidad
            ELSE (SELECT p.precio_venta FROM productos p WHERE p.id = items_venta.productoId)
          END
        ),
        costo_unitario = COALESCE(
          costo_unitario,
          (SELECT p.costo_compra FROM productos p WHERE p.id = items_venta.productoId),
          0
        )
    ''');
  }

  Future<void> _hardenProductConstraintsV4(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF;');
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE productos RENAME TO productos_old;');
      await txn.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          codigo TEXT UNIQUE,
          nombre TEXT NOT NULL,
          descripcion TEXT,
          precio_venta REAL NOT NULL CHECK(precio_venta >= 0),
          costo_compra REAL NOT NULL DEFAULT 0 CHECK(costo_compra >= 0),
          stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
          categoria_id INTEGER,
          FOREIGN KEY (categoria_id) REFERENCES categorias(id)
        )
      ''');
      await txn.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo);");
      await txn.execute('''
        INSERT INTO productos (id, codigo, nombre, descripcion, precio_venta, costo_compra, stock, categoria_id)
        SELECT 
          id, codigo, nombre, descripcion,
          CASE WHEN precio_venta IS NULL OR precio_venta < 0 THEN 0 ELSE precio_venta END,
          CASE WHEN costo_compra IS NULL OR costo_compra < 0 THEN 0 ELSE costo_compra END,
          CASE WHEN stock IS NULL OR stock < 0 THEN 0 ELSE stock END,
          categoria_id
        FROM productos_old;
      ''');
      await txn.execute('DROP TABLE productos_old;');
    });
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future _migrateToV6(Database db) async {
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_clienteId ON ventas(clienteId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_ventas_metodoPago ON ventas(metodoPago);");

    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_items_venta_ventaId ON items_venta(ventaId);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_items_venta_productoId ON items_venta(productoId);");

    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos(nombre);");
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_productos_descripcion ON productos(descripcion);");

    await db.execute('''
      UPDATE items_venta AS iv
      SET 
        precio_unitario = COALESCE(
          iv.precio_unitario,
          (SELECT p.precio_venta FROM productos p WHERE p.id = iv.productoId)
        ),
        costo_unitario  = COALESCE(
          iv.costo_unitario,
          (SELECT p.costo_compra FROM productos p WHERE p.id = iv.productoId),
          0
        ),
        subtotal = COALESCE(
          iv.subtotal,
          COALESCE(iv.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = iv.productoId))
          * COALESCE(iv.cantidad, 0)
        )
      WHERE iv.productoId IS NOT NULL;
    ''');

    await _createItemVentaTriggers(db);
  }

  Future<void> _migrateToV7(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF;');
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE items_venta_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ventaId INTEGER NOT NULL,
          productoId INTEGER NOT NULL,
          cantidad INTEGER NOT NULL CHECK(cantidad > 0),
          precio_unitario REAL NOT NULL DEFAULT 0 CHECK(precio_unitario >= 0),
          costo_unitario  REAL NOT NULL DEFAULT 0 CHECK(costo_unitario  >= 0),
          subtotal        REAL NOT NULL DEFAULT 0 CHECK(subtotal       >= 0),
          FOREIGN KEY (ventaId)   REFERENCES ventas(id)    ON DELETE CASCADE,
          FOREIGN KEY (productoId) REFERENCES productos(id) ON DELETE RESTRICT
        );
      ''');

      await txn.execute('''
        INSERT INTO items_venta_new
          (id, ventaId, productoId, cantidad, precio_unitario, costo_unitario, subtotal)
        SELECT
          iv.id, iv.ventaId, iv.productoId,
          CASE WHEN iv.cantidad IS NULL OR iv.cantidad <= 0 THEN 1 ELSE iv.cantidad END,
          COALESCE(iv.precio_unitario, p.precio_venta, 0),
          COALESCE(iv.costo_unitario,  p.costo_compra, 0),
          COALESCE(iv.subtotal, COALESCE(iv.precio_unitario, p.precio_venta, 0) * COALESCE(NULLIF(iv.cantidad, 0), 1))
        FROM items_venta iv
        JOIN productos p ON p.id = iv.productoId;
      ''');

      await txn.execute('DROP TABLE items_venta;');
      await txn.execute('ALTER TABLE items_venta_new RENAME TO items_venta;');

      await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_items_venta_ventaId ON items_venta(ventaId);');
      await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_items_venta_productoId ON items_venta(productoId);');
    });
    await db.execute('PRAGMA foreign_keys = ON;');

    await _createItemVentaTriggers(db);
  }

  Future<void> _migrateToV8(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(items_venta);");
    bool hasNombre = cols.any((c) => c['name'] == 'producto_nombre');
    bool hasDesc = cols.any((c) => c['name'] == 'producto_descripcion');
    bool hasCod = cols.any((c) => c['name'] == 'producto_codigo');

    if (!hasNombre) {
      await db
          .execute("ALTER TABLE items_venta ADD COLUMN producto_nombre TEXT;");
    }
    if (!hasDesc) {
      await db.execute(
          "ALTER TABLE items_venta ADD COLUMN producto_descripcion TEXT;");
    }
    if (!hasCod) {
      await db
          .execute("ALTER TABLE items_venta ADD COLUMN producto_codigo TEXT;");
    }

    await db.execute('''
      UPDATE items_venta AS iv
      SET 
        producto_nombre      = COALESCE(iv.producto_nombre,      (SELECT p.nombre      FROM productos p WHERE p.id = iv.productoId)),
        producto_descripcion = COALESCE(iv.producto_descripcion, (SELECT p.descripcion FROM productos p WHERE p.id = iv.productoId)),
        producto_codigo      = COALESCE(iv.producto_codigo,      (SELECT p.codigo      FROM productos p WHERE p.id = iv.productoId))
      WHERE iv.productoId IS NOT NULL;
    ''');

    await db.execute('PRAGMA foreign_keys = OFF;');
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE items_venta_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ventaId INTEGER NOT NULL,
          productoId INTEGER,
          cantidad INTEGER NOT NULL CHECK(cantidad > 0),
          precio_unitario REAL NOT NULL DEFAULT 0 CHECK(precio_unitario >= 0),
          costo_unitario  REAL NOT NULL DEFAULT 0 CHECK(costo_unitario  >= 0),
          subtotal        REAL NOT NULL DEFAULT 0 CHECK(subtotal       >= 0),
          producto_nombre TEXT,
          producto_descripcion TEXT,
          producto_codigo TEXT,
          FOREIGN KEY (ventaId)   REFERENCES ventas(id)    ON DELETE CASCADE,
          FOREIGN KEY (productoId) REFERENCES productos(id) ON DELETE SET NULL
        );
      ''');

      await txn.execute('''
        INSERT INTO items_venta_new
          (id, ventaId, productoId, cantidad, precio_unitario, costo_unitario, subtotal,
           producto_nombre, producto_descripcion, producto_codigo)
        SELECT
          iv.id, iv.ventaId, iv.productoId,
          CASE WHEN iv.cantidad IS NULL OR iv.cantidad <= 0 THEN 1 ELSE iv.cantidad END,
          COALESCE(iv.precio_unitario, 0),
          COALESCE(iv.costo_unitario, 0),
          COALESCE(iv.subtotal, 0),
          iv.producto_nombre, iv.producto_descripcion, iv.producto_codigo
        FROM items_venta iv;
      ''');

      await txn.execute('DROP TABLE items_venta;');
      await txn.execute('ALTER TABLE items_venta_new RENAME TO items_venta;');

      await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_items_venta_ventaId ON items_venta(ventaId);');
      await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_items_venta_productoId ON items_venta(productoId);');
    });
    await db.execute('PRAGMA foreign_keys = ON;');

    await _createItemVentaTriggersV8(db);
  }

  Future<void> _migrateToV9(Database db) async {
    if (!await _columnExists(db, 'productos', 'activo')) {
      await db.execute(
          'ALTER TABLE productos ADD COLUMN activo INTEGER NOT NULL DEFAULT 1;');
    }
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo);');
  }

  Future<void> _migrateUsersV10(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        color TEXT
      );
    ''');

    if (await _tableExists(db, 'ventas')) {
      if (!await _columnExists(db, 'ventas', 'userId')) {
        await db.execute('ALTER TABLE ventas ADD COLUMN userId INTEGER;');
      }
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ventas_userId ON ventas(userId);');
    } else {
      await db.execute('''
        CREATE TABLE ventas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          clienteId INTEGER,
          fecha TEXT NOT NULL,
          metodoPago TEXT NOT NULL,
          total REAL NOT NULL,
          userId INTEGER
        );
      ''');
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);");
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_ventas_clienteId ON ventas(clienteId);");
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_ventas_metodoPago ON ventas(metodoPago);");
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_ventas_userId ON ventas(userId);");
    }
  }

  // ======= TRIGGERS =======
  Future<void> _createItemVentaTriggers(Database db) async {
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_items_venta_after_insert
      AFTER INSERT ON items_venta
      FOR EACH ROW
      BEGIN
        UPDATE items_venta
        SET 
          precio_unitario = COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId)),
          costo_unitario  = COALESCE(NEW.costo_unitario,  (SELECT p.costo_compra FROM productos p WHERE p.id = NEW.productoId), 0),
          subtotal = COALESCE(NEW.subtotal,
                      COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId))
                      * COALESCE(NEW.cantidad, 0))
        WHERE id = NEW.id;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_items_venta_after_update
      AFTER UPDATE OF cantidad, precio_unitario, costo_unitario, productoId, subtotal
      ON items_venta
      FOR EACH ROW
      BEGIN
        UPDATE items_venta
        SET 
          precio_unitario = COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId)),
          costo_unitario  = COALESCE(NEW.costo_unitario,  (SELECT p.costo_compra FROM productos p WHERE p.id = NEW.productoId), 0),
          subtotal = COALESCE(NEW.subtotal,
                      COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId))
                      * COALESCE(NEW.cantidad, 0))
        WHERE id = NEW.id;
      END;
    ''');
  }

  Future<void> _createItemVentaTriggersV8(Database db) async {
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_items_venta_v8_after_insert
      AFTER INSERT ON items_venta
      FOR EACH ROW
      BEGIN
        UPDATE items_venta
        SET 
          precio_unitario = COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId), 0),
          costo_unitario  = COALESCE(NEW.costo_unitario,  (SELECT p.costo_compra FROM productos p WHERE p.id = NEW.productoId), 0),
          subtotal        = COALESCE(NEW.subtotal,
                                COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId), 0)
                                * COALESCE(NEW.cantidad, 0)),
          producto_nombre      = COALESCE(NEW.producto_nombre,      (SELECT p.nombre      FROM productos p WHERE p.id = NEW.productoId)),
          producto_descripcion = COALESCE(NEW.producto_descripcion, (SELECT p.descripcion FROM productos p WHERE p.id = NEW.productoId)),
          producto_codigo      = COALESCE(NEW.producto_codigo,      (SELECT p.codigo      FROM productos p WHERE p.id = NEW.productoId))
        WHERE id = NEW.id;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_items_venta_v8_after_update
      AFTER UPDATE OF cantidad, precio_unitario, costo_unitario, productoId, subtotal,
                      producto_nombre, producto_descripcion, producto_codigo
      ON items_venta
      FOR EACH ROW
      BEGIN
        UPDATE items_venta
        SET 
          precio_unitario = COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId), 0),
          costo_unitario  = COALESCE(NEW.costo_unitario,  (SELECT p.costo_compra FROM productos p WHERE p.id = NEW.productoId), 0),
          subtotal        = COALESCE(NEW.subtotal,
                                COALESCE(NEW.precio_unitario, (SELECT p.precio_venta FROM productos p WHERE p.id = NEW.productoId), 0)
                                * COALESCE(NEW.cantidad, 0)),
          producto_nombre      = COALESCE(NEW.producto_nombre,      (SELECT p.nombre      FROM productos p WHERE p.id = NEW.productoId)),
          producto_descripcion = COALESCE(NEW.producto_descripcion, (SELECT p.descripcion FROM productos p WHERE p.id = NEW.productoId)),
          producto_codigo      = COALESCE(NEW.producto_codigo,      (SELECT p.codigo      FROM productos p WHERE p.id = NEW.productoId))
        WHERE id = NEW.id;
      END;
    ''');
  }

  // ======= CRUD / QUERIES =======
  Map<String, dynamic> _withSyncMeta(Map<String, dynamic> map, {bool forceDirty = true}) {
    final copy = Map<String, dynamic>.from(map);
    final now = DateTime.now().toIso8601String();
    if (forceDirty) {
      copy['synced'] = 0;
      copy['last_updated'] = now;
    } else {
      copy['synced'] ??= 0;
      copy['last_updated'] ??= now;
    }
    return copy;
  }

  Future<int> insertProducto(Map<String, dynamic> data) async {
    final db = await database;
    final String? inputCodigo = data['codigo']?.toString().trim().isEmpty == true ? null : data['codigo']?.toString().trim();
    final String? inputBarcode = data['codigoBarras']?.toString().trim().isEmpty == true ? null : data['codigoBarras']?.toString().trim();

    String? finalCodigo = inputCodigo;
    String? finalBarcode = inputBarcode;
    if (finalCodigo == null && finalBarcode != null) {
      finalCodigo = finalBarcode;
    } else if (finalCodigo != null && finalBarcode == null) {
      finalBarcode = finalCodigo;
    }

    final id = await db.insert('productos', _withSyncMeta({
      'codigo': finalCodigo,
      'codigoBarras': finalBarcode,
      'nombre': data['nombre'],
      'descripcion': data['descripcion'] ?? '',
      'precio_venta': data['precio_venta'],
      'costo_compra': data['costo_compra'] ?? 0.0,
      'stock': data['stock'] ?? 0,
      'categoria_id': data['categoria_id'],
      'imageUrl': data['imageUrl']
    }, forceDirty: false));
    final stockInicial = (data['stock'] as int?) ?? 0;
    if (stockInicial > 0) {
      await _logMovimientoStock(
        productoId: id,
        tipo: 'alta_producto',
        cantidad: stockInicial,
        nota: 'Alta con stock inicial',
      );
    }
    notifyDbChange();
    return id;
  }

  Future<int> updateProducto(Map<String, dynamic> data, int id) async {
    final db = await database;
    final String? inputCodigo = data['codigo']?.toString().trim().isEmpty == true ? null : data['codigo']?.toString().trim();
    final String? inputBarcode = data['codigoBarras']?.toString().trim().isEmpty == true ? null : data['codigoBarras']?.toString().trim();

    String? finalCodigo = inputCodigo;
    String? finalBarcode = inputBarcode;
    if (finalCodigo == null && finalBarcode != null) {
      finalCodigo = finalBarcode;
    } else if (finalCodigo != null && finalBarcode == null) {
      finalBarcode = finalCodigo;
    }

    final count = await db.update(
      'productos',
      _withSyncMeta({
        'codigo': finalCodigo,
        'codigoBarras': finalBarcode,
        'nombre': data['nombre'],
        'descripcion': data['descripcion'] ?? '',
        'precio_venta': data['precio_venta'],
        'costo_compra': data['costo_compra'] ?? 0.0,
        'stock': data['stock'] ?? 0,
        'categoria_id': data['categoria_id'],
        'imageUrl': data['imageUrl']
      }),
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDbChange();
    return count;
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    final count = await db.update('productos', _withSyncMeta({'activo': 0}),
        where: 'id = ?', whereArgs: [id]);
    notifyDbChange();
    return count;
  }

  Future<int> activarProducto(int id) async {
    final db = await database;
    final count = await db.update('productos', _withSyncMeta({'activo': 1}),
        where: 'id = ?', whereArgs: [id]);
    notifyDbChange();
    return count;
  }

  Future<int> insertVenta(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('ventas', _withSyncMeta({
      'clienteId': data['clienteId'],
      'fecha': data['fecha'],
      'metodoPago': data['metodoPago'],
      'total': data['total'],
      'subtotal': data['subtotal'] ?? data['total'],
      'descuento': data['descuento'] ?? 0.0,
      'discountType': data['discountType'],
      'discountValue': data['discountValue'] ?? 0.0,
      'discountAmount': data['discountAmount'] ?? data['descuento'] ?? 0.0,
      'userId': data['userId'] ?? _activeUserId,
    }, forceDirty: false));
    notifyDbChange();
    return id;
  }

  Future<List<Map<String, dynamic>>> getVentas({String? orderBy}) async {
    final db = await database;
    String orderClause = "v.fecha DESC";
    if (orderBy == 'fecha_asc') orderClause = "v.fecha ASC";
    if (orderBy == 'fecha_desc') orderClause = "v.fecha DESC";
    if (orderBy == 'total_asc') orderClause = "v.total ASC";
    if (orderBy == 'total_desc') orderClause = "v.total DESC";

    return await db.rawQuery('''
      SELECT v.id, v.fecha, v.metodoPago, v.total, v.subtotal, v.descuento,
             COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
             u.nombre AS usuarioNombre
      FROM ventas v
      LEFT JOIN clientes c ON v.clienteId = c.id
      LEFT JOIN usuarios u ON v.userId = u.id
      ORDER BY $orderClause
    ''');
  }

  Future<int> insertDeuda(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('deudas', _withSyncMeta(data, forceDirty: false));
    notifyDbChange();
    return id;
  }

  Future<List<Map<String, dynamic>>> getDeudas() async {
    final db = await database;
    final res = await db.rawQuery('''
  SELECT d.id,
         d.clienteId,
         d.monto,
         d.fecha,
         d.estado,
         d.descripcion,
         d.ventaId,
         d.fechaPago,
         COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
         COALESCE(p.cantidad, 0)            AS pendientesCount
  FROM deudas d
  LEFT JOIN clientes c ON d.clienteId = c.id
  LEFT JOIN (
    SELECT clienteId, COUNT(*) AS cantidad
    FROM deudas
    WHERE estado = 'Pendiente'
    GROUP BY clienteId
  ) p ON d.clienteId = p.clienteId
  ORDER BY d.fecha DESC
''');
    return res;
  }

  Future<void> markDeudaAsPagada(int id, double monto) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Obtener datos de la deuda para actualizar la venta asociada
    final deuda = await db.query('deudas',
        columns: ['clienteId', 'ventaId'], where: 'id = ?', whereArgs: [id]);
    final clienteId =
        deuda.isNotEmpty ? deuda.first['clienteId'] as int? : null;
    final ventaId = deuda.isNotEmpty ? deuda.first['ventaId'] as int? : null;

    // Actualizar estado y fecha de pago de la deuda
    await db.update(
      'deudas',
      _withSyncMeta({
        'estado': 'Pagada',
        'fechaPago': now,
      }),
      where: 'id = ?',
      whereArgs: [id],
    );

    if (ventaId != null) {
      // Actualizar la venta original para reflejar el pago de la deuda
      await db.update(
        'ventas',
        _withSyncMeta({
          'metodoPago': 'PagoDeuda',
          'fecha': now,
        }),
        where: 'id = ?',
        whereArgs: [ventaId],
      );
    } else {
      // Fallback para deudas sin venta asociada
      await db.insert('ventas', _withSyncMeta({
        'clienteId': clienteId,
        'fecha': now,
        'metodoPago': 'PagoDeuda',
        'total': monto,
        'userId': _activeUserId,
      }, forceDirty: false));
    }

    notifyDbChange();
  }

  Future<void> revertirDeudaAPendiente(int id) async {
    final db = await database;
    final deudas = await db.query('deudas', columns: ['ventaId'], where: 'id = ?', whereArgs: [id]);
    final ventaId = deudas.isNotEmpty ? deudas.first['ventaId'] as int? : null;

    await db.update(
      'deudas',
      _withSyncMeta({
        'estado': 'Pendiente',
        'fechaPago': null,
      }),
      where: 'id = ?',
      whereArgs: [id],
    );

    if (ventaId != null) {
      await db.update(
        'ventas',
        _withSyncMeta({
          'metodoPago': 'Fiado',
        }),
        where: 'id = ?',
        whereArgs: [ventaId],
      );
    }

    notifyDbChange();
  }

  Future<int> countDeudasCliente(int clienteId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS cantidad FROM deudas WHERE clienteId = ? AND estado = ?',
      [clienteId, 'Pendiente'],
    );
    final v = res.isNotEmpty ? res.first['cantidad'] : 0;
    return (v is int) ? v : (v as num?)?.toInt() ?? 0;
  }

  Future<int> countDeudasClienteTotal(int clienteId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM deudas WHERE clienteId = ?',
      [clienteId],
    );
    final v = res.isNotEmpty ? res.first['total'] : 0;
    return (v is int) ? v : (v as num?)?.toInt() ?? 0;
  }

  Future<int> insertItemVenta(Map<String, dynamic> data) async {
    final db = await database;

    final producto = await db.query(
      'productos',
      columns: [
        'stock',
        'precio_venta',
        'costo_compra',
        'nombre',
        'descripcion',
        'codigo',
        'activo'
      ],
      where: 'id = ?',
      whereArgs: [data['productoId']],
    );

    if (producto.isEmpty) throw Exception("Producto inexistente");
    if ((producto.first['activo'] as int? ?? 1) == 0) {
      throw Exception("Producto inactivo");
    }

    final stockActual = (producto.first['stock'] as int? ?? 0);
    final cant = (data['cantidad'] as num?)?.toInt() ?? 0;
    if (cant <= 0) throw Exception("Cantidad inválida");
    if (stockActual < cant) throw Exception("Stock insuficiente");

    final puSnap = (data['precio_unitario'] as num?)?.toDouble() ??
        (producto.first['precio_venta'] as num?)?.toDouble() ??
        0.0;
    final cuSnap = (data['costo_unitario'] as num?)?.toDouble() ??
        (producto.first['costo_compra'] as num?)?.toDouble() ??
        0.0;
    final subSnap = (data['subtotal'] as num?)?.toDouble() ?? (puSnap * cant);

    final row = {
      'ventaId': data['ventaId'],
      'productoId': data['productoId'],
      'cantidad': cant,
      'precio_unitario': puSnap,
      'costo_unitario': cuSnap,
      'subtotal': subSnap,
      'producto_nombre': data['producto_nombre'] ?? producto.first['nombre'],
      'producto_descripcion':
          data['producto_descripcion'] ?? (producto.first['descripcion'] ?? ''),
      'producto_codigo':
          data['producto_codigo'] ?? (producto.first['codigo'] ?? ''),
    };

    // Insertamos el ítem
    final id = await db.insert('items_venta', row);

    // Restamos stock del producto
    await db.rawUpdate(
      'UPDATE productos SET stock = stock - ?, synced = 0, last_updated = ? WHERE id = ?',
      [cant, DateTime.now().toIso8601String(), data['productoId']],
    );

    // Registramos movimiento de stock (EGRESO por venta)
    await _logMovimientoStock(
      productoId: data['productoId'] as int,
      tipo: 'egreso',
      cantidad: cant,
      nota: 'Venta #${row['ventaId']}',
    );

    notifyDbChange();
    return id;
  }

  Future<List<Map<String, dynamic>>> getItemsByVenta(int ventaId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        iv.cantidad,
        iv.subtotal,
        iv.precio_unitario  AS precioUnitario,
        iv.costo_unitario   AS costoUnitario,
        COALESCE(iv.producto_nombre,      p.nombre)      AS producto,
        COALESCE(iv.producto_descripcion, p.descripcion) AS descripcion,
        COALESCE(iv.producto_codigo,      p.codigo)      AS codigo
      FROM items_venta iv
      LEFT JOIN productos p ON iv.productoId = p.id
      WHERE iv.ventaId = ?
    ''', [ventaId]);
  }

  Future<void> updateVentaTotal(int ventaId, double total) async {
    final db = await database;
    await db.update('ventas', _withSyncMeta({'total': total}),
        where: 'id = ?', whereArgs: [ventaId]);
    notifyDbChange();
  }

  Future<List<Map<String, dynamic>>> getDeudasByCliente(int clienteId) async {
    final db = await database;
    return await db.query('deudas', where: 'clienteId = ?', whereArgs: [clienteId], orderBy: 'fecha DESC');
  }

  Future<List<Map<String, dynamic>>> getStockProductos() async {
    final db = await database;
    return await db.query('productos');
  }

  Future<List<Map<String, dynamic>>> getVentasDelMes(
      String mes, String anio) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM ventas
      WHERE strftime('%m', fecha) = ? AND strftime('%Y', fecha) = ?
    ''', [mes, anio]);
  }

  Future<List<Map<String, dynamic>>> getDeudasDelMes(
      String mes, String anio) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM deudas
      WHERE strftime('%m', fecha) = ? AND strftime('%Y', fecha) = ?
    ''', [mes, anio]);
  }

  Future<int> insertCliente(Cliente cliente) async {
    final db = await database;
    final id = await db.insert('clientes', _withSyncMeta(cliente.toMap(), forceDirty: false));
    notifyDbChange();
    return id;
  }

  Future<List<Cliente>> getClientes() async {
    final db = await database;
    final res = await db.query('clientes');
    return res.map((e) => Cliente.fromMap(e)).toList();
  }

  Future<int> updateCliente(Cliente cliente) async {
    final db = await database;
    final count = await db.update('clientes', _withSyncMeta(cliente.toMap()),
        where: 'id = ?', whereArgs: [cliente.id]);
    notifyDbChange();
    return count;
  }

  Future<int> deleteCliente(int id) async {
    final db = await database;
    // Registro de baja en deleted_records para sincronización
    final rec = await db.query('clientes', columns: ['firebase_id'], where: 'id = ?', whereArgs: [id]);
    if (rec.isNotEmpty && rec.first['firebase_id'] != null) {
      await db.insert('deleted_records', {
        'table_name': 'clientes',
        'firebase_id': rec.first['firebase_id'] as String,
        'deleted_at': DateTime.now().toIso8601String(),
      });
    }
    final count = await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
    notifyDbChange();
    return count;
  }

  Future<Map<String, dynamic>?> getVentaById(int ventaId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT v.id, v.fecha, v.metodoPago, v.total, v.subtotal, v.descuento,
             COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
             u.nombre AS usuarioNombre
      FROM ventas v
      LEFT JOIN clientes c ON v.clienteId = c.id
      LEFT JOIN usuarios u ON v.userId = u.id
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
             COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
             u.nombre AS usuarioNombre
      FROM ventas v
      LEFT JOIN clientes c ON v.clienteId = c.id
      LEFT JOIN usuarios u ON v.userId = u.id
      WHERE $where
      ORDER BY v.fecha DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> buscarVentasAvanzado({
    int? clienteId,
    String? metodoPago,
    DateTime? desde,
    DateTime? hasta,
    String? productoQuery,
    String? orderBy,
  }) async {
    final db = await database;

    String where = "1=1";
    List<dynamic> args = [];
    String extraJoins = "";

    if (clienteId != null) {
      where += " AND v.clienteId = ?";
      args.add(clienteId);
    }
    if (metodoPago != null && metodoPago.isNotEmpty) {
      where += " AND v.metodoPago = ?";
      args.add(metodoPago);
    }

    // RANGO SEMI-ABIERTO [desde, hasta+1d)
    if (desde != null && hasta != null) {
      final desdeIso =
          DateTime(desde.year, desde.month, desde.day).toIso8601String();
      final hastaExcl = DateTime(hasta.year, hasta.month, hasta.day)
          .add(const Duration(days: 1))
          .toIso8601String();
      where += " AND v.fecha >= ? AND v.fecha < ?";
      args.addAll([desdeIso, hastaExcl]);
    }

    // 🔎 Filtro por producto (busca en snapshot de items_venta y, si existe, en productos)
    // Here we perform the query without filtering by `productoQuery` because
    // we want to filter with accent-insensitivity and checking barcode as well in memory,
    // just like we do for products.
    if (productoQuery != null && productoQuery.trim().isNotEmpty) {
      extraJoins += '''
      LEFT JOIN items_venta iv ON iv.ventaId = v.id
      LEFT JOIN productos p ON iv.productoId = p.id
    ''';
      // To get the actual product data to filter in memory:
      // We will select the relevant fields. Since we GROUP BY v.id later,
      // GROUP_CONCAT is needed to get all items data per sale.
    }

    String orderClause = "v.fecha DESC";
    if (orderBy == 'fecha_asc') orderClause = "v.fecha ASC";
    if (orderBy == 'fecha_desc') orderClause = "v.fecha DESC";
    if (orderBy == 'total_asc') orderClause = "v.total ASC";
    if (orderBy == 'total_desc') orderClause = "v.total DESC";

    final results = await db.rawQuery('''
    SELECT 
      v.*,
      COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
      u.nombre AS usuarioNombre
      ${productoQuery != null && productoQuery.trim().isNotEmpty ? ", GROUP_CONCAT(COALESCE(iv.producto_nombre, p.nombre, '')) as all_nombres, GROUP_CONCAT(COALESCE(iv.producto_descripcion, p.descripcion, '')) as all_descripciones, GROUP_CONCAT(COALESCE(iv.producto_codigo, p.codigo, '')) as all_codigos, GROUP_CONCAT(p.codigoBarras) as all_codigoBarras" : ""}
    FROM ventas v
    LEFT JOIN clientes c ON v.clienteId = c.id
    LEFT JOIN usuarios u ON v.userId = u.id
    $extraJoins
    WHERE $where
    GROUP BY v.id
    ORDER BY $orderClause
  ''', args);

    if (productoQuery != null && productoQuery.trim().isNotEmpty) {
      final normalizedSearch = normalizeString(productoQuery.trim());
      return results.where((v) {
        final nombres = normalizeString(v['all_nombres'] as String? ?? '');
        final desc = normalizeString(v['all_descripciones'] as String? ?? '');
        final codigos = normalizeString(v['all_codigos'] as String? ?? '');
        final codigoBarras = normalizeString(v['all_codigoBarras'] as String? ?? '');

        return nombres.contains(normalizedSearch) ||
            desc.contains(normalizedSearch) ||
            codigos.contains(normalizedSearch) ||
            codigoBarras.contains(normalizedSearch);
      }).toList();
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> buscarDeudas({
    String? cliente,
    String? estado,
    String? fecha,
  }) async {
    final db = await database;

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

    return await db.rawQuery('''
      SELECT d.id,
             d.clienteId,
             d.monto,
             d.fecha,
             d.estado,
             d.descripcion,
             d.ventaId,
             d.fechaPago,
             COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
             COALESCE(p.cantidad, 0)            AS pendientesCount
      FROM deudas d
      LEFT JOIN clientes c ON d.clienteId = c.id
      LEFT JOIN (
        SELECT clienteId, COUNT(*) AS cantidad
        FROM deudas
        WHERE estado = 'Pendiente'
        GROUP BY clienteId
      ) p ON d.clienteId = p.clienteId
      WHERE $where
      ORDER BY d.fecha DESC
    ''', args);
  }

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
    SELECT SUM(
      (iv.precio_unitario - iv.costo_unitario) * iv.cantidad
    ) as ganancia
    FROM items_venta iv
    INNER JOIN ventas v ON iv.ventaId = v.id
    LEFT JOIN productos p ON iv.productoId = p.id
    WHERE $where
  ''', args);

    return (res.first['ganancia'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalVentasDia(DateTime fecha,
      {int? categoriaId, DateTime? desde, DateTime? hasta}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];
    String join = "";

    if (desde != null && hasta != null) {
      where += " AND v.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    } else {
      final dateStr = fecha.toIso8601String().substring(0, 10);
      where += " AND v.fecha LIKE ?";
      args.add("$dateStr%");
    }

    if (categoriaId != null) {
      join =
          "INNER JOIN items_venta iv ON v.id = iv.ventaId INNER JOIN productos p ON iv.productoId = p.id ";
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

  Future<double> getTotalVentasMes(DateTime fecha,
      {int? categoriaId, DateTime? desde, DateTime? hasta}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];
    String join = "";

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

    if (categoriaId != null) {
      join =
          "INNER JOIN items_venta iv ON v.id = iv.ventaId INNER JOIN productos p ON iv.productoId = p.id ";
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
      SELECT COALESCE(iv.producto_nombre, p.nombre) AS nombre, SUM(iv.cantidad) AS totalVendida
      FROM items_venta iv
      LEFT JOIN productos p ON iv.productoId = p.id
      INNER JOIN ventas v ON iv.ventaId = v.id
      WHERE $where
      GROUP BY nombre
      ORDER BY totalVendida DESC
      LIMIT 1
    ''', args);

    return res.isNotEmpty ? res.first['nombre'] as String : "Sin datos";
  }

  Future<List<Map<String, dynamic>>> getVentasUltimos7Dias(
      {int? categoriaId}) async {
    final db = await database;
    String join = "";
    String where = "v.fecha >= date('now','-7 day')";
    List<dynamic> args = [];

    if (categoriaId != null) {
      join =
          "INNER JOIN items_venta iv ON v.id = iv.ventaId INNER JOIN productos p ON iv.productoId = p.id ";
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

  Future<Map<String, double>> getDistribucionMetodosPago(
      {int? categoriaId}) async {
    final db = await database;
    String join = "";
    String where = "1=1";
    List<dynamic> args = [];

    if (categoriaId != null) {
      join =
          "INNER JOIN items_venta iv ON v.id = iv.ventaId INNER JOIN productos p ON iv.productoId = p.id ";
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

  Future<List<Map<String, dynamic>>> getCategorias() async {
    final db = await database;
    return await db.query('categorias', orderBy: 'nombre ASC');
  }

  Future<int> insertCategoria(String nombre) async {
    final db = await database;
    return await db.insert('categorias', _withSyncMeta({'nombre': nombre}, forceDirty: false));
  }

  String normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(',', '');
  }

  Future<List<Map<String, dynamic>>> getProductos({
    String? search,
    int? categoriaId,
    bool soloAgotados = false,
    bool incluirInactivos = false,
    String? orderBy,
  }) async {
    final db = await database;

    String where = "1=1";
    final args = <dynamic>[];

    if (!incluirInactivos) {
      where += " AND p.activo = 1";
    }
    if (categoriaId != null) {
      where += " AND p.categoria_id = ?";
      args.add(categoriaId);
    }
    if (soloAgotados) {
      where += " AND p.stock <= 0";
    }

    String orderClause = "p.nombre ASC";
    if (orderBy == 'precio_asc') orderClause = "p.precio_venta ASC";
    if (orderBy == 'precio_desc') orderClause = "p.precio_venta DESC";
    if (orderBy == 'stock_asc') orderClause = "p.stock ASC";
    if (orderBy == 'stock_desc') orderClause = "p.stock DESC";
    if (orderBy == 'popularidad') orderClause = "vendidos_count DESC";
    if (orderBy == 'nombre_asc') orderClause = "p.nombre ASC";

    final results = await db.rawQuery('''
      SELECT p.id, p.codigo, p.codigoBarras, p.nombre, p.descripcion, p.precio_venta,
             p.costo_compra, p.stock, p.categoria_id, p.activo,
             c.nombre AS categoria_nombre,
             COALESCE(v_pop.vendidos_count, 0) AS vendidos_count
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      LEFT JOIN (
        SELECT productoId, SUM(cantidad) AS vendidos_count
        FROM items_venta
        GROUP BY productoId
      ) v_pop ON p.id = v_pop.productoId
      WHERE $where
      ORDER BY $orderClause
    ''', args);

    if (search != null && search.trim().isNotEmpty) {
      final normalizedSearch = normalizeString(search.trim());
      return results.where((p) {
        final nombre = normalizeString(p['nombre'] as String? ?? '');
        final desc = normalizeString(p['descripcion'] as String? ?? '');
        final codigo = normalizeString(p['codigo'] as String? ?? '');
        final barcode = normalizeString(p['codigoBarras'] as String? ?? '');
        return nombre.contains(normalizedSearch) ||
            desc.contains(normalizedSearch) ||
            codigo.contains(normalizedSearch) ||
            barcode.contains(normalizedSearch);
      }).toList();
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> getAllCategorias() async {
    final db = await database;
    return await db.query('categorias', orderBy: 'nombre ASC');
  }

  Future<int> addCategoria(String nombre) async {
    final db = await database;
    return await db.insert('categorias', _withSyncMeta({'nombre': nombre}, forceDirty: false));
  }

  Future<int> updateCategoria(int id, String nombre) async {
    final db = await database;
    return await db.update('categorias', _withSyncMeta({'nombre': nombre}),
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategoria(int id) async {
    final db = await database;
    // Registro de baja en deleted_records para sincronización
    final rec = await db.query('categorias', columns: ['firebase_id'], where: 'id = ?', whereArgs: [id]);
    if (rec.isNotEmpty && rec.first['firebase_id'] != null) {
      await db.insert('deleted_records', {
        'table_name': 'categorias',
        'firebase_id': rec.first['firebase_id'] as String,
        'deleted_at': DateTime.now().toIso8601String(),
      });
    }
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
      final desdeIso =
          DateTime(desde.year, desde.month, desde.day).toIso8601String();
      final hastaExcl = DateTime(hasta.year, hasta.month, hasta.day)
          .add(const Duration(days: 1))
          .toIso8601String();
      where += " AND d.fecha >= ? AND d.fecha < ?";
      args.addAll([desdeIso, hastaExcl]);
    }

    return await db.rawQuery('''
      SELECT d.id,
             d.clienteId,
             d.monto,
             d.fecha,
             d.estado,
             d.descripcion,
             d.ventaId,
             d.fechaPago,
             COALESCE(c.nombre, 'Consumidor Final') AS clienteNombre,
             COALESCE(p.cantidad, 0)            AS pendientesCount
      FROM deudas d
      LEFT JOIN clientes c ON d.clienteId = c.id
      LEFT JOIN (
        SELECT clienteId, COUNT(*) AS cantidad
        FROM deudas
        WHERE estado = 'Pendiente'
        GROUP BY clienteId
      ) p ON d.clienteId = p.clienteId
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
    await db.update('productos', _withSyncMeta({'stock': cantidad}),
        where: 'id = ?', whereArgs: [productoId]);
    notifyDbChange();
  }

  Future<void> setStockConAjuste(int productoId, int nuevoStock, {String? nota}) async {
    final db = await database;
    final prod = await db.query('productos',
        columns: ['stock'], where: 'id = ?', whereArgs: [productoId], limit: 1);
    if (prod.isEmpty) throw Exception('Producto inexistente');
    final stockActual = (prod.first['stock'] as num?)?.toInt() ?? 0;
    final diferencia = nuevoStock - stockActual;
    if (diferencia == 0) return;
    await db.rawUpdate(
      'UPDATE productos SET stock = ?, synced = 0, last_updated = ? WHERE id = ?',
      [nuevoStock, DateTime.now().toIso8601String(), productoId],
    );
    await _logMovimientoStock(
      productoId: productoId,
      tipo: 'ajuste',
      cantidad: diferencia.abs(),
      nota: nota ?? (diferencia > 0 ? 'Ajuste positivo' : 'Ajuste negativo'),
    );
    notifyDbChange();
  }

  Future<void> incrementarStock(int productoId, int cantidad,
      {String? nota}) async {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a 0');
    }

    final db = await database;

    // Verificamos que el producto exista (opcional pero útil)
    final prod = await db.query('productos',
        columns: ['id'], where: 'id = ?', whereArgs: [productoId], limit: 1);
    if (prod.isEmpty) throw Exception('Producto inexistente');

    // 1) Actualizo stock y marcamos para sincronización
    await db.rawUpdate(
      'UPDATE productos SET stock = stock + ?, synced = 0, last_updated = ? WHERE id = ?',
      [cantidad, DateTime.now().toIso8601String(), productoId],
    );

    // 2) Registro el movimiento (ingreso)
    await _logMovimientoStock(
      productoId: productoId,
      tipo: 'ingreso',
      cantidad: cantidad,
      nota: nota ?? 'Ingreso manual',
    );

    notifyDbChange();
  }

  Future<void> decrementarStock(int productoId, int cantidad) async {
    final db = await database;
    await db.rawUpdate('UPDATE productos SET stock = stock - ?, synced = 0, last_updated = ? WHERE id = ?',
        [cantidad, DateTime.now().toIso8601String(), productoId]);
    await _logMovimientoStock(
      productoId: productoId,
      tipo: 'egreso',
      cantidad: cantidad,
      nota: 'Egreso manual',
    );
    notifyDbChange();
  }

  Future<int> getProductosSinStockCount() async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT COUNT(*) AS cantidad FROM productos WHERE stock <= 0');
    return (res.isNotEmpty ? res.first['cantidad'] as int : 0);
  }

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

  Future<Map<String, dynamic>?> getProductoByCodigoOrBarcode(String query) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT p.id, p.codigo, p.codigoBarras, p.nombre, p.descripcion, p.precio_venta, p.costo_compra, p.stock, p.categoria_id, 
             c.nombre AS categoria_nombre
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      WHERE (p.codigo = ? OR p.codigoBarras = ?) AND p.activo = 1
      LIMIT 1
    ''', [query, query]);
    return res.isNotEmpty ? res.first : null;
  }

  // ===== USUARIOS =====
  Future<int> insertUsuario(String nombre, {String? color, String? avatar}) async {
    final db = await database;
    final id = await db.insert(
      'usuarios',
      _withSyncMeta({
        'nombre': nombre.trim(),
        'color': color,
        'avatar': avatar,
      }, forceDirty: false),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    notifyDbChange();
    return id;
  }

  Future<List<Map<String, dynamic>>> getUsuarios() async {
    final db = await database;
    return await db.query('usuarios', orderBy: 'nombre ASC');
  }

  Future<int> updateUsuario(int id, String nuevoNombre, {String? color, String? avatar}) async {
    final db = await database;
    final count = await db.update(
      'usuarios',
      _withSyncMeta({
        'nombre': nuevoNombre.trim(),
        'color': color,
        if (avatar != null) 'avatar': avatar,
      }),
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDbChange();
    return count;
  }

  Future<int> deleteUsuario(int id) async {
    final db = await database;
    await db.update('ventas', _withSyncMeta({'userId': null}),
        where: 'userId = ?', whereArgs: [id]);
    // Registro de baja en deleted_records para sincronización
    final rec = await db.query('usuarios', columns: ['firebase_id'], where: 'id = ?', whereArgs: [id]);
    if (rec.isNotEmpty && rec.first['firebase_id'] != null) {
      await db.insert('deleted_records', {
        'table_name': 'usuarios',
        'firebase_id': rec.first['firebase_id'] as String,
        'deleted_at': DateTime.now().toIso8601String(),
      });
    }
    final count = await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
    notifyDbChange();
    return count;
  }

  Future<int> updateUsuarioAvatar(int id, String? avatarBase64) async {
    final db = await database;
    final count = await db.update(
      'usuarios',
      _withSyncMeta({
        'avatar': avatarBase64,
      }),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (id == _activeUserId) {
      _activeUserAvatar = avatarBase64;
      _activeUserAvatarBytes = (avatarBase64 != null && avatarBase64.isNotEmpty)
          ? base64Decode(avatarBase64)
          : null;
    }
    notifyDbChange();
    return count;
  }

  // ===== Usuario activo (en memoria) =====
  int? _activeUserId;
  String? _activeUserName;
  String? _activeUserAvatar;
  Uint8List? _activeUserAvatarBytes;

  void setActiveUser({required int? id, String? nombre, String? avatar}) {
    _activeUserId = id;
    _activeUserName = nombre;
    _activeUserAvatar = avatar;
    _activeUserAvatarBytes = (avatar != null && avatar.isNotEmpty)
        ? base64Decode(avatar)
        : null;
    notifyDbChange();
  }

  int? get activeUserId => _activeUserId;
  String? get activeUserName => _activeUserName;
  String? get activeUserAvatar => _activeUserAvatar;
  Uint8List? get activeUserAvatarBytes => _activeUserAvatarBytes;

  // Entrada "oficial" desde la UI: normaliza/valida y delega en insertVenta
  Future<int> insertVentaBase(Map<String, dynamic> data) async {
    final fechaIso = () {
      final f = data['fecha'];
      if (f is DateTime) return f.toIso8601String();
      if (f is String && f.isNotEmpty) return f;
      return DateTime.now().toIso8601String();
    }();

    final normalizado = {
      'clienteId': data['clienteId'],
      'fecha': fechaIso,
      'metodoPago': (data['metodoPago'] ?? 'Efectivo').toString(),
      'total': (data['total'] as num?)?.toDouble() ?? 0.0,
      'subtotal': (data['subtotal'] as num?)?.toDouble() ?? (data['total'] as num?)?.toDouble() ?? 0.0,
      'descuento': (data['descuento'] as num?)?.toDouble() ?? 0.0,
      'discountType': data['discountType'],
      'discountValue': (data['discountValue'] as num?)?.toDouble() ?? 0.0,
      'discountAmount': (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      // si no viene, se completa con el usuario activo
      'userId': data['userId'] ?? _activeUserId,
    };

    return insertVenta(normalizado);
  }

  Future<void> _migrateMovimientosV11(Database db) async {
    final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='movimientos_stock';");
    if (exists.isEmpty) {
      await db.execute('''
      CREATE TABLE movimientos_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        productoId INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        nota TEXT,
        producto_nombre TEXT,
        producto_codigo TEXT,
        FOREIGN KEY (productoId) REFERENCES productos(id) ON DELETE CASCADE
      )
    ''');
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_movs_fecha ON movimientos_stock(fecha);");
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_movs_tipo ON movimientos_stock(tipo);");
    }
  }

  Future<void> _migrateDeudasVentaIdV12(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(deudas);");
    final hasVentaId = cols.any((c) => c['name'] == 'ventaId');
    if (!hasVentaId) {
      await db.execute("ALTER TABLE deudas ADD COLUMN ventaId INTEGER;");
      await db.execute(
          "CREATE INDEX IF NOT EXISTS idx_deudas_ventaId ON deudas(ventaId);");
    }
  }

  Future<void> _migrateClientesDniV13(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(clientes);");
    final hasDni = cols.any((c) => c['name'] == 'dni');
    if (!hasDni) {
      await db.execute("ALTER TABLE clientes ADD COLUMN dni TEXT;");
    }
  }

  Future<void> _logMovimientoStock({
    required int productoId,
    required String tipo, // 'ingreso' | 'egreso' | 'ajuste' | 'alta_producto'
    required int cantidad,
    String? nota,
  }) async {
    final db = await database;

    // snapshots del producto (nombre/codigo) para el reporte
    final p = await db.query('productos',
        columns: ['nombre', 'codigo'],
        where: 'id = ?',
        whereArgs: [productoId]);
    final nombre = p.isNotEmpty ? (p.first['nombre'] as String? ?? '') : '';
    final codigo = p.isNotEmpty ? (p.first['codigo'] as String? ?? '') : '';

    await db.insert('movimientos_stock', _withSyncMeta({
      'fecha': DateTime.now().toIso8601String(),
      'productoId': productoId,
      'tipo': tipo,
      'cantidad': cantidad,
      'nota': nota,
      'producto_nombre': nombre,
      'producto_codigo': codigo,
    }, forceDirty: false));
    notifyDbChange();
  }

  Future<List<Map<String, dynamic>>> getIngresosStock({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;

    String where = "m.tipo IN ('ingreso','alta_producto')";
    final args = <dynamic>[];

    if (desde != null && hasta != null) {
      where += " AND m.fecha BETWEEN ? AND ?";
      args.add(desde.toIso8601String());
      args.add(hasta.toIso8601String());
    }

    return await db.rawQuery('''
    SELECT 
      m.id            AS id,
      m.fecha         AS fecha,
      m.productoId    AS productoId,
      m.tipo          AS tipo,
      m.cantidad      AS cantidad,
      m.nota          AS nota,
      COALESCE(m.producto_nombre, p.nombre) AS producto,
      COALESCE(m.producto_codigo, p.codigo) AS codigo
    FROM movimientos_stock m
    LEFT JOIN productos p ON p.id = m.productoId
    WHERE $where
    ORDER BY m.fecha DESC
  ''', args);
  }

  Future<void> _migrateToHybridV14(Database db) async {
    final tables = [
      'categorias',
      'productos',
      'usuarios',
      'clientes',
      'ventas',
      'deudas',
      'movimientos_stock'
    ];

    for (final table in tables) {
      if (await _tableExists(db, table)) {
        if (!await _columnExists(db, table, 'firebase_id')) {
          await db.execute("ALTER TABLE $table ADD COLUMN firebase_id TEXT;");
        }
        if (!await _columnExists(db, table, 'last_updated')) {
          await db.execute("ALTER TABLE $table ADD COLUMN last_updated TEXT;");
        }
        if (!await _columnExists(db, table, 'synced')) {
          await db.execute("ALTER TABLE $table ADD COLUMN synced INTEGER DEFAULT 1;");
        }
        // Marcar registros locales existentes como sucios para sincronizarlos al loguearse en Firebase
        await db.execute("UPDATE $table SET synced = 0 WHERE firebase_id IS NULL;");
      }
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        firebase_id TEXT NOT NULL,
        deleted_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS config_sync (
        negocioId TEXT PRIMARY KEY,
        ownerEmail TEXT,
        last_sync_timestamp TEXT
      )
    ''');
  }

  Future<void> _migrateToV15(Database db) async {
    if (!await _columnExists(db, 'ventas', 'subtotal')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN subtotal REAL;');
    }
    if (!await _columnExists(db, 'ventas', 'descuento')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN descuento REAL;');
    }
  }

  Future<void> _migrateToV16(Database db) async {
    if (!await _columnExists(db, 'ventas', 'discountType')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN discountType TEXT;');
    }
    if (!await _columnExists(db, 'ventas', 'discountValue')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN discountValue REAL;');
    }
    if (!await _columnExists(db, 'ventas', 'discountAmount')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN discountAmount REAL;');
    }
  }

  // --- Métodos de Carrito Temporal (Windows only, no sync) ---
  Future<void> saveCarritoTemporal(String jsonStr) async {
    final db = await database;
    await db.insert(
      'carrito_temporal',
      {'id': 1, 'data': jsonStr},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCarritoTemporal() async {
    final db = await database;
    final maps = await db.query(
      'carrito_temporal',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (maps.isEmpty) return null;
    return maps.first['data'] as String?;
  }

  Future<void> clearCarritoTemporal() async {
    final db = await database;
    await db.delete(
      'carrito_temporal',
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
