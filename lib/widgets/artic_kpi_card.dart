import 'package:flutter/material.dart';
import 'dart:math';

class ArticKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final Color accentColor;

  const ArticKpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.accentColor,
  }) : super(key: key);

  @override
  State<ArticKpiCard> createState() => _ArticKpiCardState();
}

class _ArticKpiCardState extends State<ArticKpiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 80,
      child: Stack(
        children: [
          // Fondo hielo
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFE6F7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          // Brillo animado
          AnimatedBuilder(
            animation: _shineController,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.6),
                      Colors.white.withOpacity(0.0),
                    ],
                    stops: const [0.2, 0.5, 0.8],
                    begin: Alignment(-1.0 + 2.0 * _shineController.value, 0),
                    end: Alignment(1.0 + 2.0 * _shineController.value, 0),
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.transparent, width: 2),
                  ),
                ),
              );
            },
          ),

          // Contenido
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Colors.white.withOpacity(0.6), blurRadius: 2)
                      ],
                    )),
                Text(widget.value,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Colors.white.withOpacity(0.7), blurRadius: 3)
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
