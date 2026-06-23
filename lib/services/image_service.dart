import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:artic_stock/widgets/artic_dialog.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  /// Abre el selector de imagen según la plataforma.
  /// Devuelve los bytes originales de la imagen seleccionada, o null si se cancela.
  Future<Uint8List?> pickImage(BuildContext context) async {
    if (Platform.isWindows) {
      return await _pickImageWindows();
    } else if (Platform.isAndroid) {
      return await _pickImageAndroid(context);
    }
    return null;
  }

  Future<Uint8List?> _pickImageWindows() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint("Error picking image on Windows: $e");
    }
    return null;
  }

  Future<Uint8List?> _pickImageAndroid(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Mostrar un diálogo elegante para elegir cámara o galería
    final ImageSource? source = await showArticDialog<ImageSource>(
      context: context,
      builder: (ctx) => ArticDialogCard(
        title: "Seleccionar Imagen",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
              title: Text("Tomar Foto", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.photo_library, color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7)),
              title: Text("Elegir de Galería", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source);
      if (file != null) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint("Error picking image on Android: $e");
    }
    return null;
  }

  /// Redimensiona a 300x300, convierte a JPEG al 60% de calidad,
  /// y remueve metadatos EXIF al decodificar y volver a codificar.
  Future<Uint8List?> processImage(Uint8List originalBytes) async {
    try {
      // 1. Decodificar la imagen a píxeles en memoria (remueve EXIF)
      final image = img.decodeImage(originalBytes);
      if (image == null) {
        debugPrint("Error: No se pudo decodificar la imagen.");
        return null;
      }

      // 2. Redimensionar a 300x300 píxeles manteniendo o forzando la relación de aspecto.
      // Dado que el requerimiento pide "Redimensionar a 300x300 píxeles", usamos copyResize.
      final resizedImage = img.copyResize(
        image,
        width: 300,
        height: 300,
        interpolation: img.Interpolation.linear,
      );

      // 3. Convertir a JPEG con calidad 60%
      final jpegBytes = img.encodeJpg(resizedImage, quality: 60);
      final resultBytes = Uint8List.fromList(jpegBytes);

      debugPrint("Imagen procesada exitosamente. Tamaño original: ${originalBytes.lengthInBytes} bytes. Tamaño final: ${resultBytes.lengthInBytes} bytes.");
      return resultBytes;
    } catch (e) {
      debugPrint("Error al procesar la imagen: $e");
      return null;
    }
  }

  /// Sube la imagen a Firebase Storage y devuelve la URL de descarga.
  Future<String?> uploadProductImage(int productId, Uint8List processedBytes) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('productos/producto_$productId.jpg');

      final uploadTask = storageRef.putData(
        processedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading image to Firebase Storage: $e");
      return null;
    }
  }
}
