class Cliente {
  final int? id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? direccion;

  Cliente(
      {this.id,
      required this.nombre,
      this.telefono,
      this.email,
      this.direccion});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nombre: map['nombre'],
      telefono: map['telefono'],
      email: map['email'],
      direccion: map['direccion'],
    );
  }
}
