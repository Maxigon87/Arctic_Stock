import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double ventasHoy = 0;
  double ventasMes = 0;
  double deudasPendientes = 0;
  String productoTop = "Sin datos";
  List<Map<String, dynamic>> ventasDias = [];
  Map<String, double> metodosPago = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // ✅ Escucha cambios en la DB
    DBService().onDatabaseChanged.listen((_) {
      _loadDashboardData(); // 🔄 Recarga datos y refresca gráficos
    });
  }

  Future<void> _loadDashboardData() async {
    final db = DBService();

    ventasHoy = await db.getTotalVentasDia(DateTime.now());
    ventasMes = await db.getTotalVentasMes(DateTime.now());
    deudasPendientes = await db.getTotalDeudasPendientes();
    productoTop = await db.getProductoMasVendido();
    ventasDias = await db.getVentasUltimos7Dias();
    metodosPago = await db.getDistribucionMetodosPago();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📊 Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildKpiCard("Ventas de Hoy",
                "💰 \$${ventasHoy.toStringAsFixed(2)}", Colors.green),
            _buildKpiCard("Ventas del Mes",
                "📆 \$${ventasMes.toStringAsFixed(2)}", Colors.blue),
            _buildKpiCard(
                "Deudas Pendientes",
                "💸 \$${deudasPendientes.toStringAsFixed(2)}",
                Colors.redAccent),
            _buildKpiCard(
                "Producto Más Vendido", "🏆 $productoTop", Colors.orange),
            const SizedBox(height: 20),

            // 📊 Ventas de los últimos 7 días
            const Text("📊 Ventas últimos 7 días",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildBarChart()),

            const SizedBox(height: 30),

            // 🥧 Distribución de métodos de pago
            const Text("🥧 Métodos de pago",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildPieChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        trailing: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  /// 📊 **Gráfico de barras: ventas últimos 7 días**
  Widget _buildBarChart() {
    if (ventasDias.isEmpty) return const Center(child: Text("Sin datos"));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < ventasDias.length) {
                  return Text(ventasDias[index]['dia']);
                }
                return const Text("");
              },
            ),
          ),
        ),
        barGroups: List.generate(ventasDias.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
                toY: (ventasDias[i]['total'] as double),
                color: Colors.greenAccent)
          ]);
        }),
      ),
    );
  }

  /// 🥧 **Gráfico de pastel: métodos de pago**
  Widget _buildPieChart() {
    if (metodosPago.isEmpty) return const Center(child: Text("Sin datos"));
    return PieChart(
      PieChartData(
        sections: metodosPago.entries.map((e) {
          return PieChartSectionData(
            title: "${e.key}\n${e.value.toStringAsFixed(0)}%",
            value: e.value,
            color: _getColorForMetodo(e.key),
            radius: 60,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          );
        }).toList(),
      ),
    );
  }

  Color _getColorForMetodo(String metodo) {
    switch (metodo) {
      case "Efectivo":
        return Colors.green;
      case "Tarjeta":
        return Colors.blue;
      case "Transferencia":
        return Colors.orange;
      case "Fiado":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
