import 'dart:io';

import 'package:excel/excel.dart';

import 'db_service.dart';
import 'file_helper.dart';
import '../utils/file_namer.dart';

class CatalogService {
  /// Exporta todos los productos a un archivo Excel.
  /// Devuelve el [File] generado o null si no se pudo crear.
  static Future<File?> exportProductos() async {
    final productos = await DBService().getProductos(incluirInactivos: true);

    final excel = Excel.createExcel();
    final sheet = excel['Productos'];
    excel.setDefaultSheet('Productos');

    // Encabezados
    sheet.appendRow([
      'codigo',
      'nombre',
      'descripcion',
      'precio_venta',
      'costo_compra',
      'stock',
      'categoria',
    ]);

    for (final p in productos) {
      sheet.appendRow([
        p['codigo'] ?? '',
        p['nombre'] ?? '',
        p['descripcion'] ?? '',
        p['precio_venta'] ?? 0,
        p['costo_compra'] ?? 0,
        p['stock'] ?? 0,
        p['categoria_nombre'] ?? '',
      ]);
    }

    final dir = await FileHelper.getCatalogoDir();
    final file = File('${dir.path}/${FileNamer.catalogoExcel()}')
      ..createSync(recursive: true);

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      return file;
    }
    return null;
  }
}

