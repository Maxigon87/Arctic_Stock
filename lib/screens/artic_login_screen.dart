import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../widgets/artic_background.dart';
import '../Services/db_service.dart'; // usuarios + setActiveUser

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

  // --- Usuarios ---
  List<Map<String, dynamic>> _usuarios = [];
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

    _loadUsuarios();
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo usuario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
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
    DBService()
        .setActiveUser(id: _selectedUserId, nombre: u['nombre'] as String?);

    if (!mounted) return;
    // Navega por ruta nombrada (definida en MaterialApp.routes)
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _windController.dispose();
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
                      child: Image.asset(
                        'assets/images/artic_logo.png',
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Panel frosted glass
                  AnimatedOpacity(
                    opacity: showButton ? 1 : 0,
                    duration: const Duration(milliseconds: 800),
                    child: showButton
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.15)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text('Usuario',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _loadingUsers
                                                ? const LinearProgressIndicator(
                                                    minHeight: 48)
                                                : DropdownButtonFormField<int>(
                                                    initialValue:
                                                        (_usuarios.isNotEmpty)
                                                            ? _selectedUserId
                                                            : null,
                                                    items: _usuarios.map((u) {
                                                      return DropdownMenuItem<
                                                          int>(
                                                        value: u['id'] as int,
                                                        child: Text(u['nombre']
                                                            as String),
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
                                          IconButton.outlined(
                                            tooltip: 'Agregar usuario',
                                            icon: const Icon(
                                                Icons.person_add_alt_1),
                                            onPressed: _addUsuarioDialog,
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
                                    ],
                                  ),
                                ),
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
