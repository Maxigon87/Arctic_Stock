import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_service.dart';
import '../widgets/artic_metric_card.dart';
import '../widgets/artic_empty_state.dart';
import '../utils/currency_formatter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Totales
  double ventasHoy = 0;
  double ventasPeriodo = 0; 
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

    // Ventas de hoy
    ventasHoy = await dbService.getTotalVentasDia(
      hoy,
      categoriaId: categoriaSeleccionada,
    );

    // Ventas del período
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

    // Ganancia del período
    gananciaPeriodo = await dbService.getGananciaTotal(
      desde: tieneRango ? desde : _startOfMonth(hoy),
      hasta: tieneRango ? hasta : _endOfMonth(hoy),
      categoriaId: categoriaSeleccionada,
    );

    // Deudas pendientes
    deudasPendientes = await dbService.getTotalDeudasPendientes(
      categoriaId: categoriaSeleccionada,
    );

    // Producto top
    productoTop = await dbService.getProductoMasVendido(
      categoriaId: categoriaSeleccionada,
      desde: desde,
      hasta: hasta,
    );

    // Serie últimos 7 días
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

  String _fmtDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Widget _buildFiltrosDashboard() {
    final tieneRango = (desde != null && hasta != null);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF22D3EE);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black12,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filtros de Análisis",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (tieneRango) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Período: ${_fmtDate(desde!)} → ${_fmtDate(hasta!)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (tieneRango || categoriaSeleccionada != null)
                IconButton(
                  tooltip: 'Limpiar filtros',
                  onPressed: () {
                    setState(() {
                      desde = null;
                      hasta = null;
                      categoriaSeleccionada = null;
                    });
                    _loadDashboardData();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: Colors.redAccent,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Dropdown de Categoría
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    hint: Text(
                      "Todas las categorías",
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    value: categoriaSeleccionada,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          "Todas las categorías",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ...categorias.map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(
                              c['nombre'],
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => categoriaSeleccionada = v);
                      _loadDashboardData();
                    },
                  ),
                ),
              ),
              // Date Picker Button
              ElevatedButton.icon(
                onPressed: () async {
                  final rango = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: isDark
                              ? const ColorScheme.dark(
                                  primary: Color(0xFF22D3EE),
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E293B),
                                  onSurface: Colors.white,
                                )
                              : const ColorScheme.light(
                                  primary: Color(0xFF0284C7),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black87,
                                ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (rango != null) {
                    setState(() {
                      desde = rango.start;
                      hasta = rango.end;
                    });
                    _loadDashboardData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.6),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
                    ),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: Text(
                  tieneRango ? "Cambiar rango" : "Filtrar por fecha",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(double maxWidth) {
    int columns = 4;
    if (maxWidth < 650) {
      columns = 1;
    } else if (maxWidth < 950) {
      columns = 2;
    } else if (maxWidth < 1300) {
      columns = 3;
    }

    final tieneRango = (desde != null && hasta != null);
    final salesTrend = ventasDias.map((d) => (d['total'] as num?)?.toDouble() ?? 0.0).toList();

    final kpis = [
      if (_productosSinStock > 0)
        _KpiData(
          title: "Productos sin stock",
          value: "$_productosSinStock",
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
          subtitle: "¡Atención requerida!",
          trendData: [5.0, 4.0, 3.0, 4.0, 3.0, 2.0, 1.0, _productosSinStock.toDouble()],
        ),
      _KpiData(
        title: "Ventas de Hoy",
        value: formatCurrency(ventasHoy),
        icon: Icons.monetization_on_outlined,
        color: const Color(0xFF10B981),
        subtitle: "Ventas del día actual",
        trendData: salesTrend,
      ),
      _KpiData(
        title: "Ganancia de Hoy",
        value: formatCurrency(gananciaHoy),
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF34D399),
        subtitle: "Margen del día actual",
        trendData: salesTrend.map((v) => v * 0.3).toList(),
      ),
      _KpiData(
        title: tieneRango ? "Ventas del Rango" : "Ventas del Mes",
        value: formatCurrency(ventasPeriodo),
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF3B82F6),
        subtitle: tieneRango ? "Rango seleccionado" : "Mes en curso",
        trendData: salesTrend,
      ),
      _KpiData(
        title: tieneRango ? "Ganancia del Rango" : "Ganancia del Mes",
        value: formatCurrency(gananciaPeriodo),
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF6366F1),
        subtitle: tieneRango ? "Rango seleccionado" : "Mes en curso",
        trendData: salesTrend.map((v) => v * 0.3).toList(),
      ),
      _KpiData(
        title: "Deudas Pendientes",
        value: formatCurrency(deudasPendientes),
        icon: Icons.money_off_rounded,
        color: const Color(0xFFF87171),
        subtitle: "Cobros pendientes de fiados",
        trendData: [100.0, 95.0, 90.0, 85.0, 80.0, 85.0, 90.0, deudasPendientes > 0 ? deudasPendientes : 0.0],
      ),
      _KpiData(
        title: "Producto Más Vendido",
        value: productoTop,
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFFF59E0B),
        subtitle: "Mayor rotación comercial",
        showSparkline: false,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 140,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return ArticMetricCard(
          title: kpi.title,
          value: kpi.value,
          accentColor: kpi.color,
          icon: kpi.icon,
          subtitle: kpi.subtitle,
          trendData: kpi.trendData,
          showSparkline: kpi.showSparkline,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Optimizado: fondo transparente para el efecto de fondo unificado
      appBar: AppBar(
        title: const Text(
          "📊 Dashboard Comercial",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final bool isLargeScreen = screenWidth > 950;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltrosDashboard(),
                _buildMetricsGrid(screenWidth),
                const SizedBox(height: 24),
                
                // Distribución de gráficos
                if (isLargeScreen)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildChartContainer(
                          context: context,
                          title: "Ventas últimos 7 días",
                          icon: Icons.bar_chart_rounded,
                          child: SizedBox(height: 240, child: _buildBarChart()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildChartContainer(
                          context: context,
                          title: "Métodos de pago",
                          icon: Icons.pie_chart_outline,
                          child: SizedBox(height: 240, child: _buildPieChart()),
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildChartContainer(
                    context: context,
                    title: "Ventas últimos 7 días",
                    icon: Icons.bar_chart_rounded,
                    child: SizedBox(height: 220, child: _buildBarChart()),
                  ),
                  const SizedBox(height: 16),
                  _buildChartContainer(
                    context: context,
                    title: "Métodos de pago",
                    icon: Icons.pie_chart_outline,
                    child: SizedBox(height: 240, child: _buildPieChart()),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartContainer({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF22D3EE);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (ventasDias.isEmpty) {
      return const ArticEmptyState(
        icon: Icons.analytics_outlined,
        title: "Sin datos de ventas",
        description: "No se registran ventas para los últimos 7 días.",
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.black12,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text("");
                return Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: index < ventasDias.length
                      ? Text(
                          ventasDias[index]['dia'].toString(),
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const Text(""),
                );
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: total == 0 ? 100 : null,
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPieChart() {
    if (metodosPago.isEmpty) {
      return const ArticEmptyState(
        icon: Icons.pie_chart_outline_outlined,
        title: "Sin métodos de pago",
        description: "No se registran métodos de pago en las ventas del período.",
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PieChart(
      PieChartData(
        centerSpaceRadius: 45,
        sectionsSpace: 4,
        sections: metodosPago.entries.map((e) {
          final value = e.value;
          return PieChartSectionData(
            title: "${e.key}\n${value.toStringAsFixed(0)}%",
            value: value,
            color: _getColorForMetodo(e.key),
            radius: 55,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getColorForMetodo(String metodo) {
    switch (metodo) {
      case "Efectivo":
        return const Color(0xFF10B981); // Emerald
      case "Tarjeta":
        return const Color(0xFF3B82F6); // Blue
      case "Transferencia":
        return const Color(0xFFF59E0B); // Amber
      case "Fiado":
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey;
    }
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<double>? trendData;
  final bool showSparkline;

  _KpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.trendData,
    this.showSparkline = true,
  });
}
