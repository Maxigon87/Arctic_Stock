import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DBService _dbService = DBService();

  fb_auth.User? get currentUser => _auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String? get negocioId => currentUser?.uid;

  Stream<fb_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Iniciar sesión (Admin del negocio)
  Future<fb_auth.UserCredential> loginNegocio(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final db = await _dbService.database;
      await db.insert(
        'config_sync',
        {
          'negocioId': credential.user!.uid,
          'ownerEmail': credential.user!.email,
          'last_sync_timestamp': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      notifyListeners();
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Registrar un nuevo negocio/empresa
  Future<fb_auth.UserCredential> registerNegocio({
    required String email,
    required String password,
    required String nombreNegocio,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;

      // Crear documento del negocio en Firestore
      await _firestore.collection('negocios').doc(uid).set({
        'nombre': nombreNegocio.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Guardar localmente la configuración de sincronización
      final db = await _dbService.database;
      await db.insert(
        'config_sync',
        {
          'negocioId': uid,
          'ownerEmail': email.trim(),
          'last_sync_timestamp': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      notifyListeners();
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Obtener negocioId activo local
  Future<String?> getLocalNegocioId() async {
    try {
      final db = await _dbService.database;
      final res = await db.query('config_sync', limit: 1);
      if (res.isNotEmpty) {
        return res.first['negocioId'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // Cerrar Sesión
  Future<void> logout() async {
    try {
      await _auth.signOut();
      
      // Limpiar el usuario activo local (empleado)
      _dbService.setActiveUser(id: null, nombre: null);

      // Limpiar configuración de sincronización local
      final db = await _dbService.database;
      await db.delete('config_sync');

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
