import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';



import '../widgets/artic_background.dart';

import '../services/db_service.dart'; // usuarios + setActiveUser

import '../widgets/articlogo.dart';

import '../services/auth_service.dart';

import '../services/sync_service.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../widgets/artic_dialog.dart';
import '../widgets/artic_image_cropper.dart';
import '../widgets/artic_sync_loader.dart';



class ArticLoginScreen extends StatefulWidget {

  const ArticLoginScreen({super.key});



  @override

  State<ArticLoginScreen> createState() => _ArticLoginScreenState();

}



class _ArticLoginScreenState extends State<ArticLoginScreen>

    with TickerProviderStateMixin {

  late AnimationController _titleController;

  late AnimationController _windController;

  late Animation<double> _scaleAnimation;

  late Animation<double> _opacityAnimation;

  bool showButton = false;



  final List<_WindParticle> _windParticles =

      List.generate(40, (_) => _WindParticle());



  // --- Sincronización y Empresa ---

  bool _isBusinessAuthenticated = false;

  bool _showRegisterForm = false;

  bool _authenticating = false;

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final _businessNameController = TextEditingController();



  // --- Usuarios ---

  List<Map<String, dynamic>> _usuarios = [];
  final Map<String, Uint8List> _avatarBytesCache = {};

  Uint8List? _getAvatarBytes(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    return _avatarBytesCache.putIfAbsent(base64Str, () => base64Decode(base64Str));
  }

  int? _selectedUserId;

  bool _loadingUsers = true;



  @override

  void initState() {

    super.initState();



    // Animación del título

    _titleController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 1500),

    );

    _scaleAnimation =

        CurvedAnimation(parent: _titleController, curve: Curves.elasticOut);

    _opacityAnimation =

        CurvedAnimation(parent: _titleController, curve: Curves.easeIn);



    _titleController.forward().whenComplete(() {

      Future.delayed(const Duration(milliseconds: 800), () {

        if (mounted) setState(() => showButton = true);

      });

    });



    // Animación viento

    _windController =

        AnimationController(vsync: this, duration: const Duration(seconds: 5))

          ..addListener(() {

            setState(() {

              for (var p in _windParticles) {

                p.x += p.speed;

                if (p.x > 1.2) p.reset();

              }

            });

          })

          ..repeat();



    _checkBusinessAuth();

  }



  Future<void> _checkBusinessAuth() async {

    final auth = AuthService();

    final localNegocioId = await auth.getLocalNegocioId();

    if (auth.isAuthenticated || localNegocioId != null) {

      setState(() {

        _isBusinessAuthenticated = true;

      });

      SyncService().startPeriodicSync();

      // Sincronización silenciosa inicial

      SyncService().syncData().then((_) {

        if (mounted) _loadUsuarios();

      });

    } else {

      setState(() {

        _isBusinessAuthenticated = false;

      });

    }

  }



  Future<void> _submitBusinessAuth() async {

    final email = _emailController.text.trim();

    final password = _passwordController.text.trim();

    final businessName = _businessNameController.text.trim();



    if (email.isEmpty || password.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Por favor completa todos los campos')),

      );

      return;

    }



    if (_showRegisterForm && businessName.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Por favor escribe el nombre de tu negocio')),

      );

      return;

    }



    setState(() => _authenticating = true);



    try {

      final auth = AuthService();

      if (_showRegisterForm) {

        await auth.registerNegocio(

          email: email,

          password: password,

          nombreNegocio: businessName,

        );

      } else {

        await auth.loginNegocio(email, password);

      }



      await SyncService().syncData();

      SyncService().startPeriodicSync();

      await _loadUsuarios();



      if (mounted) {

        setState(() {

          _isBusinessAuthenticated = true;

          _authenticating = false;

        });

      }

    } catch (e) {

      if (mounted) {

        setState(() => _authenticating = false);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Error de autenticación: $e')),

        );

      }

    }

  }



  Future<void> _logoutBusiness() async {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showArticDialog<bool>(

      context: context,

      builder: (ctx) => ArticDialogCard(

        title: 'Cerrar Sesión de Empresa',

        actions: [

          TextButton(

              onPressed: () => Navigator.pop(ctx, false),

              child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),

          TextButton(

              onPressed: () => Navigator.pop(ctx, true),

              child: const Text('Salir', style: TextStyle(color: Colors.red))),

        ],

        child: Text(

          '¿Estás seguro de que quieres cerrar la sesión de tu empresa? Se cerrará el acceso local en este dispositivo.',

          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),

        ),

      ),

    );



    if (ok == true) {

      setState(() => _loadingUsers = true);

      SyncService().stopPeriodicSync();

      await AuthService().logout();

      if (mounted) {

        setState(() {

          _isBusinessAuthenticated = false;

          _loadingUsers = false;

          _usuarios = [];

          _selectedUserId = null;

        });

      }

    }

  }



  Future<void> _loadUsuarios() async {

    final list = await DBService().getUsuarios();

    if (!mounted) return;

    setState(() {

      _usuarios = list;

      if (_selectedUserId == null && list.isNotEmpty) {

        _selectedUserId = list.first['id'] as int;

      } else if (_selectedUserId != null &&

          !list.any((u) => u['id'] == _selectedUserId)) {

        _selectedUserId = list.isNotEmpty ? list.first['id'] as int : null;

      }

      _loadingUsers = false;

    });

  }



  Future<void> _addUsuarioDialog() async {

    final controller = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? avatarBase64;

    final ok = await showArticDialog<bool>(

      context: context,

      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => ArticDialogCard(

          title: 'Nuevo usuario',

          actions: [

            TextButton(

                onPressed: () => Navigator.pop(ctx, false),

                child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),

            ElevatedButton(

                style: ElevatedButton.styleFrom(

                  backgroundColor: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),

                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,

                ),

                onPressed: () => Navigator.pop(ctx, true),

                child: const Text('Guardar')),

          ],

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (result == null) return;
                    final file = result.files.first;
                    Uint8List? bytes = file.bytes;
                    if (bytes == null && file.path != null) {
                      bytes = await File(file.path!).readAsBytes();
                    }
                    if (bytes == null) return;

                    final croppedBytes = await showDialog<Uint8List>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => ArticImageCropperDialog(imageBytes: bytes!),
                    );
                    if (croppedBytes != null) {
                      setDialogState(() {
                        avatarBase64 = base64Encode(croppedBytes);
                      });
                    }
                  } catch (_) {}
                },
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)).withOpacity(0.1),
                  backgroundImage: (avatarBase64 != null && avatarBase64!.isNotEmpty)
                      ? MemoryImage(base64Decode(avatarBase64!))
                      : null,
                  child: (avatarBase64 == null || avatarBase64!.isEmpty)
                      ? Icon(Icons.camera_alt, size: 28, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(

                controller: controller,

                autofocus: true,

                style: TextStyle(color: isDark ? Colors.white : Colors.black87),

                decoration: InputDecoration(

                  labelText: 'Nombre',

                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),

                ),

              ),
            ]
          ),

        ),
      ),

    );



    final name = controller.text.trim();

    if (ok == true && name.isNotEmpty) {

      try {

        final newId = await DBService().insertUsuario(name);

        if (!mounted) return;

        setState(() => _selectedUserId = newId); // seleccionar el nuevo

        await _loadUsuarios(); // refrescar lista

      } catch (e) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('No se pudo crear el usuario: $e')),

        );

      }

    }

  }



  Future<void> _acceder() async {

    if (_selectedUserId == null) return;

    final u = _usuarios.firstWhere((e) => e['id'] == _selectedUserId);

    DBService().setActiveUser(

      id: _selectedUserId,

      nombre: u['nombre'] as String?,

      avatar: u['avatar'] as String?,

    );



    if (!mounted) return;

    // Navega por ruta nombrada (definida en MaterialApp.routes)

    Navigator.pushReplacementNamed(context, '/home');

  }



  @override

  void dispose() {

    _titleController.dispose();

    _windController.dispose();

    _emailController.dispose();

    _passwordController.dispose();

    _businessNameController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      body: ArticBackground(

        child: Stack(

          children: [

            CustomPaint(

                size: Size.infinite, painter: _WindPainter(_windParticles)),

            Center(

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  ScaleTransition(

                    scale: _scaleAnimation,

                    child: FadeTransition(

                      opacity: _opacityAnimation,

                      child: ScaleTransition(

                        scale: _scaleAnimation,

                        child: FadeTransition(

                          opacity: _opacityAnimation,

                          child: const ArticLogo(size: 240),

                        ),

                      ),

                    ),

                  ),

                  const SizedBox(height: 32),



                  // Panel login card

                  AnimatedOpacity(

                    opacity: showButton ? 1 : 0,

                    duration: const Duration(milliseconds: 800),

                    child: showButton

                        ? ConstrainedBox(

                            constraints: const BoxConstraints(maxWidth: 520),

                            child: ClipRRect(

                              borderRadius: BorderRadius.circular(18),

                              child: Container(

                                padding: const EdgeInsets.all(20),

                                decoration: BoxDecoration(

                                  color: Theme.of(context).cardColor,

                                  border: Border.all(

                                    color:

                                        Theme.of(context).colorScheme.outline,

                                  ),

                                  boxShadow: const [

                                    BoxShadow(

                                      color: Colors.black26,

                                      blurRadius: 16,

                                      offset: Offset(0, 8),

                                    ),

                                  ],

                                ),

                                child: _isBusinessAuthenticated

                                    ? Column(

                                        mainAxisSize: MainAxisSize.min,

                                        crossAxisAlignment:

                                            CrossAxisAlignment.stretch,

                                        children: [

                                          Text('Usuario (Empleado)',

                                              style: Theme.of(context)

                                                  .textTheme

                                                  .titleMedium

                                                  ?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),

                                          const SizedBox(height: 8),

                                          Row(

                                            children: [

                                              Expanded(

                                                child: _loadingUsers

                                                    ? const LinearProgressIndicator(

                                                        minHeight: 48)

                                                    : DropdownButtonFormField<int>(

                                                        value: (_usuarios.isNotEmpty)

                                                            ? _selectedUserId

                                                            : null,

                                                        dropdownColor: Theme.of(context).brightness == Brightness.dark

                                                            ? const Color(0xFF1E293B)

                                                            : Colors.white,

                                                        style: TextStyle(

                                                          color: Theme.of(context).brightness == Brightness.dark

                                                              ? Colors.white

                                                              : Colors.black87,

                                                        ),

                                                        items: _usuarios.map((u) {
                                                          final avatarBase64 = u['avatar'] as String?;
                                                          final avatarBytes = _getAvatarBytes(avatarBase64);
                                                          return DropdownMenuItem<int>(

                                                            value: u['id'] as int,

                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                CircleAvatar(
                                                                  radius: 12,
                                                                  backgroundColor: Colors.transparent,
                                                                  backgroundImage: avatarBytes != null
                                                                      ? MemoryImage(avatarBytes)
                                                                      : null,
                                                                  child: avatarBytes == null
                                                                      ? Icon(
                                                                          Icons.person,
                                                                          size: 16,
                                                                          color: Theme.of(context).brightness == Brightness.dark
                                                                              ? Colors.white70
                                                                              : Colors.black54,
                                                                        )
                                                                      : null,
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Text(

                                                                  u['nombre'] as String,

                                                                  style: TextStyle(

                                                                    color: Theme.of(context).brightness == Brightness.dark

                                                                        ? Colors.white

                                                                        : Colors.black87,

                                                                  ),

                                                                ),
                                                              ],
                                                            ),

                                                          );

                                                        }).toList(),

                                                        onChanged: _usuarios

                                                                .isNotEmpty

                                                            ? (v) => setState(() =>

                                                                _selectedUserId = v)

                                                            : null,

                                                        decoration:

                                                            const InputDecoration(

                                                          hintText:

                                                              'No hay usuarios. Agregá uno',

                                                          border:

                                                              OutlineInputBorder(),

                                                        ),

                                                      ),

                                              ),

                                              const SizedBox(width: 8),

                                              IconButton(

                                                tooltip: 'Agregar usuario',

                                                icon: const Text(

                                                  "➕",

                                                  style: TextStyle(fontSize: 22),

                                                ),

                                                onPressed: _addUsuarioDialog,

                                                padding: EdgeInsets.zero,

                                                constraints: const BoxConstraints(),

                                              ),

                                            ],

                                          ),

                                          const SizedBox(height: 16),

                                          FilledButton(

                                            onPressed: (_usuarios.isNotEmpty &&

                                                    _selectedUserId != null)

                                                ? _acceder

                                                : null,

                                            child: const Text('Acceder'),

                                          ),

                                          const SizedBox(height: 12),

                                          TextButton.icon(

                                            onPressed: _logoutBusiness,

                                            icon: const Icon(Icons.logout, size: 16),

                                            label: const Text('Salir de la Empresa'),

                                            style: TextButton.styleFrom(

                                              foregroundColor: Colors.redAccent,

                                            ),

                                          ),

                                        ],

                                      )

                                    : _buildBusinessAuthForm(),

                              ),

                            ),

                          )

                        : const SizedBox.shrink(),

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildBusinessAuthForm() {

    return Column(

      mainAxisSize: MainAxisSize.min,

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Text(

          _showRegisterForm ? 'Crear Cuenta de Negocio' : 'Iniciar Sesión (Negocio)',

          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),

          textAlign: TextAlign.center,

        ),

        const SizedBox(height: 16),

        if (_showRegisterForm) ...[

          TextField(

            controller: _businessNameController,

            style: TextStyle(

              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,

            ),

            decoration: InputDecoration(

              labelText: 'Nombre del Negocio',

              labelStyle: TextStyle(

                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,

              ),

              prefixIcon: Icon(

                Icons.business,

                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,

              ),

              border: const OutlineInputBorder(),

              enabledBorder: OutlineInputBorder(

                borderSide: BorderSide(

                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,

                ),

              ),

            ),

          ),

          const SizedBox(height: 12),

        ],

        TextField(

          controller: _emailController,

          keyboardType: TextInputType.emailAddress,

          style: TextStyle(

            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,

          ),

          decoration: InputDecoration(

            labelText: 'Correo Electrónico',

            labelStyle: TextStyle(

              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,

            ),

            prefixIcon: Icon(

              Icons.email,

              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,

            ),

            border: const OutlineInputBorder(),

            enabledBorder: OutlineInputBorder(

              borderSide: BorderSide(

                color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,

              ),

            ),

          ),

        ),

        const SizedBox(height: 12),

        TextField(

          controller: _passwordController,

          obscureText: true,

          style: TextStyle(

            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,

          ),

          decoration: InputDecoration(

            labelText: 'Contraseña',

            labelStyle: TextStyle(

              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,

            ),

            prefixIcon: Icon(

              Icons.lock,

              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,

            ),

            border: const OutlineInputBorder(),

            enabledBorder: OutlineInputBorder(

              borderSide: BorderSide(

                color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,

              ),

            ),

          ),

        ),

        const SizedBox(height: 20),

        if (_authenticating)

          const Center(child: Padding(

            padding: EdgeInsets.all(8.0),

            child: CircularProgressIndicator(),

          ))

        else ...[

          FilledButton(

            onPressed: _submitBusinessAuth,

            child: Text(_showRegisterForm ? 'Registrar Negocio' : 'Ingresar al Negocio'),

          ),

          const SizedBox(height: 8),

          TextButton(

            onPressed: () {

              setState(() {

                _showRegisterForm = !_showRegisterForm;

              });

            },

            child: Text(_showRegisterForm

                ? '¿Ya tienes una cuenta? Inicia Sesión'

                : '¿No tienes cuenta? Registra tu Negocio'),

          ),

        ],

      ],

    );

  }

}



// 🌬️ Modelo de partícula viento

class _WindParticle {

  double x, y, speed, size;

  _WindParticle()

      : x = Random().nextDouble(),

        y = Random().nextDouble(),

        speed = 0.003 + Random().nextDouble() * 0.004,

        size = 1 + Random().nextDouble() * 2;

  void reset() {

    x = -0.1;

    y = Random().nextDouble();

    speed = 0.003 + Random().nextDouble() * 0.004;

    size = 1 + Random().nextDouble() * 2;

  }

}



// 🎨 Pintor de viento

class _WindPainter extends CustomPainter {

  final List<_WindParticle> particles;

  _WindPainter(this.particles);



  @override

  void paint(Canvas canvas, Size size) {

    final paint = Paint()..color = Colors.white.withOpacity(0.15);

    for (var p in particles) {

      canvas.drawCircle(

        Offset(p.x * size.width, p.y * size.height),

        p.size,

        paint,

      );

    }

  }



  @override

  bool shouldRepaint(CustomPainter oldDelegate) => true;

}
