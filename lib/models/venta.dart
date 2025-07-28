class Venta {
  final int? id;
  final int productoId;   // FK hacia Producto
  final int cantidad;
  final double total;
  final String fecha;

  Venta({
    this.id,
    required this.productoId,
    required this.cantidad,
    required this.total,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'productoId': productoId,
    'cantidad': cantidad,
    'total': total,
    'fecha': fecha,
  };

  factory Venta.fromMap(Map<String, dynamic> map) => Venta(
    id: map['id'],
    productoId: map['productoId'],
    cantidad: map['cantidad'],
    total: map['total'],
    fecha: map['fecha'],
  );
}
