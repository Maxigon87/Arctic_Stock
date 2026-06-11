import 'package:flutter/material.dart';

class ArticLogo extends StatelessWidget {
  final double size;
  const ArticLogo({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = !identical(0, 0.0) && (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS);

    final String imagePath = isMobile
        ? 'assets/logo/logo_sin_titulo.png'
        : (isDark ? 'assets/images/artic_logo.png' : 'assets/logo/logo_con_titulo.png');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.asset(
        imagePath,
        key: ValueKey(imagePath),
        width: size,
        height: size,
      ),
    );
  }
}
