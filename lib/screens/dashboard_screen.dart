import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../Services/db_service.dart';
import '../widgets/artic_background.dart';
import '../widgets/artic_kpi_card.dart';
import '../widgets/artic_container.dart';
import '../utils/currency_formatter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Totales
  double ventasHoy = 0;
  double ventasPeriodo = 0; // ← mes actual o rango seleccionado
  double deudasPendientes = 0;
  String productoTop = "Sin datos";
  // Ganancias
  double gananciaHoy = 0;
  double gananciaPeriodo = 0;

  // Series / distribuciones
  List<Map<String, dynamic>> ventasDias = [];
  Map<String, double> metodosPago = {};

  // Filtros
  int? categoriaSeleccionada;
  DateTime? desde;
  DateTime? hasta;
  List<Map<String, dynamic>> categorias = [];

  // Otros
  final DBService dbService = DBService();
  int _productosSinStock = 0;
  late StreamSubscription _dbSub;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
    _loadDashboardData();
    _dbSub = DBService().onDatabaseChanged.listen((_) => _loadDashboardData());
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _loadCategorias() async {
    categorias = await dbService.getAllCategorias();
    if (mounted) setState(() {});
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 0, 23, 59, 59);

  Future<void> _loadDashboardData() async {
    final hoy = DateTime.now();
    final tieneRango = (desde != null && hasta != null);

    // Ventas de hoy (siempre día actual)
    ventasHoy = await dbService.getTotalVentasDia(
      hoy,
      categoriaId: categoriaSeleccionada,
    );

    // Ventas del período (mes actual o rango)
    ventasPeriodo = await dbService.getTotalVentasMes(
      hoy,
      categoriaId: categoriaSeleccionada,
      desde: tieneRango ? desde : null,
      hasta: tieneRango ? hasta : null,
    );

    // Ganancia de hoy
    gananciaHoy = await dbService.getGananciaTotal(
      desde: _startOfDay(hoy),
      hasta: _endOfDay(hoy),
      categoriaId: categoriaSeleccionada,
    );

    // Ganancia del período (mes actual o rango)
    gananciaPeriodo = await dbService.getGananciaTotal(
      desde: tieneRango ? desde : _startOfMonth(hoy),
      hasta: tieneRango ? hasta : _endOfMonth(hoy),
      categoriaId: categoriaSeleccionada,
    );

    // Deudas pendientes
    deudasPendientes = await dbService.getTotalDeudasPendientes(
      categoriaId: categoriaSeleccionada,
    );

    // Producto top (respeta rango si hay)
    productoTop = await dbService.getProductoMasVendido(
      categoriaId: categoriaSeleccionada,
      desde: desde,
      hasta: hasta,
    );

    // Serie últimos 7 días (por ahora fijo a últimos 7 días)
    ventasDias = await dbService.getVentasUltimos7Dias(
      categoriaId: categoriaSeleccionada,
    );

    // Distribución métodos de pago
    metodosPago = await dbService.getDistribucionMetodosPago(
      categoriaId: categoriaSeleccionada,
    );

    // KPI sin stock
    _productosSinStock = await dbService.getProductosSinStockCount();

    if (mounted) setState(() {});
  }

  Widget _buildFiltrosDashboard() {
    final tieneRango = (desde != null && hasta != null);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                hint: const Text("Categoría"),
                value: categoriaSeleccionada,
                items: categorias
                    .map((c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['nombre']),
                        ))
                    .toList(),
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
              child: Text(tieneRango ? "Cambiar rango" : "Filtrar Fecha"),
            ),
            if (tieneRango) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Limpiar rango',
                onPressed: () {
                  setState(() {
                    desde = null;
                    hasta = null;
                  });
                  _loadDashboardData();
                },
                icon: const Icon(Icons.clear),
              ),
            ]
          ],
        ),
        const SizedBox(height: 10),
        if (tieneRango)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Rango: ${_fmtDate(desde!)} → ${_fmtDate(hasta!)}",
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final tieneRango = (desde != null && hasta != null);
    final tituloVentasPeriodo =
        tieneRango ? "Ventas del Rango" : "Ventas del Mes";
    final tituloGananciaPeriodo =
        tieneRango ? "Ganancia del Rango" : "Ganancia del Mes";

    return Scaffold(
      appBar: AppBar(title: const Text("📊 Dashboard")),
      body: ArticBackground(
        child: ArticContainer(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltrosDashboard(),

                // KPI: Productos sin stock
                AnimatedOpacity(
                  opacity: _productosSinStock > 0 ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 400),
                  child: ArticKpiCard(
                    title: "Productos sin stock",
                    value: "$_productosSinStock",
                    accentColor:
                        _productosSinStock > 0 ? Colors.redAccent : Colors.teal,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),

                // Ventas y Ganancias - Hoy
                ArticKpiCard(
                  title: "Ventas de Hoy",
                  value: "💰 ${formatCurrency(ventasHoy)}",
                  accentColor: Colors.green,
                ),
                ArticKpiCard(
                  title: "Ganancia de Hoy",
                  value: "📈 ${formatCurrency(gananciaHoy)}",
                  accentColor: Colors.lightGreen,
                ),

                // Ventas y Ganancias - Período (mes o rango)
                ArticKpiCard(
                  title: tituloVentasPeriodo,
                  value: "📆 ${formatCurrency(ventasPeriodo)}",
                  accentColor: Colors.blue,
                ),
                ArticKpiCard(
                  title: tituloGananciaPeriodo,
                  value: "🏦 ${formatCurrency(gananciaPeriodo)}",
                  accentColor: Colors.indigo,
                ),

                // Deudas pendientes
                ArticKpiCard(
                  title: "Deudas Pendientes",
                  value: "💸 ${formatCurrency(deudasPendientes)}",
                  accentColor: Colors.red,
                ),

                // Producto Top
                ArticKpiCard(
                  title: "Producto Más Vendido",
                  value: "🏆 $productoTop",
                  accentColor: Colors.orange,
                ),

                const SizedBox(height: 20),

                const Text(
                  "📊 Ventas últimos 7 días",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 220, child: _buildBarChart()),

                const SizedBox(height: 30),

                const Text(
                  "🥧 Métodos de pago",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
        child: Text("Sin datos", style: TextStyle(color: Colors.white)),
      );
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
                final index = value.toInt();
                return index < ventasDias.length
                    ? Text(
                        ventasDias[index]['dia'].toString(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : const Text("");
              },
            ),
          ),
        ),
        barGroups: List.generate(ventasDias.length, (i) {
          final total = (ventasDias[i]['total'] as num?)?.toDouble() ?? 0.0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: total,
                color: Colors.cyanAccent,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPieChart() {
    if (metodosPago.isEmpty) {
      return const Center(
        child: Text("Sin datos", style: TextStyle(color: Colors.white)),
      );
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
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
