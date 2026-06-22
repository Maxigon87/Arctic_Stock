import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ArticBarcodeScanner extends StatefulWidget {
  final String title;
  const ArticBarcodeScanner({super.key, this.title = 'Escanear Código de Barras'});

  @override
  State<ArticBarcodeScanner> createState() => _ArticBarcodeScannerState();
}

class _ArticBarcodeScannerState extends State<ArticBarcodeScanner> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  PermissionStatus _cameraPermissionStatus = PermissionStatus.denied;
  bool _checkingPermission = true;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _cameraPermissionStatus = status;
        _checkingPermission = false;
      });
    } else {
      final requestStatus = await Permission.camera.request();
      setState(() {
        _cameraPermissionStatus = requestStatus;
        _checkingPermission = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  case TorchState.unavailable:
                  case TorchState.auto:
                    return const Icon(Icons.flash_off, color: Colors.white54);
                }
              },
            ),
            iconSize: 22,
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flip_camera_ios),
            iconSize: 22,
            onPressed: () => _controller.switchCamera(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _checkingPermission
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : _cameraPermissionStatus.isGranted
              ? Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        if (_hasScanned) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final codeValue = barcodes.first.rawValue;
                          if (codeValue != null && codeValue.isNotEmpty) {
                            setState(() => _hasScanned = true);
                            Navigator.pop(context, codeValue);
                          }
                        }
                      },
                    ),
                    // Beautiful Custom Scanner Overlay
                    const _ScannerOverlay(),
                  ],
                )
              : _buildPermissionDeniedView(),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              'Permiso de Cámara Denegado',
              style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Para poder escanear códigos de barras con la cámara de tu celular, debes conceder el permiso en la configuración de la aplicación.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await openAppSettings();
                _checkPermission();
              },
              child: Text('Abrir Configuración', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final scanAreaSize = width * 0.7;

      return Stack(
        children: [
          // Background Dim layer with cut-out
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                ),
                Center(
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize * 0.65,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Frame Corners overlay
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize * 0.65,
              child: Stack(
                children: [
                  // Corner brackets
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildCorner(top: true, left: true),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildCorner(top: true, left: false),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _buildCorner(top: false, left: true),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildCorner(top: false, left: false),
                  ),
                  // Instruction inside scan area
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: Text(
                        'Alinea el código de barras aquí',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Animated red scanner line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: _ScanningLine(width: scanAreaSize),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCorner({required bool top, required bool left}) {
    const double size = 20;
    const double stroke = 4;
    const Color color = Color(0xFF0EA5E9);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: top ? 0 : null,
            bottom: top ? null : 0,
            left: left ? 0 : null,
            right: left ? null : 0,
            child: Container(
              width: size,
              height: stroke,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            top: top ? 0 : null,
            bottom: top ? null : 0,
            left: left ? 0 : null,
            right: left ? null : 0,
            child: Container(
              width: stroke,
              height: size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanningLine extends StatefulWidget {
  final double width;
  const _ScanningLine({required this.width});

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -50, end: 50).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: widget.width - 8,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
