class Producto {
  final int? id;
  final String nombre;
  final double precio;

  Producto({this.id, required this.nombre, required this.precio});

  // Convierte el objeto en un Map para guardarlo en SQLite
  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
  };

  // Crea un Producto a partir de un Map (cuando lo traes de SQLite)
  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    id: map['id'],
    nombre: map['nombre'],
    precio: map['precio'],
  );
}
