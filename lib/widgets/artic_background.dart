import 'dart:math';
import 'package:flutter/material.dart';

class ArticBackground extends StatefulWidget {
  final Widget child;
  const ArticBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<ArticBackground> createState() => _ArticBackgroundState();
}

class _Snowflake {
  double x, y, radius, speed;
  _Snowflake(
      {required this.x,
      required this.y,
      required this.radius,
      required this.speed});
}

class _ArticBackgroundState extends State<ArticBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Snowflake> _flakes = [];
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _generateSnowflakes();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..addListener(() {
            _updateFlakes();
          })
          ..repeat();
  }

  void _generateSnowflakes() {
    for (int i = 0; i < 80; i++) {
      _flakes.add(_Snowflake(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        radius: 1 + _rand.nextDouble() * 2,
        speed: 0.0005 + _rand.nextDouble() * 0.0015,
      ));
    }
  }

  void _updateFlakes() {
    for (var f in _flakes) {
      f.y += f.speed;
      f.x += sin(f.y * 10) * 0.0005; // 🔥 viento lateral
      if (f.y > 1.2) f.y = -0.05;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0B0E26),
                  const Color(0xFF1A2340)
                ] // noche ártica
              : [
                  const Color(0xFFE6F7FF),
                  const Color(0xFFB3E5FC)
                ], // día helado
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
              size: Size.infinite, painter: _SnowPainter(_flakes, isDark)),
          widget.child, // 🔥 contenido encima del fondo
        ],
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
    final paint = Paint()..style = PaintingStyle.fill;
    for (var f in flakes) {
      paint.color = darkMode
          ? Colors.white.withOpacity(0.7)
          : Colors.white.withOpacity(0.9);
      canvas.drawCircle(
          Offset(f.x * size.width, f.y * size.height), f.radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
