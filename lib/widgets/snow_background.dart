import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/theme_controller.dart';

class Snowflake {
  double x;
  double y;
  double radius;
  double density;

  Snowflake({required this.x, required this.y, required this.radius, required this.density});
}

class SnowBackground extends StatefulWidget {
  final Widget child;
  const SnowBackground({super.key, required this.child});

  @override
  State<SnowBackground> createState() => _SnowBackgroundState();
}

class _SnowBackgroundState extends State<SnowBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Snowflake> _snowflakes = [];
  final Random _random = Random();
  final int _numberOfSnowflakes = 15; // Kept low for premium performance and subtlety

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_snowflakes.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < _numberOfSnowflakes; i++) {
        _snowflakes.add(Snowflake(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          radius: _random.nextDouble() * 2 + 1.0, // Small, subtle flakes
          density: _random.nextDouble() * 0.5 + 0.2,
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.performanceMode,
      builder: (context, isPerformanceMode, _) {
        if (isPerformanceMode) {
          return widget.child;
        }
        return Stack(
          children: [
            widget.child,
            IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    _updateSnow();
                    return CustomPaint(
                      painter: SnowPainter(snowflakes: _snowflakes),
                      child: Container(),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateSnow() {
    if (_snowflakes.isEmpty) return;
    final size = MediaQuery.of(context).size;
    for (var flake in _snowflakes) {
      // Fall down
      flake.y += flake.density * 0.8;
      // Slight sway
      flake.x += sin(flake.y / 30) * 0.2;

      // Reset when going off screen
      if (flake.y > size.height) {
        flake.y = -10;
        flake.x = _random.nextDouble() * size.width;
      }
    }
  }
}

class SnowPainter extends CustomPainter {
  final List<Snowflake> snowflakes;
  SnowPainter({required this.snowflakes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    for (var flake in snowflakes) {
      canvas.drawCircle(Offset(flake.x, flake.y), flake.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowPainter oldDelegate) => true;
}
