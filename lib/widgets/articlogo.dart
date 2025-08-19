import 'package:flutter/material.dart';

class ArticLogo extends StatelessWidget {
  final double size;
  const ArticLogo({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.asset(
        isDark
            ? 'assets/imges/artic_logo.png'
            : 'assets/logo/logo_con_titulo.png',
        key: ValueKey(isDark),
        width: size,
        height: size,
      ),
    );
  }
}
