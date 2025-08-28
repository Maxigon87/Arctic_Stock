class FileNamer {
  /// Genera un nombre de archivo para facturas PDF
  static String factura(int ventaId, String cliente) {
    final fecha = DateTime.now().toIso8601String().split('T').first;
    // Sanitizar el nombre del cliente (sin espacios ni caracteres raros)
    final safeCliente = cliente.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'venta_${ventaId}_${safeCliente}_$fecha.pdf';
  }

  /// Nombre para reporte mensual en PDF
  static String reportePdf() {
    final now = DateTime.now();
    return 'reporte_${now.year}-${now.month.toString().padLeft(2, '0')}.pdf';
  }

  /// Nombre para reporte de productos en PDF
  static String reporteProductosPdf() {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'reporte_productos_$date.pdf';
  }

  /// Nombre para reporte de ingresos en PDF
  static String reporteIngresosPdf() {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'reporte_ingresos_$date.pdf';
  }

  /// Nombre para reporte mensual en Excel
  static String reporteExcel() {
    final now = DateTime.now();
    return 'reporte_${now.year}-${now.month.toString().padLeft(2, '0')}.xlsx';
  }

  /// Nombre para exportación del catálogo de productos en Excel
  static String catalogoExcel() {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'catalogo_$date.xlsx';
  }
}
