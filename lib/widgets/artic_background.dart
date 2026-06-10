import 'dart:math';
import 'package:flutter/material.dart';

class ArticBackground extends StatelessWidget {
  final Widget child;
  const ArticBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A), // Azul marino profundo
                  const Color(0xFF1E293B), // Gris glacial oscuro
                ]
              : [
                  const Color(0xFFEDF2F7), // Blanco glacial suave
                  const Color(0xFFCBD5E1), // Gris azulado suave
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: SnowParticlesWidget(),
          ),
          child, // Se mantiene intacto sin reconstruirse en cada cuadro de la animación
        ],
      ),
    );
  }
}

class _Snowflake {
  double x, y, radius, speed, drift;
  _Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
  });
}

class SnowParticlesWidget extends StatefulWidget {
  const SnowParticlesWidget({super.key});

  @override
  State<SnowParticlesWidget> createState() => _SnowParticlesWidgetState();
}

class _SnowParticlesWidgetState extends State<SnowParticlesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Snowflake> _flakes = [];
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _generateSnowflakes();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  void _generateSnowflakes() {
    for (int i = 0; i < 60; i++) {
      _flakes.add(_Snowflake(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        radius: 1.0 + _rand.nextDouble() * 2.2,
        speed: 0.0006 + _rand.nextDouble() * 0.0012,
        drift: -0.0003 + _rand.nextDouble() * 0.0006,
      ));
    }
  }

  void _updateFlakes() {
    for (var f in _flakes) {
      f.y += f.speed;
      f.x += f.drift + sin(f.y * 10) * 0.0004; // Viento suave lateral
      if (f.y > 1.05) {
        f.y = -0.05;
        f.x = _rand.nextDouble();
      }
      if (f.x > 1.0) f.x = 0.0;
      if (f.x < 0.0) f.x = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // RepaintBoundary aísla los repintados del CustomPaint del resto del árbol de widgets
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          _updateFlakes();
          return CustomPaint(
            painter: _SnowPainter(_flakes, isDark),
          );
        },
      ),
    );
  }
}

class _SnowPainter extends CustomPainter {
  final List<_Snowflake> flakes;
  final bool darkMode;
  _SnowPainter(this.flakes, this.darkMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = darkMode
          ? Colors.white.withOpacity(0.55)
          : Colors.white.withOpacity(0.85);

    for (var f in flakes) {
      canvas.drawCircle(
        Offset(f.x * size.width, f.y * size.height),
        f.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
