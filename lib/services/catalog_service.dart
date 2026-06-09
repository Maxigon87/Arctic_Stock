import 'dart:io';

import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import 'db_service.dart';
import 'file_helper.dart';
import '../utils/file_namer.dart';

class CatalogService {
  /// Helper to extract raw value from Excel CellValue
  static dynamic _getRawValue(CellValue? value) {
    if (value == null) return null;
    if (value is TextCellValue) return value.value;
    if (value is IntCellValue) return value.value;
    if (value is DoubleCellValue) return value.value;
    if (value is BoolCellValue) return value.value;
    if (value is DateCellValue) return DateTime(value.year, value.month, value.day);
    if (value is DateTimeCellValue) {
      return DateTime(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      );
    }
    return value.toString();
  }

  /// Exporta todos los productos a un archivo Excel.
  /// Devuelve el [File] generado o null si no se pudo crear.
  static Future<File?> exportProductos() async {
    final productos = await DBService().getProductos(incluirInactivos: true);

    final excel = Excel.createExcel();
    final sheet = excel['Productos'];
    excel.setDefaultSheet('Productos');

    // Encabezados
    sheet.appendRow(<CellValue?>[
      TextCellValue('codigo'),
      TextCellValue('nombre'),
      TextCellValue('descripcion'),
      TextCellValue('precio_venta'),
      TextCellValue('costo_compra'),
      TextCellValue('stock'),
      TextCellValue('categoria'),
    ]);

    for (final p in productos) {
      sheet.appendRow(<CellValue?>[
        TextCellValue(p['codigo']?.toString() ?? ''),
        TextCellValue(p['nombre']?.toString() ?? ''),
        TextCellValue(p['descripcion']?.toString() ?? ''),
        DoubleCellValue((p['precio_venta'] as num?)?.toDouble() ?? 0.0),
        DoubleCellValue((p['costo_compra'] as num?)?.toDouble() ?? 0.0),
        IntCellValue((p['stock'] as num?)?.toInt() ?? 0),
        TextCellValue(p['categoria_nombre']?.toString() ?? ''),
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

  /// Importa productos desde un archivo Excel o CSV.
  /// Cada fila debe tener el mismo formato generado por la exportación.
  static Future<void> importProductos(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    final List<Map<String, dynamic>> rows = [];

    if (extension == '.csv') {
      final content = await file.readAsString();
      final csvRows = Csv(lineDelimiter: '\n', fieldDelimiter: ',').decode(content);
      if (csvRows.isEmpty) return;
      final headers = csvRows.first.map((e) => e.toString()).toList();
      for (var i = 1; i < csvRows.length; i++) {
        final row = csvRows[i];
        final map = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          map[headers[j]] = row[j];
        }
        rows.add(map);
      }
    } else {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Productos'] ?? excel.tables.values.first;
      if (table == null || table.rows.isEmpty) return;
      final headers = table.rows.first
          .map((cell) => _getRawValue(cell?.value)?.toString() ?? '')
          .toList();
      for (var i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        final map = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          map[headers[j]] = _getRawValue(row[j]?.value);
        }
        rows.add(map);
      }
    }

    final db = DBService();
    final categorias = await db.getCategorias();
    final Map<String, int> categoriaIds = {
      for (final c in categorias)
        (c['nombre'] as String).toLowerCase(): c['id'] as int,
    };

    for (final row in rows) {
      final nombre = row['nombre']?.toString().trim();
      final precio = double.tryParse(row['precio_venta']?.toString() ?? '');
      if (nombre == null || nombre.isEmpty || precio == null) {
        continue; // Campos obligatorios faltantes
      }

      final codigo = row['codigo']?.toString().trim();
      final descripcion = row['descripcion']?.toString().trim();
      final costo =
          double.tryParse(row['costo_compra']?.toString() ?? '0') ?? 0.0;
      final stockRaw = row['stock'];
      final stock = stockRaw is num
          ? stockRaw.toInt()
          : (double.tryParse(stockRaw?.toString() ?? '0') ?? 0).toInt();

      int? categoriaId;
      final categoriaNombre = row['categoria']?.toString().trim();
      if (categoriaNombre != null && categoriaNombre.isNotEmpty) {
        final key = categoriaNombre.toLowerCase();
        if (!categoriaIds.containsKey(key)) {
          final newId = await db.insertCategoria(categoriaNombre);
          categoriaIds[key] = newId;
        }
        categoriaId = categoriaIds[key];
      }

      final data = {
        'codigo': codigo,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio_venta': precio,
        'costo_compra': costo,
        'stock': stock,
        'categoria_id': categoriaId,
      };

      if (codigo != null && codigo.isNotEmpty) {
        final existing = await db.getProductoByCodigo(codigo);
        if (existing != null) {
          await db.updateProducto(data, existing['id'] as int);
          continue;
        }
      }
      await db.insertProducto(data);
    }
  }
}
