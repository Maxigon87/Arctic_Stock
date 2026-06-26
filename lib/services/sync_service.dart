import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'db_service.dart';
import 'auth_service.dart';
import 'connectivity_helper.dart';

class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DBService _dbService = DBService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  StreamSubscription<void>? _dbListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  // Iniciar la sincronización basada en eventos y escuchar cambios locales/ciclo de vida
  void startPeriodicSync() async {
    // Escuchar cambios en la base de datos local con un debounce de 1 segundo
    _dbListener?.cancel();
    Timer? debounceTimer;
    _dbListener = _dbService.onDatabaseChanged.listen((_) {
      if (_isSyncing) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(seconds: 1), () {
        if (!_isSyncing) {
          syncData(force: false);
        }
      });
    });

    // Registrar observer para sincronizar cuando la app vuelva a primer plano (resumed)
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);

    // Iniciar temporizador de sincronización periódica cada 5 minutos
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing) {
        syncData(force: true);
      }
    });

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (!result.contains(ConnectivityResult.none)) {
        if (!_isSyncing) {
           syncData(force: true);
        }
      }
    });

    // Ejecutar sincronización inicial al arrancar el servicio (completa)
    await syncData(force: true);
  }

  // Detener la sincronización y el observer de ciclo de vida
  void stopPeriodicSync() {
    _dbListener?.cancel();
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _lastSyncTime = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App retomada en primer plano: Iniciando sincronización por ciclo de vida.");
      syncData(force: true);
    }
  }

  // Obtener conteo detallado de cambios locales pendientes
  Future<Map<String, int>> getPendingChangesCount() async {
    final db = await _dbService.database;
    final Map<String, int> counts = {};

    try {
      final deletesRes = await db.rawQuery('SELECT COUNT(*) FROM deleted_records');
      final deletes = deletesRes.isNotEmpty ? (deletesRes.first.values.first as int? ?? 0) : 0;
      if (deletes > 0) {
        counts['Eliminaciones'] = deletes;
      }
    } catch (_) {}

    final tables = {
      'categorias': 'Categorías',
      'usuarios': 'Usuarios',
      'clientes': 'Clientes',
      'productos': 'Productos',
      'ventas': 'Ventas',
      'deudas': 'Deudas',
      'movimientos_stock': 'Movimientos de Stock'
    };

    for (final entry in tables.entries) {
      try {
        final countRes = await db.rawQuery('SELECT COUNT(*) FROM ${entry.key} WHERE synced = 0');
        final count = countRes.isNotEmpty ? (countRes.first.values.first as int? ?? 0) : 0;
        if (count > 0) {
          counts[entry.value] = count;
        }
      } catch (_) {}
    }

    return counts;
  }

  // Ejecutar sincronización bidireccional completa
  Future<void> syncData({bool force = false}) async {
    if (_isSyncing) return;

    final hasInternet = await ConnectivityHelper.hasInternet();
    if (!hasInternet) {
      debugPrint("Sincronización cancelada: No hay conexión a internet. Trabajando offline.");
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final negocioId = _authService.negocioId ?? await _authService.getLocalNegocioId();
      if (negocioId == null) {
        debugPrint("Sincronización cancelada: No hay negocio autenticado.");
        _isSyncing = false;
        notifyListeners();
        return;
      }

      // Cargar la última fecha de sincronización de la base de datos si no está cargada en memoria
      if (_lastSyncTime == null) {
        try {
          final db = await _dbService.database;
          final config = await db.query('config_sync', where: 'negocioId = ?', whereArgs: [negocioId], limit: 1);
          if (config.isNotEmpty) {
            final ts = config.first['last_sync_timestamp'] as String?;
            if (ts != null && ts.isNotEmpty) {
              _lastSyncTime = DateTime.tryParse(ts);
            }
          }
        } catch (_) {}
      }

      // Obtener los cambios locales pendientes
      final pending = await getPendingChangesCount();

      // Si no existen cambios locales pendientes y no es forzada, no hacemos nada
      if (pending.isEmpty && !force) {
        _isSyncing = false;
        notifyListeners();
        return;
      }

      if (pending.isNotEmpty) {
        pending.forEach((key, value) {
          debugPrint("$key pendientes: $value");
        });
      }
      debugPrint("Iniciando sincronización...");

      // 1. Procesar eliminaciones locales (tombstones) hacia la nube
      await _syncDeletes(negocioId);

      // 2. Subir cambios locales (Push)
      await _syncPush(negocioId);

      // 3. Descargar cambios remotos (Pull)
      await _syncPull(negocioId);

      debugPrint("Sincronización finalizada.");
    } catch (e, stack) {
      debugPrint("Error durante la sincronización: $e");
      debugPrint(stack.toString());
    } finally {
      _isSyncing = false;
      _dbService.notifyDbChange();
      notifyListeners();
    }
  }

  // === 1. SUBIR ELIMINACIONES (Tombstones) ===
  Future<void> _syncDeletes(String negocioId) async {
    final db = await _dbService.database;
    final deletes = await db.query('deleted_records');

    for (final row in deletes) {
      final id = row['id'] as int;
      final tableName = row['table_name'] as String;
      final firebaseId = row['firebase_id'] as String;

      try {
        // Eliminar en Firestore
        await _firestore
            .collection('negocios')
            .doc(negocioId)
            .collection(tableName)
            .doc(firebaseId)
            .delete();

        // Eliminar tombstone local una vez subido con éxito
        await db.delete('deleted_records', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint("Error subiendo eliminación de $tableName ($firebaseId): $e");
      }
    }
  }

  // === 2. PUSH: SUBIR CAMBIOS LOCALES A FIRESTORE ===
  Future<void> _syncPush(String negocioId) async {
    final db = await _dbService.database;

    final tablesToPush = [
      'categorias',
      'usuarios',
      'clientes',
      'productos',
      'ventas',
      'deudas',
      'movimientos_stock'
    ];

    for (final table in tablesToPush) {
      final unsynced = await db.query(table, where: 'synced = 0');
      if (unsynced.isEmpty) continue;

      debugPrint("Subiendo ${unsynced.length} registros pendientes en la tabla: $table");

      for (final row in unsynced) {
        final localId = row['id'] as int;
        var firebaseId = row['firebase_id'] as String?;
        final data = Map<String, dynamic>.from(row);

        // Limpiar claves locales innecesarias para la nube
        data.remove('id');
        data.remove('synced');

        // Lógica específica para Ventas: desnormalizar/anidar items_venta
        if (table == 'ventas') {
          final items = await db.query('items_venta', where: 'ventaId = ?', whereArgs: [localId]);
          data['items'] = items.map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            itemMap.remove('id');
            itemMap.remove('ventaId');
            return itemMap;
          }).toList();
        }

        try {
          final collectionRef = _firestore
              .collection('negocios')
              .doc(negocioId)
              .collection(table);

          if (firebaseId == null || firebaseId.isEmpty) {
            // Crear documento nuevo en Firestore
            final docRef = await collectionRef.add(data);
            firebaseId = docRef.id;

            // Actualizar firebase_id localmente y marcar como sincronizado
            await db.update(
              table,
              {'firebase_id': firebaseId, 'synced': 1},
              where: 'id = ?',
              whereArgs: [localId],
            );
          } else {
            // Actualizar documento existente
            await collectionRef.doc(firebaseId).set(data, SetOptions(merge: true));
            await db.update(
              table,
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [localId],
            );
          }
        } catch (e) {
          debugPrint("Error subiendo registro $localId de la tabla $table: $e");
        }
      }
    }
  }

  // === 3. PULL: DESCARGAR CAMBIOS DE FIRESTORE ===
  Future<void> _syncPull(String negocioId) async {
    final db = await _dbService.database;

    // Obtener la fecha de última sincronización
    final config = await db.query('config_sync', where: 'negocioId = ?', whereArgs: [negocioId], limit: 1);
    String? lastSyncTime;
    if (config.isNotEmpty) {
      lastSyncTime = config.first['last_sync_timestamp'] as String?;
    }

    final nowTime = DateTime.now().toIso8601String();
    final tablesToPull = [
      'categorias',
      'usuarios',
      'clientes',
      'productos',
      'ventas',
      'deudas',
      'movimientos_stock'
    ];

    for (final table in tablesToPull) {
      var query = _firestore
          .collection('negocios')
          .doc(negocioId)
          .collection(table);

      QuerySnapshot snapshot;
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        // Restar 24 horas de margen de seguridad para evitar desfases de reloj y zonas horarias
        final parsed = DateTime.tryParse(lastSyncTime);
        final queryTime = parsed != null 
            ? parsed.subtract(const Duration(hours: 24)).toIso8601String() 
            : lastSyncTime;
        snapshot = await query.where('last_updated', isGreaterThan: queryTime).get();
      } else {
        // Primera sincronización: descargar todo
        snapshot = await query.get();
      }

      if (snapshot.docs.isEmpty) continue;
      debugPrint("Descargando ${snapshot.docs.length} registros nuevos/actualizados de: $table");

      for (final doc in snapshot.docs) {
        final remoteData = doc.data() as Map<String, dynamic>;
        final String docId = doc.id;

        // Buscar si existe localmente por firebase_id
        final localExist = await db.query(table, where: 'firebase_id = ?', whereArgs: [docId], limit: 1);

        if (localExist.isNotEmpty) {
          final localRow = localExist.first;
          final localLastUpdated = localRow['last_updated'] as String?;
          final remoteLastUpdated = remoteData['last_updated'] as String?;

          // Si el registro remoto es más nuevo y el local ya está sincronizado (no sucio)
          if (localRow['synced'] == 1 &&
              (localLastUpdated == null ||
                  remoteLastUpdated == null ||
                  remoteLastUpdated.compareTo(localLastUpdated) > 0)) {
            
            final updateMap = _mapRemoteToLocal(table, remoteData, docId);
            updateMap['synced'] = 1;

            if (table == 'ventas') {
              final localVentaId = localRow['id'] as int;
              await _updateLocalVentaAndItems(db, localVentaId, updateMap);
            } else {
              await db.update(table, updateMap, where: 'firebase_id = ?', whereArgs: [docId]);
              if (table == 'usuarios') {
                final localId = localRow['id'] as int;
                if (localId == _dbService.activeUserId) {
                  _dbService.setActiveUser(
                    id: localId,
                    nombre: updateMap['nombre'] as String?,
                    avatar: updateMap['avatar'] as String?,
                  );
                }
              }
            }
          }
        } else {
          // Registro nuevo localmente en base a firebase_id, pero verifiquemos conflictos UNIQUE
          bool conflictHandled = false;

          if (table == 'productos') {
            final String? remoteCodigo = remoteData['codigo']?.toString().trim();
            if (remoteCodigo != null && remoteCodigo.isNotEmpty) {
              final existing = await db.query('productos', where: 'codigo = ?', whereArgs: [remoteCodigo], limit: 1);
              if (existing.isNotEmpty) {
                final localRow = existing.first;
                final int localId = localRow['id'] as int;
                
                final updateMap = _mapRemoteToLocal(table, remoteData, docId);
                updateMap['synced'] = 1;
                
                await db.update('productos', updateMap, where: 'id = ?', whereArgs: [localId]);
                conflictHandled = true;
              }
            }
          } else if (table == 'categorias') {
            final String? remoteNombre = remoteData['nombre']?.toString().trim();
            if (remoteNombre != null && remoteNombre.isNotEmpty) {
              final existing = await db.query('categorias', where: 'LOWER(nombre) = ?', whereArgs: [remoteNombre.toLowerCase()], limit: 1);
              if (existing.isNotEmpty) {
                final localRow = existing.first;
                final int localId = localRow['id'] as int;
                
                final updateMap = _mapRemoteToLocal(table, remoteData, docId);
                updateMap['synced'] = 1;
                
                await db.update('categorias', updateMap, where: 'id = ?', whereArgs: [localId]);
                conflictHandled = true;
              }
            }
          } else if (table == 'usuarios') {
            final String? remoteNombre = remoteData['nombre']?.toString().trim();
            if (remoteNombre != null && remoteNombre.isNotEmpty) {
              final existing = await db.query('usuarios', where: 'LOWER(nombre) = ?', whereArgs: [remoteNombre.toLowerCase()], limit: 1);
              if (existing.isNotEmpty) {
                final localRow = existing.first;
                final int localId = localRow['id'] as int;
                
                final updateMap = _mapRemoteToLocal(table, remoteData, docId);
                updateMap['synced'] = 1;
                
                await db.update('usuarios', updateMap, where: 'id = ?', whereArgs: [localId]);
                conflictHandled = true;

                if (localId == _dbService.activeUserId) {
                  _dbService.setActiveUser(
                    id: localId,
                    nombre: updateMap['nombre'] as String?,
                    avatar: updateMap['avatar'] as String?,
                  );
                }
              }
            }
          } else if (table == 'clientes') {
            final String? remoteNombre = remoteData['nombre']?.toString().trim();
            if (remoteNombre != null && remoteNombre.isNotEmpty) {
              final existing = await db.query('clientes', where: 'LOWER(nombre) = ?', whereArgs: [remoteNombre.toLowerCase()], limit: 1);
              if (existing.isNotEmpty) {
                final localRow = existing.first;
                final int localId = localRow['id'] as int;
                
                final updateMap = _mapRemoteToLocal(table, remoteData, docId);
                updateMap['synced'] = 1;
                
                await db.update('clientes', updateMap, where: 'id = ?', whereArgs: [localId]);
                conflictHandled = true;
              }
            }
          }

          if (!conflictHandled) {
            // Registro nuevo localmente sin conflictos
            final insertMap = _mapRemoteToLocal(table, remoteData, docId);
            insertMap['synced'] = 1;

            if (table == 'ventas') {
              await _insertLocalVentaAndItems(db, insertMap);
            } else {
              final insertedId = await db.insert(table, insertMap);
              if (table == 'usuarios') {
                if (insertedId == _dbService.activeUserId || (insertMap['nombre'] == _dbService.activeUserName)) {
                  _dbService.setActiveUser(
                    id: insertedId,
                    nombre: insertMap['nombre'] as String?,
                    avatar: insertMap['avatar'] as String?,
                  );
                }
              }
            }
          }
        }
      }
    }

    // Actualizar la última fecha de sincronización
    await db.insert(
      'config_sync',
      {
        'negocioId': negocioId,
        'last_sync_timestamp': nowTime,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _lastSyncTime = DateTime.tryParse(nowTime);
    notifyListeners();
  }

  // Mapear campos remotos a campos locales SQLite
  Map<String, dynamic> _mapRemoteToLocal(String table, Map<String, dynamic> remote, String docId) {
    final local = Map<String, dynamic>.from(remote);
    local['firebase_id'] = docId;

    // Procesar campos específicos si es necesario
    if (table == 'ventas') {
      local.remove('items'); // Los items se manejan en tabla aparte
    }
    return local;
  }

  // Insertar Venta e Items asociados localmente
  Future<void> _insertLocalVentaAndItems(Database db, Map<String, dynamic> ventaMap) async {
    final itemsList = ventaMap.remove('items') as List<dynamic>?;
    
    // Insertar venta y obtener ID
    final ventaId = await db.insert('ventas', ventaMap);

    // Insertar ítems asociados
    if (itemsList != null) {
      for (final item in itemsList) {
        final itemMap = Map<String, dynamic>.from(item);
        itemMap['ventaId'] = ventaId;
        await db.insert('items_venta', itemMap);
      }
    }
  }

  // Actualizar Venta e Items asociados localmente
  Future<void> _updateLocalVentaAndItems(Database db, int localVentaId, Map<String, dynamic> ventaMap) async {
    final itemsList = ventaMap.remove('items') as List<dynamic>?;

    // Actualizar venta
    await db.update('ventas', ventaMap, where: 'id = ?', whereArgs: [localVentaId]);

    // Eliminar items anteriores e insertar los nuevos para refrescar la relación
    await db.delete('items_venta', where: 'ventaId = ?', whereArgs: [localVentaId]);

    if (itemsList != null) {
      for (final item in itemsList) {
        final itemMap = Map<String, dynamic>.from(item);
        itemMap['ventaId'] = localVentaId;
        await db.insert('items_venta', itemMap);
      }
    }
  }
}
