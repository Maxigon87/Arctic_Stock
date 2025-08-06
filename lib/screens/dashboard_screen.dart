import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_kpi_card.dart';
import '../widgets/artic_container.dart';

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
  int? categoriaSeleccionada;
  DateTime? desde;
  DateTime? hasta;
  List<Map<String, dynamic>> categorias = [];
  final DBService dbService = DBService();

  /// ✅ NUEVO: KPI Productos sin stock
  int _productosSinStock = 0;
  late StreamSubscription _dbSub;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // ✅ Suscripción para refrescar KPI cuando cambia la base
    _dbSub = DBService().onDatabaseChanged.listen((_) => _loadDashboardData());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final db = DBService();
    ventasHoy = await db.getTotalVentasDia(DateTime.now());
    ventasMes = await db.getTotalVentasMes(DateTime.now());
    deudasPendientes = await db.getTotalDeudasPendientes();
    productoTop = await db.getProductoMasVendido();
    ventasDias = await db.getVentasUltimos7Dias();
    metodosPago = await db.getDistribucionMetodosPago();
    _productosSinStock = await db.getProductosSinStockCount();

    if (mounted) setState(() {});
  }

  Widget _buildFiltrosDashboard() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                hint: const Text("Categoría"),
                value: categoriaSeleccionada,
                items: categorias.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['nombre']),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => categoriaSeleccionada = v);
                  _loadDashboardData();
                },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () async {
                final rango = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2022),
                  lastDate: DateTime.now(),
                );
                if (rango != null) {
                  setState(() {
                    desde = rango.start;
                    hasta = rango.end;
                  });
                  _loadDashboardData();
                }
              },
              child: const Text("Filtrar Fecha"),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📊 Dashboard")),
      body: ArticBackground(
        child: ArticContainer(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltrosDashboard(),

                // ✅ KPI nuevo: Productos sin stock (con alerta)
                AnimatedOpacity(
                  opacity: _productosSinStock > 0 ? 0.6 : 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: ArticKpiCard(
                    title: "Productos sin stock",
                    value: "$_productosSinStock",
                    accentColor:
                        _productosSinStock > 0 ? Colors.redAccent : Colors.teal,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),

                // 🔥 Otros KPI
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
                ArticKpiCard(
                  title: "Productos sin Stock",
                  value: "⚠️ $_productosSinStock",
                  accentColor: Colors.redAccent,
                ),

                const SizedBox(height: 20),

                const Text("📊 Ventas últimos 7 días",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 220, child: _buildBarChart()),

                const SizedBox(height: 30),

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
