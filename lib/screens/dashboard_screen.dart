import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_kpi_card.dart';

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
    DBService().onDatabaseChanged.listen((_) => _loadDashboardData());
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
      body: ArticBackground(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            // ✅ evita overflow de gráficos
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔥 KPI Cards Árticas
                ArticKpiCard(
                  title: "Ventas de Hoy",
                  value: "💰 \$${ventasHoy.toStringAsFixed(2)}",
                  accentColor: Colors.green,
                ),
                ArticKpiCard(
                  title: "Ventas del Mes",
                  value: "📆 \$${ventasMes.toStringAsFixed(2)}",
                  accentColor: Colors.blue,
                ),
                ArticKpiCard(
                  title: "Deudas Pendientes",
                  value: "💸 \$${deudasPendientes.toStringAsFixed(2)}",
                  accentColor: Colors.red,
                ),
                ArticKpiCard(
                  title: "Producto Más Vendido",
                  value: "🏆 $productoTop",
                  accentColor: Colors.orange,
                ),

                const SizedBox(height: 20),

                // 📊 Gráfico de barras
                const Text("📊 Ventas últimos 7 días",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 220, child: _buildBarChart()),

                const SizedBox(height: 30),

                // 🥧 Gráfico de pastel
                const Text("🥧 Métodos de pago",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 240, child: _buildPieChart()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 📊 **Gráfico de barras**
  Widget _buildBarChart() {
    if (ventasDias.isEmpty) {
      return const Center(
          child: Text("Sin datos", style: TextStyle(color: Colors.white)));
    }
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
                return index < ventasDias.length
                    ? Text(ventasDias[index]['dia'],
                        style: const TextStyle(color: Colors.white))
                    : const Text("");
              },
            ),
          ),
        ),
        barGroups: List.generate(ventasDias.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: (ventasDias[i]['total'] as double),
              color: Colors.cyanAccent,
              borderRadius: BorderRadius.circular(4),
            )
          ]);
        }),
      ),
    );
  }

  /// 🥧 **Gráfico de pastel**
  Widget _buildPieChart() {
    if (metodosPago.isEmpty) {
      return const Center(
          child: Text("Sin datos", style: TextStyle(color: Colors.white)));
    }
    return PieChart(
      PieChartData(
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        sections: metodosPago.entries.map((e) {
          return PieChartSectionData(
            title: "${e.key}\n${e.value.toStringAsFixed(0)}%",
            value: e.value,
            color: _getColorForMetodo(e.key),
            radius: 70,
            titleStyle: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          );
        }).toList(),
      ),
    );
  }

  Color _getColorForMetodo(String metodo) {
    switch (metodo) {
      case "Efectivo":
        return Colors.greenAccent;
      case "Tarjeta":
        return Colors.blueAccent;
      case "Transferencia":
        return Colors.orangeAccent;
      case "Fiado":
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
