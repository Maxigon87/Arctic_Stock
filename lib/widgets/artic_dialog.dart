import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class SnowParticle {
  double x; // normalized 0..1
  double y; // pixels from top
  double size;
  double speed;
  double opacity;
  double drift;

  SnowParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });
}

class SnowPainter extends CustomPainter {
  final List<SnowParticle> particles;
  SnowPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var p in particles) {
      if (p.opacity <= 0 || p.y < 0) continue;
      paint.color = Colors.white.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SnowFallEffect extends StatefulWidget {
  final Widget child;
  const SnowFallEffect({super.key, required this.child});

  @override
  State<SnowFallEffect> createState() => _SnowFallEffectState();
}

class _SnowFallEffectState extends State<SnowFallEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<SnowParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Spawn 15-20 particles from the bottom of the card
    for (int i = 0; i < 20; i++) {
      _particles.add(
        SnowParticle(
          x: _random.nextDouble(),
          // start below the visible area (approx. 120‑150 pixels down)
          y: 120.0 + _random.nextDouble() * 30.0,
          size: _random.nextDouble() * 2.5 + 1.5, // size between 1.5 and 4
          speed: _random.nextDouble() * 80.0 + 60.0, // speed
          opacity: _random.nextDouble() * 0.7 + 0.3, // starting opacity
          drift: (_random.nextDouble() - 0.5) * 1.2, // horizontal drift
        ),
      );
    }

    _controller.addListener(() {
      if (!mounted) return;
      setState(() {
        for (var p in _particles) {
          // Move particles upward (decrease y)
          p.y -= p.speed * 0.016; // approximate time delta
          p.x += p.drift * 0.01;
          // Fade out as they rise above the top edge
          if (p.y < 0) {
            p.opacity = max(0.0, p.opacity - 0.015);
          }
        }
      });
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SnowPainter(_particles),
      child: widget.child,
    );
  }
}

class ArticDialogCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final double? maxWidth;

  const ArticDialogCard({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SnowFallEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: isDark ? Colors.white60 : Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: child,
                    ),
                  ),
                  if (actions != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showArticDialog<T>({
  required BuildContext context,
  required Widget builder(BuildContext context),
  double maxWidth = 500,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: curve,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
  );
}
