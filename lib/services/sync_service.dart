import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_service.dart';
import 'auth_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DBService _dbService = DBService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Timer? _syncTimer;
  StreamSubscription<void>? _dbListener;

  // Iniciar la sincronización periódica (cada 2 minutos) y escuchar cambios locales
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      syncData();
    });

    // Escuchar cambios en la base de datos local con un debounce de 3 segundos para evitar sobrecarga
    _dbListener?.cancel();
    Timer? debounceTimer;
    _dbListener = _dbService.onDatabaseChanged.listen((_) {
      if (_isSyncing) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(seconds: 3), () {
        if (!_isSyncing) {
          syncData();
        }
      });
    });
  }

  // Detener la sincronización periódica y el escucha
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _dbListener?.cancel();
  }

  // Ejecutar sincronización bidireccional completa
  Future<void> syncData() async {
    if (_isSyncing) return;

    final negocioId = _authService.negocioId ?? await _authService.getLocalNegocioId();
    if (negocioId == null) {
      debugPrint("Sincronización cancelada: No hay negocio autenticado.");
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint("Iniciando sincronización para el negocio: $negocioId");

      // 1. Procesar eliminaciones locales (tombstones) hacia la nube
      await _syncDeletes(negocioId);

      // 2. Subir cambios locales (Push)
      await _syncPush(negocioId);

      // 3. Descargar cambios remotos (Pull)
      await _syncPull(negocioId);

      debugPrint("Sincronización finalizada con éxito.");
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
        // Traer solo los modificados después de la última sincronización
        snapshot = await query.where('last_updated', isGreaterThan: lastSyncTime).get();
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
            }
          }
        } else {
          // Registro nuevo localmente
          final insertMap = _mapRemoteToLocal(table, remoteData, docId);
          insertMap['synced'] = 1;

          if (table == 'ventas') {
            await _insertLocalVentaAndItems(db, insertMap);
          } else {
            await db.insert(table, insertMap);
          }
        }
      }
    }

    // Actualizar la última fecha de sincronización
    await db.update(
      'config_sync',
      {'last_sync_timestamp': nowTime},
      where: 'negocioId = ?',
      whereArgs: [negocioId],
    );
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
