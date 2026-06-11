import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';
import '../../../services/sync_service.dart';
import '../../../widgets/articlogo.dart';
import '../../widgets/snow_background.dart';

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  final _authService = AuthService();
  final _dbService = DBService();

  bool _isBusinessAuthenticated = false;
  bool _showRegisterForm = false;
  bool _loading = false;

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();

  // Employee Selection
  List<Map<String, dynamic>> _employees = [];
  int? _selectedEmployeeId;
  bool _loadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _businessNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final negocioId = await _authService.getLocalNegocioId();
    if (negocioId != null || _authService.isAuthenticated) {
      setState(() {
        _isBusinessAuthenticated = true;
      });
      // Start background sync
      SyncService().startPeriodicSync();
      _loadEmployees();
    } else {
      setState(() {
        _isBusinessAuthenticated = false;
        _loadingEmployees = false;
      });
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final list = await _dbService.getUsuarios();
      setState(() {
        _employees = list;
        if (list.isNotEmpty) {
          _selectedEmployeeId = list.first['id'] as int;
        }
        _loadingEmployees = false;
      });
    } catch (_) {
      setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _submitBusinessAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final bizName = _businessNameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Por favor completa todos los campos');
      return;
    }

    if (_showRegisterForm && bizName.isEmpty) {
      _showSnackbar('Por favor escribe el nombre de tu negocio');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_showRegisterForm) {
        await _authService.registerNegocio(
          email: email,
          password: password,
          nombreNegocio: bizName,
        );
      } else {
        await _authService.loginNegocio(email, password);
      }

      await SyncService().syncData();
      SyncService().startPeriodicSync();
      await _loadEmployees();

      setState(() {
        _isBusinessAuthenticated = true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnackbar('Error de autenticación: $e');
    }
  }

  Future<void> _logoutBusiness() async {
    setState(() => _loading = true);
    try {
      SyncService().stopPeriodicSync();
      await _authService.logout();
      setState(() {
        _isBusinessAuthenticated = false;
        _employees = [];
        _selectedEmployeeId = null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnackbar('Error al cerrar sesión: $e');
    }
  }

  Future<void> _addEmployee() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nuevo Empleado', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del Empleado',
            hintText: 'Ej. Juan Pérez',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final newId = await _dbService.insertUsuario(name);
        await _loadEmployees();
        setState(() {
          _selectedEmployeeId = newId;
        });
      } catch (e) {
        _showSnackbar('Error al agregar empleado: $e');
      }
    }
  }

  void _loginEmployee() {
    if (_selectedEmployeeId == null) return;
    final emp = _employees.firstWhere((e) => e['id'] == _selectedEmployeeId);
    _dbService.setActiveUser(
      id: _selectedEmployeeId,
      nombre: emp['nombre'] as String?,
      avatar: emp['avatar'] as String?,
    );

    Navigator.pushReplacementNamed(context, '/mobile_home');
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SnowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? size.width * 0.2 : 24,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: ArticLogo(size: 160),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ARCTIC STOCK',
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Gestión Comercial Mobile',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isBusinessAuthenticated
                        ? _buildEmployeeSelectionCard()
                        : _buildBusinessAuthCard(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessAuthCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      key: const ValueKey('business_auth'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _showRegisterForm ? 'Crear cuenta de negocio' : 'Iniciar sesión (Negocio)',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_showRegisterForm) ...[
            TextField(
              controller: _businessNameCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre del Negocio',
                prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF64748B)),
                labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
              labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF64748B)),
              labelStyle: GoogleFonts.manrope(color: const Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitBusinessAuth,
                  child: Text(
                    _showRegisterForm ? 'Registrar Negocio' : 'Ingresar al Negocio',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _showRegisterForm = !_showRegisterForm;
              });
            },
            child: Text(
              _showRegisterForm
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿No tienes cuenta? Registra tu negocio',
              style: GoogleFonts.manrope(color: const Color(0xFF0EA5E9), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelectionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      key: const ValueKey('employee_selection'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selecciona tu Usuario',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_loadingEmployees)
            const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          else ...[
            if (_employees.isEmpty) ...[
              Text(
                'No hay usuarios de empleado creados. Registra el primero para ingresar.',
                style: GoogleFonts.manrope(color: const Color(0xFF64748B), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ] else ...[
              DropdownButtonFormField<int>(
                value: _selectedEmployeeId,
                items: _employees.map((e) {
                  return DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(
                      e['nombre'] as String,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedEmployeeId = val;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Empleado',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF0EA5E9)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add_outlined, color: Color(0xFF0EA5E9)),
              label: Text(
                'Crear Usuario Empleado',
                style: GoogleFonts.manrope(color: const Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
              ),
              onPressed: _addEmployee,
            ),
            const SizedBox(height: 24),
            _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _employees.isNotEmpty ? _loginEmployee : null,
                    child: Text(
                      'Acceder',
                      style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.logout_outlined, size: 18),
              label: Text(
                'Cerrar sesión de negocio',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              onPressed: _logoutBusiness,
            ),
          ],
        ],
      ),
    );
  }
}
