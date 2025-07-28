class Deuda {
  final int? id;
  final String cliente;
  final double monto;
  final String fecha;

  Deuda({
    this.id,
    required this.cliente,
    required this.monto,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'cliente': cliente,
    'monto': monto,
    'fecha': fecha,
  };

  factory Deuda.fromMap(Map<String, dynamic> map) => Deuda(
    id: map['id'],
    cliente: map['cliente'],
    monto: map['monto'],
    fecha: map['fecha'],
  );
}
