class Producto {
  final int? id;
  final String nombre;
  final String? codigo; // NUEVO
  final String? descripcion; // NUEVO
  final double precioVenta; // NUEVO (antes: precio)
  final double costoCompra; // NUEVO
  final int stock; // NUEVO
  final int? categoriaId; // NUEVO
  final String? imageUrl; // NUEVO

  const Producto({
    this.id,
    required this.nombre,
    this.codigo,
    this.descripcion,
    required this.precioVenta,
    required this.costoCompra,
    this.stock = 0,
    this.categoriaId,
    this.imageUrl,
  });

  /// 💡 Utilidad por unidad (para mostrar rápido en UI)
  double get utilidadUnidad => precioVenta - costoCompra;

  /// Guardar en SQLite (nombres de columnas = esquema de DB)
  Map<String, dynamic> toMap() => {
        'id': id,
        'codigo': codigo,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio_venta': precioVenta,
        'costo_compra': costoCompra,
        'stock': stock,
        'categoria_id': categoriaId,
        'imageUrl': imageUrl,
      };

  /// Cargar desde SQLite (tolerante al viejo 'precio')
  factory Producto.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    // Compatibilidad: si no viene precio_venta, usar 'precio'
    final precioVenta = map.containsKey('precio_venta')
        ? toDouble(map['precio_venta'])
        : toDouble(map['precio']);

    return Producto(
      id: map['id'] as int?,
      nombre: map['nombre']?.toString() ?? '',
      codigo: map['codigo']?.toString(),
      descripcion: map['descripcion']?.toString(),
      precioVenta: precioVenta,
      costoCompra: toDouble(map['costo_compra']),
      stock: (map['stock'] is int)
          ? map['stock'] as int
          : int.tryParse('${map['stock'] ?? 0}') ?? 0,
      categoriaId: map['categoria_id'] as int?,
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  Producto copyWith({
    int? id,
    String? nombre,
    String? codigo,
    String? descripcion,
    double? precioVenta,
    double? costoCompra,
    int? stock,
    int? categoriaId,
    String? imageUrl,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      precioVenta: precioVenta ?? this.precioVenta,
      costoCompra: costoCompra ?? this.costoCompra,
      stock: stock ?? this.stock,
      categoriaId: categoriaId ?? this.categoriaId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() =>
      'Producto(id:$id, cod:$codigo, nombre:$nombre, pv:$precioVenta, cc:$costoCompra, stock:$stock, cat:$categoriaId, img:$imageUrl)';
}
