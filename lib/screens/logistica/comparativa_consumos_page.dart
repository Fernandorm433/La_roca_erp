import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

enum FiltroTiempo { dia, semana, mes, ano, personalizado }

class ComparativaConsumosPage extends StatefulWidget {
  const ComparativaConsumosPage({super.key});

  @override
  State<ComparativaConsumosPage> createState() => _ComparativaConsumosPageState();
}

class _ComparativaConsumosPageState extends State<ComparativaConsumosPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  FiltroTiempo _filtroActual = FiltroTiempo.dia;
  DateTime? _fechaInicioCustom;
  DateTime? _fechaFinCustom;

  // Totales
  double _ingresoCementoBags = 0, _consumoCementoBags = 0;
  double _ingresoArena = 0, _consumoArena = 0;
  double _ingresoPiedra = 0, _consumoPiedra = 0;
  double _ingresoAditivo = 0, _consumoAditivo = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  String _limpiarNumero(dynamic valor) {
    if (valor == null) return '0';
    String s = valor.toString().replaceAll(',', '.');
    return s;
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    
    _ingresoCementoBags = _consumoCementoBags = 0;
    _ingresoArena = _consumoArena = 0;
    _ingresoPiedra = _consumoPiedra = 0;
    _ingresoAditivo = _consumoAditivo = 0;

    final now = DateTime.now();
    DateTime inicio, fin;

    switch (_filtroActual) {
      case FiltroTiempo.dia:
        inicio = DateTime(now.year, now.month, now.day);
        fin = inicio.add(const Duration(days: 1));
        break;
      case FiltroTiempo.semana:
        int daysToSubtract = now.weekday - 1; // 1 = Monday
        inicio = DateTime(now.year, now.month, now.day - daysToSubtract);
        fin = inicio.add(const Duration(days: 7));
        break;
      case FiltroTiempo.mes:
        inicio = DateTime(now.year, now.month, 1);
        fin = DateTime(now.year, now.month + 1, 1);
        break;
      case FiltroTiempo.ano:
        inicio = DateTime(now.year, 1, 1);
        fin = DateTime(now.year + 1, 1, 1);
        break;
      case FiltroTiempo.personalizado:
        inicio = _fechaInicioCustom ?? now;
        fin = _fechaFinCustom != null ? _fechaFinCustom!.add(const Duration(days: 1)) : now.add(const Duration(days: 1));
        break;
    }

    final String fechaInicioStr = inicio.toIso8601String().split('T')[0];
    final String fechaFinStr = fin.toIso8601String().split('T')[0];

    try {
      final recepciones = await _sb
          .from('recepcion_materiales')
          .select()
          .gte('fecha', fechaInicioStr)
          .lt('fecha', fechaFinStr);

      for (var r in recepciones) {
        String desc = r['descripcion'].toString().toUpperCase();
        double cant = double.tryParse(_limpiarNumero(r['volumen_m3'])) ?? 0;
        
        if (desc.contains('CEMENTO')) {
          _ingresoCementoBags += cant; 
        } else if (desc.contains('ARENA')) {
          _ingresoArena += cant * 1600; // Conversión: 1 m3 = 1600 kg
        } else if (desc.contains('PIEDRA')) {
          _ingresoPiedra += cant * 1600; // Conversión: 1 m3 = 1600 kg
        } else if (desc.contains('ADITIVO')) {
          _ingresoAditivo += cant; 
        }
      }

      final despachos = await _sb
          .from('despachos_produccion')
          .select()
          .gte('fecha', fechaInicioStr)
          .lt('fecha', fechaFinStr);

      for (var d in despachos) {
        double cementoKg = double.tryParse(_limpiarNumero(d['cemento'])) ?? 0;
        _consumoCementoBags += (cementoKg / 1500); // FÓRMULA SENCILLA: KG a BIG BAGS
        
        _consumoArena += double.tryParse(_limpiarNumero(d['arena'])) ?? 0;
        _consumoPiedra += (double.tryParse(_limpiarNumero(d['piedra_12'])) ?? 0) + 
                          (double.tryParse(_limpiarNumero(d['piedra_34'])) ?? 0) + 
                          (double.tryParse(_limpiarNumero(d['piedra_38'])) ?? 0);
        _consumoAditivo += double.tryParse(_limpiarNumero(d['aditivo'])) ?? 0;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint("Error comparativa: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: const Text('Dashboard Analítico de Consumos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3, color: Colors.white)),
        backgroundColor: const Color(0xFF002244),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF004899)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Resumen Global - Gráfico Moderno
                      _buildChartSection().animate().fade(duration: 400.ms).slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      
                      const Text('DESGLOSE DE MATERIALES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF003366), letterSpacing: 1.0)),
                      const SizedBox(height: 16),
                      
                      _buildModernCard('Cemento (Big Bags)', _ingresoCementoBags, _consumoCementoBags, 'Bolsas', Icons.shopping_bag, const Color(0xFF003366))
                          .animate().fade(delay: 100.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildModernCard('Arena (KG)', _ingresoArena, _consumoArena, 'KG', Icons.grain, const Color(0xFF004899))
                          .animate().fade(delay: 200.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildModernCard('Piedra Chancada (KG)', _ingresoPiedra, _consumoPiedra, 'KG', Icons.terrain, const Color(0xFF0284C7))
                          .animate().fade(delay: 300.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildModernCard('Aditivo (LT)', _ingresoAditivo, _consumoAditivo, 'LT', Icons.water_drop, const Color(0xFF38BDF8))
                          .animate().fade(delay: 400.ms).slideX(begin: 0.05),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFiltroBtn('HOY', FiltroTiempo.dia),
            const SizedBox(width: 12),
            _buildFiltroBtn('ESTA SEMANA', FiltroTiempo.semana),
            const SizedBox(width: 12),
            _buildFiltroBtn('ESTE MES', FiltroTiempo.mes),
            const SizedBox(width: 12),
            _buildFiltroBtn('ESTE AÑO', FiltroTiempo.ano),
            const SizedBox(width: 12),
            _buildCalendarBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarBtn() {
    final act = _filtroActual == FiltroTiempo.personalizado;
    return InkWell(
      onTap: _seleccionarRangoFechas,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: act ? const LinearGradient(colors: [Color(0xFF002244), Color(0xFF004899)]) : null,
          color: act ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: act ? [const BoxShadow(color: Color(0x33003366), blurRadius: 8, offset: Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: act ? Colors.white : const Color(0xFF64748B)),
            if (act && _fechaInicioCustom != null && _fechaFinCustom != null) ...[
              const SizedBox(width: 8),
              Text(
                '${DateFormat('dd/MM/yy').format(_fechaInicioCustom!)} - ${DateFormat('dd/MM/yy').format(_fechaFinCustom!)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarRangoFechas() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fechaInicioCustom != null && _fechaFinCustom != null
          ? DateTimeRange(start: _fechaInicioCustom!, end: _fechaFinCustom!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003366),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF002244),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _fechaInicioCustom = result.start;
        _fechaFinCustom = result.end;
        _filtroActual = FiltroTiempo.personalizado;
      });
      _cargarDatos();
    }
  }

  Widget _buildFiltroBtn(String label, FiltroTiempo filtro) {
    final act = _filtroActual == filtro;
    return InkWell(
      onTap: () {
        setState(() => _filtroActual = filtro);
        _cargarDatos();
      },
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: act ? const LinearGradient(colors: [Color(0xFF002244), Color(0xFF004899)]) : null,
          color: act ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: act ? [const BoxShadow(color: Color(0x33003366), blurRadius: 8, offset: Offset(0, 4))] : [],
        ),
        child: Text(label, style: TextStyle(color: act ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildChartSection() {
    double _calcPerc(double ing, double cons) {
      if (ing > 0) return cons / ing;
      if (cons > 0) return 1.2; // Si no hay ingreso pero hay consumo, es déficit máximo visual
      return 0.0;
    }

    double percCemento = _calcPerc(_ingresoCementoBags, _consumoCementoBags);
    double percArena = _calcPerc(_ingresoArena, _consumoArena);
    double percPiedra = _calcPerc(_ingresoPiedra, _consumoPiedra);
    double percAditivo = _calcPerc(_ingresoAditivo, _consumoAditivo);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF002244), Color(0xFF004899)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF002244).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nivel de Consumo vs Ingreso', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF002244), letterSpacing: -0.5)),
                      Text('Porcentaje de uso del stock en planta', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF0F172A),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String material = ['CEMENTO', 'ARENA', 'PIEDRA', 'ADITIVO'][group.x];
                      double ing = [_ingresoCementoBags, _ingresoArena, _ingresoPiedra, _ingresoAditivo][group.x];
                      double cons = [_consumoCementoBags, _consumoArena, _consumoPiedra, _consumoAditivo][group.x];
                      
                      String textVal;
                      if (ing <= 0 && cons > 0) {
                        textVal = 'DÉFICIT';
                      } else {
                        double perc = ing > 0 ? cons / ing : 0;
                        textVal = '${(perc * 100).toStringAsFixed(1)}%';
                      }
                      
                      bool isDeficit = cons > ing;

                      return BarTooltipItem(
                        '$material\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                        children: <TextSpan>[
                          TextSpan(
                            text: textVal,
                            style: TextStyle(color: isDeficit ? const Color(0xFFF87171) : const Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 36,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5);
                        String text = ['CEMENTO', 'ARENA', 'PIEDRA', 'ADITIVO'][value.toInt() % 4];
                        return SideTitleWidget(
                          meta: meta, 
                          space: 10, 
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(text, style: style)
                          )
                        );
                      }
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: 0.25,
                      getTitlesWidget: (value, meta) {
                        if (value > 1.0 || value <= 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text('${(value * 100).toInt()}%', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false, 
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1.5)
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, percCemento, const [Color(0xFF64748B), Color(0xFF0F172A)]),
                  _makeBarGroup(1, percArena, const [Color(0xFFFBBF24), Color(0xFFD97706)]),
                  _makeBarGroup(2, percPiedra, const [Color(0xFF94A3B8), Color(0xFF475569)]),
                  _makeBarGroup(3, percAditivo, const [Color(0xFFA78BFA), Color(0xFF7C3AED)]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0)))),
              const SizedBox(width: 8),
              const Text('Capacidad Total', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              const SizedBox(width: 24),
              Container(width: 14, height: 14, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              const Text('Consumo Activo', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              const SizedBox(width: 24),
              Container(width: 14, height: 14, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFDC2626)]), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              const Text('Déficit', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, List<Color> gradientColors) {
    double val = y > 1.1 ? 1.1 : y; 
    
    // Si consumió más de lo que ingresó, usar rojo
    LinearGradient barGradient = y > 1.0 
        ? const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFDC2626)], begin: Alignment.bottomCenter, end: Alignment.topCenter)
        : LinearGradient(colors: gradientColors, begin: Alignment.bottomCenter, end: Alignment.topCenter);

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: val,
          gradient: barGradient,
          width: 36, // barras más gruesas
          borderRadius: BorderRadius.circular(8),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 1.0, 
            color: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildModernCard(String titulo, double ingreso, double consumo, String unidad, IconData icono, Color colorMain) {
    final df = NumberFormat('#,##0.0', 'en_US');
    final double saldo = ingreso - consumo;
    final bool balanceNegativo = saldo < 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colorMain.withValues(alpha: 0.8), colorMain], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: colorMain.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(icono, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF002244), letterSpacing: -0.5)),
                      Text('Medido en $unidad', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: balanceNegativo ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(balanceNegativo ? Icons.warning_rounded : Icons.check_circle_rounded, 
                           size: 14, color: balanceNegativo ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(balanceNegativo ? 'Déficit' : 'Óptimo', 
                           style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: balanceNegativo ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildMetricCol('Ingreso Total', df.format(ingreso), const Color(0xFF10B981), Icons.arrow_downward_rounded)),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(child: _buildMetricCol('Consumido', df.format(consumo), const Color(0xFFF59E0B), Icons.arrow_upward_rounded)),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(child: _buildMetricCol('Restante', df.format(saldo), balanceNegativo ? const Color(0xFFEF4444) : const Color(0xFF0F172A), Icons.inventory_2_outlined)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Progress Bar Moderno
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(height: 12, color: const Color(0xFFF1F5F9)),
                  FractionallySizedBox(
                    widthFactor: ingreso <= 0 
                        ? (consumo > 0 ? 1.0 : 0.0) 
                        : (consumo / ingreso).clamp(0.0, 1.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: balanceNegativo 
                            ? const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFDC2626)])
                            : LinearGradient(colors: [colorMain.withValues(alpha: 0.6), colorMain]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 $unidad', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('${df.format(ingreso)} $unidad', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String val, Color valColor, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 6),
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valColor, letterSpacing: -0.5)),
      ],
    );
  }
}
