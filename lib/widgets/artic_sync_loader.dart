import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArticSyncLoader extends StatefulWidget {
  final double size;
  const ArticSyncLoader({super.key, this.size = 40.0});

  @override
  State<ArticSyncLoader> createState() => _ArticSyncLoaderState();
}

class _ArticSyncLoaderState extends State<ArticSyncLoader> {
  int _currentMessageIndex = 0;
  Timer? _timer;

  final List<String> _arcticMessages = [
    "Cargando base congelada...",
    "Analizando datos fríos...",
    "Sincronizando ventisqueros...",
    "Descongelando registros...",
    "Recuperando témpanos de datos...",
    "Explorando la tundra de red...",
    "Asegurando el iglú de almacenamiento...",
    "Enfriando los motores de búsqueda...",
    "Extrayendo del glaciar principal...",
    "Rompiendo el hielo del servidor...",
    "Cargando auroras de sincronización...",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _arcticMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black54;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _arcticMessages[_currentMessageIndex],
            key: ValueKey<String>(_arcticMessages[_currentMessageIndex]),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
