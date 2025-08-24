import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ArticStock/Services/catalog_service.dart';
import 'package:ArticStock/Services/db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('importProductos handles numeric stock values', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final tempDir = await Directory.systemTemp.createTemp();
    databaseFactoryFfi.setDatabasesPath(tempDir.path);
    await DBService().close();

    final csvContent = '''
codigo,nombre,descripcion,precio_venta,costo_compra,stock,categoria
A,Producto A,DescA,10,5,50,Cat1
B,Producto B,DescB,20,10,50.0,Cat2
''';

    final file = File(p.join(tempDir.path, 'productos.csv'));
    await file.writeAsString(csvContent);

    await CatalogService.importProductos(file);

    final productos = await DBService().getProductos();
    final productoA = productos.firstWhere(
      (p) => p['codigo'] == 'A',
      orElse: () => {},
    );
    final productoB = productos.firstWhere(
      (p) => p['codigo'] == 'B',
      orElse: () => {},
    );

    expect(productoA['stock'], 50);
    expect(productoB['stock'], 50);
  });
}
