import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/artic_background.dart';
import '../main.dart';

class ArticLoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme; // ✅ agregamos este parámetro

  const ArticLoginScreen({Key? key, required this.onToggleTheme})
      : super(key: key);

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

  @override
  void initState() {
    super.initState();

    // 🎬 Animación del título
    _titleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation =
        CurvedAnimation(parent: _titleController, curve: Curves.elasticOut);
    _opacityAnimation =
        CurvedAnimation(parent: _titleController, curve: Curves.easeIn);
    _titleController.forward().whenComplete(() {
      // luego de mostrar el título, mostrar viento
      Future.delayed(const Duration(milliseconds: 800), () {
        setState(() => showButton = true);
      });
    });

    // 🌬️ Animación viento
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
            // 🌬️ Viento animado
            CustomPaint(
                size: Size.infinite, painter: _WindPainter(_windParticles)),

            // ❄️ Contenido
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
                          child: Image.asset(
                            'assets/images/artic_logo.png',
                            height: 120, // ajusta tamaño
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 🔥 Botón con fade in después del viento
                  AnimatedOpacity(
                    opacity: showButton ? 1 : 0,
                    duration: const Duration(milliseconds: 800),
                    child: showButton
                        ? GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HomeScreen(
                                      onToggleTheme: widget.onToggleTheme),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFE0F7FA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: Colors.white70, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.cyanAccent.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: Offset(0, 4)),
                                ],
                              ),
                              child: Text(
                                "Acceder",
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  shadows: [
                                    Shadow(
                                        color: Colors.white.withOpacity(0.6),
                                        blurRadius: 2)
                                  ],
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
          Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
