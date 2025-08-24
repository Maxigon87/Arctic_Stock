import 'package:flutter/material.dart';

class ArticKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final IconData? icon; // ✅ nuevo parámetro opcional

  const ArticKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.accentColor,
    this.icon, // ✅ inicializado aquí
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          if (icon != null) // ✅ solo muestra si se pasa
            Icon(icon, size: 32, color: accentColor),
          if (icon != null) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accentColor)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
