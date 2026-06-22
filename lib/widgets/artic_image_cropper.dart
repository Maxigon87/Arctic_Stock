import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

class ArticImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const ArticImageCropperDialog({super.key, required this.imageBytes});

  @override
  State<ArticImageCropperDialog> createState() => _ArticImageCropperDialogState();
}

class _ArticImageCropperDialogState extends State<ArticImageCropperDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  bool _processing = false;

  Future<void> _onCropPressed() async {
    setState(() => _processing = true);
    try {
      // Allow one frame to complete
      await Future.delayed(const Duration(milliseconds: 50));
      
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      
      final ui.Image capturedImage = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await capturedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      
      final bytes = byteData.buffer.asUint8List();
      
      // Resize to target 180x180 px for avatar
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 180,
        targetHeight: 180,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image resizedImage = fi.image;
      final ByteData? resizedByteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedByteData != null && mounted) {
        Navigator.pop(context, resizedByteData.buffer.asUint8List());
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error al recortar la imagen: $e");
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ajustar Foto de Perfil',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arrastra para mover, pellizca para hacer zoom',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: Container(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        width: 250,
                        height: 250,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          boundaryMargin: const EdgeInsets.all(150),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        size: const Size(250, 250),
                        painter: HolePainter(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_processing)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.manrope(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _onCropPressed,
                    child: Text(
                      'Aceptar',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class HolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 4,
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Cyan border around cut-out
    final borderPaint = Paint()
      ..color = const Color(0xFF22D3EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 4,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
