import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

enum FiltroTiempo { dia, semana, mes, ano }

class ComparativaConsumosPage extends StatefulWidget {
  const ComparativaConsumosPage({super.key});

  @override
  State<ComparativaConsumosPage> createState() => _ComparativaConsumosPageState();
}

class _ComparativaConsumosPageState extends State<ComparativaConsumosPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  FiltroTiempo _filtroActual = FiltroTiempo.dia;

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
          _ingresoArena += cant; 
        } else if (desc.contains('PIEDRA')) {
          _ingresoPiedra += cant; 
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
        title: const Text('Dashboard Analítico', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Resumen Global - Gráfico Moderno
                      _buildChartSection().animate().fade(duration: 400.ms).slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      
                      const Text('DESGLOSE DE MATERIALES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF64748B), letterSpacing: 1.0)),
                      const SizedBox(height: 16),
                      
                      _buildModernCard('Cemento (Big Bags)', _ingresoCementoBags, _consumoCementoBags, 'Bolsas', Icons.shopping_bag, const Color(0xFF0F172A))
                          .animate().fade(delay: 100.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildModernCard('Arena (KG)', _ingresoArena, _consumoArena, 'KG', Icons.grain, const Color(0xFFD97706))
                          .animate().fade(delay: 200.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildModernCard('Piedra Chancada (KG)', _ingresoPiedra, _consumoPiedra, 'KG', Icons.terrain, const Color(0xFF475569))
                          .animate().fade(delay: 300.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildModernCard('Aditivo (LT)', _ingresoAditivo, _consumoAditivo, 'LT', Icons.water_drop, const Color(0xFF8B5CF6))
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
          ],
        ),
      ),
    );
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
          gradient: act ? const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]) : null,
          color: act ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: act ? [const BoxShadow(color: Color(0x330F172A), blurRadius: 8, offset: Offset(0, 4))] : [],
        ),
        child: Text(label, style: TextStyle(color: act ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildChartSection() {
    // Normalizar datos para el gráfico (porcentajes de salud de stock)
    double percCemento = _ingresoCementoBags > 0 ? (_consumoCementoBags / _ingresoCementoBags) : 0;
    double percArena = _ingresoArena > 0 ? (_consumoArena / _ingresoArena) : 0;
    double percPiedra = _ingresoPiedra > 0 ? (_consumoPiedra / _ingresoPiedra) : 0;
    double percAditivo = _ingresoAditivo > 0 ? (_consumoAditivo / _ingresoAditivo) : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.insights, color: Color(0xFF2563EB), size: 20)),
              const SizedBox(width: 12),
              const Text('Nivel de Consumo vs Ingreso', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.2, // Dejar espacio arriba para que el 100% no toque el techo
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (double value, TitleMeta meta) {
                      const style = TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 10);
                      String text;
                      switch (value.toInt()) {
                        case 0: text = 'CEM'; break;
                        case 1: text = 'ARE'; break;
                        case 2: text = 'PIE'; break;
                        case 3: text = 'ADI'; break;
                        default: text = ''; break;
                      }
                      return SideTitleWidget(meta: meta, space: 10, child: Text(text, style: style));
                    }),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false, 
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1, dashArray: [5, 5])
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, percCemento, const Color(0xFF0F172A)),
                  _makeBarGroup(1, percArena, const Color(0xFFD97706)),
                  _makeBarGroup(2, percPiedra, const Color(0xFF475569)),
                  _makeBarGroup(3, percAditivo, const Color(0xFF8B5CF6)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Área gris = Ingreso total (Capacidad)', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    // Si consumo es mayor a 1, clamp a 1.2 para el gráfico pero pintar de rojo oscuro para alertar
    double val = y > 1.1 ? 1.1 : y; 
    Color barColor = y > 1.0 ? const Color(0xFFEF4444) : color; // Rojo si consumió más de lo que ingresó
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: val,
          color: barColor,
          width: 22,
          borderRadius: BorderRadius.circular(6),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 1.0, // Representa el Ingreso Total
            color: const Color(0xFFF1F5F9),
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
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.5)),
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
                    widthFactor: ingreso <= 0 ? 0 : (consumo / ingreso).clamp(0.0, 1.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [colorMain.withValues(alpha: 0.6), colorMain]),
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
