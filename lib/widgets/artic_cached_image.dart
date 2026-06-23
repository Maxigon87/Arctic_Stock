import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ArticCachedImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final bool hasShadow;
  final Widget? placeholder;

  const ArticCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.hasShadow = false,
    this.placeholder,
  });

  @override
  State<ArticCachedImage> createState() => _ArticCachedImageState();
}

class _ArticCachedImageState extends State<ArticCachedImage> {
  File? _localFile;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant ArticCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _checkCache();
    }
  }

  Future<void> _checkCache() async {
    final url = widget.imageUrl;
    if (url == null || url.trim().isEmpty) {
      setState(() {
        _localFile = null;
        _hasError = false;
      });
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(appDir.path, 'cached_product_images'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Generar nombre de archivo único sanitizado basado en la URL
      final fileName = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') + '.jpg';
      final localPath = p.join(cacheDir.path, fileName);
      final file = File(localPath);

      if (await file.exists() && await file.length() > 0) {
        if (mounted) {
          setState(() {
            _localFile = file;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        // Descargar el archivo
        _downloadImage(url, file);
      }
    } catch (e) {
      debugPrint("Error checking image cache: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadImage(String url, File targetFile) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
        await targetFile.writeAsBytes(bytes);
        if (mounted) {
          setState(() {
            _localFile = targetFile;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        throw Exception("Failed to download image, status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error downloading image: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sombra suave si hasShadow es true
    final boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      boxShadow: widget.hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ]
          : null,
    );

    // Contenido del placeholder elegante
    final defaultPlaceholder = widget.placeholder ?? Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: isDark ? Colors.white38 : Colors.black38,
          size: widget.width != null ? widget.width! * 0.45 : 24,
        ),
      ),
    );

    if (widget.imageUrl == null || widget.imageUrl!.trim().isEmpty) {
      return defaultPlaceholder;
    }

    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || _localFile == null) {
      return defaultPlaceholder;
    }

    return Container(
      decoration: boxDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.file(
          _localFile!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return defaultPlaceholder;
          },
        ),
      ),
    );
  }
}
