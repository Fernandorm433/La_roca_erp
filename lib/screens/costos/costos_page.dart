// Archivo: lib/screens/costos/costos_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';

class CostosPage extends StatefulWidget {
  const CostosPage({super.key});
  @override
  State<CostosPage> createState() => _CostosPageState();
}

class _CostosPageState extends State<CostosPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> gastos = [];
  List<Map<String, dynamic>> presupuestos = [];
  List<Map<String, dynamic>> categorias = [];

  bool loadingGastos = true;
  bool loadingPresupuestos = true;
  bool loadingCategorias = true;

  DateTime mesSeleccionado = DateTime.now();

  // Métricas
  double totalGastosMes = 0;
  double totalPresupuestado = 0;
  Map<String, double> gastosPorCategoria = {};

  final List<Color> chartColors = [
    AppColors.accent,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    const Color(0xFF0284C7),
    const Color(0xFF7C3AED),
    const Color(0xFFD97706),
    const Color(0xFF059669),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarGastos(),
      _cargarPresupuestos(),
      _cargarCategorias(),
    ]);
  }

  Future<void> _cargarGastos() async {
    setState(() => loadingGastos = true);
    try {
      final inicio =
          '${mesSeleccionado.year}-${mesSeleccionado.month.toString().padLeft(2, '0')}-01';
      final fin =
          '${mesSeleccionado.year}-${(mesSeleccionado.month + 1).toString().padLeft(2, '0')}-01';
      final data = await supabase
          .from('gastos_operativos')
          .select('*, categorias_costo(nombre, color)')
          .gte('fecha', inicio)
          .lt('fecha', fin)
          .order('fecha', ascending: false);

      if (mounted) {
        setState(() {
          gastos = List<Map<String, dynamic>>.from(data);
          totalGastosMes = gastos.fold(
            0,
            (sum, g) => sum + ((g['monto'] as num?)?.toDouble() ?? 0),
          );
          // Agrupar por categoría
          gastosPorCategoria = {};
          for (final g in gastos) {
            final cat =
                (g['categorias_costo'] as Map<String, dynamic>?)?['nombre'] ??
                g['categoria'] ??
                'Sin categoría';
            gastosPorCategoria[cat] =
                (gastosPorCategoria[cat] ?? 0) +
                ((g['monto'] as num?)?.toDouble() ?? 0);
          }
          loadingGastos = false;
        });
      }
    } catch (e) {
      debugPrint('Error gastos: $e');
      if (mounted) setState(() => loadingGastos = false);
    }
  }

  Future<void> _cargarPresupuestos() async {
    setState(() => loadingPresupuestos = true);
    try {
      final mes =
          '${mesSeleccionado.year}-${mesSeleccionado.month.toString().padLeft(2, '0')}';
      final data = await supabase
          .from('presupuestos_mensuales')
          .select('*, categorias_costo(nombre)')
          .like('periodo', '$mes%');
      if (mounted) {
        setState(() {
          presupuestos = List<Map<String, dynamic>>.from(data);
          totalPresupuestado = presupuestos.fold(
            0,
            (sum, p) =>
                sum + ((p['monto_presupuestado'] as num?)?.toDouble() ?? 0),
          );
          loadingPresupuestos = false;
        });
      }
    } catch (e) {
      debugPrint('Error presupuestos: $e');
      if (mounted) setState(() => loadingPresupuestos = false);
    }
  }

  Future<void> _cargarCategorias() async {
    setState(() => loadingCategorias = true);
    try {
      final data = await supabase
          .from('categorias_costo')
          .select()
          .order('nombre');
      if (mounted) {
        setState(() {
          categorias = List<Map<String, dynamic>>.from(data);
          loadingCategorias = false;
        });
      }
    } catch (e) {
      debugPrint('Error categorías: $e');
      if (mounted) setState(() => loadingCategorias = false);
    }
  }

  Future<void> _registrarGasto() async {
    final descripcionCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final proveedorCtrl = TextEditingController();
    String? categoriaId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Registrar Gasto'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: categorias
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(c['nombre'] ?? '—'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => categoriaId = val,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionCtrl,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto (S/)',
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proveedorCtrl,
                decoration: InputDecoration(
                  labelText: 'Proveedor / Concepto',
                  prefixIcon: const Icon(Icons.store_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              if (categoriaId == null || montoCtrl.text.isEmpty) return;
              try {
                await supabase.from('gastos_operativos').insert({
                  'categoria_id': categoriaId,
                  'descripcion': descripcionCtrl.text.trim(),
                  'monto':
                      double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0,
                  'proveedor': proveedorCtrl.text.trim(),
                  'fecha': DateTime.now().toIso8601String().split('T')[0],
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _cargarGastos();
              } catch (e) {
                debugPrint('Error registrar gasto: $e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  final List<String> _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final porcentajeEjecucion = totalPresupuestado > 0
        ? (totalGastosMes / totalPresupuestado * 100).clamp(0, 999)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Header con KPIs principales
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Control de Costos',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Text(
                                  'Gastos, presupuestos y análisis',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Selector de mes compacto
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: mesSeleccionado.month,
                                isDense: true,
                                items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(_meses[i]),
                                  ),
                                ),
                                onChanged: (m) {
                                  if (m == null) return;
                                  setState(
                                    () => mesSeleccionado = DateTime(
                                      mesSeleccionado.year,
                                      m,
                                    ),
                                  );
                                  _cargarTodo();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tarjetas KPI
                      Row(
                        children: [
                          _kpiCard(
                            'Gastado',
                            'S/ ${_formatMonto(totalGastosMes)}',
                            Icons.trending_down_outlined,
                            AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          _kpiCard(
                            'Presupuesto',
                            'S/ ${_formatMonto(totalPresupuestado)}',
                            Icons.account_balance_wallet_outlined,
                            AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          _kpiCard(
                            'Ejecución',
                            '${porcentajeEjecucion.toStringAsFixed(0)}%',
                            Icons.donut_small_outlined,
                            porcentajeEjecucion > 90
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Barra de progreso presupuestal
                      if (totalPresupuestado > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ejecución presupuestal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Disponible: S/ ${_formatMonto((totalPresupuestado - totalGastosMes).clamp(0, double.infinity))}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (totalGastosMes / totalPresupuestado).clamp(
                              0,
                              1,
                            ),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              porcentajeEjecucion > 90
                                  ? AppColors.error
                                  : porcentajeEjecucion > 70
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            minHeight: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.accent,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.accent,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.receipt_long_outlined),
                        text: 'Gastos',
                      ),
                      Tab(
                        icon: Icon(Icons.pie_chart_outline),
                        text: 'Análisis',
                      ),
                      Tab(
                        icon: Icon(Icons.account_balance_outlined),
                        text: 'Presupuesto',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_tabGastos(), _tabAnalisis(), _tabPresupuesto()],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrarGasto,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Gasto'),
      ),
    );
  }

  // ─── TAB 1: GASTOS ──────────────────────────────────────────────────────────
  Widget _tabGastos() {
    if (loadingGastos) {
      return const Center(child: CircularProgressIndicator());
    }

    return gastos.isEmpty
        ? _emptyState(
            'Sin gastos registrados este mes',
            Icons.receipt_long_outlined,
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gastos.length,
            itemBuilder: (context, i) {
              final g = gastos[i];
              final cat = g['categorias_costo'] as Map<String, dynamic>?;
              final catNombre =
                  cat?['nombre'] ?? g['categoria'] ?? 'Sin categoría';
              final descripcion = g['descripcion'] ?? '—';
              final monto = (g['monto'] as num?)?.toDouble() ?? 0;
              final fecha = g['fecha'] ?? '—';
              final proveedor = g['proveedor'] ?? '';
              final aprobado = g['aprobado'] as bool? ?? false;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _colorCategoria(catNombre).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconCategoria(catNombre),
                          color: _colorCategoria(catNombre),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              descripcion,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _colorCategoria(
                                      catNombre,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    catNombre,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _colorCategoria(catNombre),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  fecha,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            if (proveedor.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                proveedor,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'S/ ${monto.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            aprobado
                                ? Icons.check_circle
                                : Icons.pending_outlined,
                            size: 16,
                            color: aprobado ? AppColors.success : Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: (i * 30).ms);
            },
          );
  }

  // ─── TAB 2: ANÁLISIS ────────────────────────────────────────────────────────
  Widget _tabAnalisis() {
    if (loadingGastos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gastosPorCategoria.isEmpty) {
      return _emptyState(
        'Sin datos para analizar este mes',
        Icons.analytics_outlined,
      );
    }

    final entries = gastosPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gráfico de torta
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribución por Categoría',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: entries.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final e = entry.value;
                        final porcentaje = totalGastosMes > 0
                            ? (e.value / totalGastosMes * 100)
                            : 0.0;
                        return PieChartSectionData(
                          value: e.value,
                          title: '${porcentaje.toStringAsFixed(0)}%',
                          color: chartColors[idx % chartColors.length],
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Leyenda
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final e = entry.value;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: chartColors[idx % chartColors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.05),
          const SizedBox(height: 16),
          // Ranking de categorías
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ranking de Gastos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 16),
                ...entries.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final e = entry.value;
                  final porcentaje = totalGastosMes > 0
                      ? (e.value / totalGastosMes)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor:
                                      chartColors[idx % chartColors.length]
                                          .withOpacity(0.2),
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          chartColors[idx % chartColors.length],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'S/ ${e.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: porcentaje,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              chartColors[idx % chartColors.length],
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(delay: (idx * 50).ms).slideX(begin: 0.05);
                }),
              ],
            ),
          ).animate().fade(delay: 100.ms),
        ],
      ),
    );
  }

  // ─── TAB 3: PRESUPUESTO ─────────────────────────────────────────────────────
  Widget _tabPresupuesto() {
    if (loadingPresupuestos) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Resumen global presupuesto vs ejecutado
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: _resumenItem(
                  'Presupuestado',
                  'S/ ${_formatMonto(totalPresupuestado)}',
                  AppColors.accent,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _resumenItem(
                  'Ejecutado',
                  'S/ ${_formatMonto(totalGastosMes)}',
                  AppColors.error,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _resumenItem(
                  'Disponible',
                  'S/ ${_formatMonto((totalPresupuestado - totalGastosMes).clamp(0, double.infinity))}',
                  AppColors.success,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: presupuestos.isEmpty
              ? _emptyState(
                  'Sin presupuesto configurado para este mes',
                  Icons.account_balance_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: presupuestos.length,
                  itemBuilder: (context, i) {
                    final p = presupuestos[i];
                    final cat = p['categorias_costo'] as Map<String, dynamic>?;
                    final catNombre = cat?['nombre'] ?? 'Sin categoría';
                    final presupuestado =
                        (p['monto_presupuestado'] as num?)?.toDouble() ?? 0;

                    // Buscar cuánto se gastó en esta categoría
                    final ejecutado = gastosPorCategoria[catNombre] ?? 0;
                    final disponible = (presupuestado - ejecutado).clamp(
                      0,
                      double.infinity,
                    );
                    final pct = presupuestado > 0
                        ? (ejecutado / presupuestado).clamp(0, 1)
                        : 0.0;

                    Color barColor = AppColors.success;
                    if (pct > 0.9) {
                      barColor = AppColors.error;
                    } else if (pct > 0.7)
                      barColor = AppColors.warning;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _iconCategoria(catNombre),
                                      color: _colorCategoria(catNombre),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      catNombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: barColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct.toDouble(),
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  barColor,
                                ),
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _miniStat(
                                  'Presup.',
                                  'S/ ${ejecutado.toStringAsFixed(0)}',
                                  Colors.grey.shade600,
                                ),
                                _miniStat(
                                  'Ejecutado',
                                  'S/ ${ejecutado.toStringAsFixed(0)}',
                                  AppColors.error,
                                ),
                                _miniStat(
                                  'Disponible',
                                  'S/ ${disponible.toStringAsFixed(0)}',
                                  AppColors.success,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(delay: (i * 50).ms);
                  },
                ),
        ),
      ],
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  String _formatMonto(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}K';
    return valor.toStringAsFixed(0);
  }

  Color _colorCategoria(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('combustible') || n.contains('gasolina')) {
      return AppColors.warning;
    }
    if (n.contains('mantenimiento') || n.contains('repuesto')) {
      return Colors.orange.shade700;
    }
    if (n.contains('planilla') ||
        n.contains('sueldo') ||
        n.contains('personal')) {
      return AppColors.accent;
    }
    if (n.contains('material') || n.contains('insumo')) {
      return const Color(0xFF0284C7);
    }
    if (n.contains('administrativo') || n.contains('oficina')) {
      return const Color(0xFF7C3AED);
    }
    return Colors.teal;
  }

  IconData _iconCategoria(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('combustible') || n.contains('gasolina')) {
      return Icons.local_gas_station;
    }
    if (n.contains('mantenimiento') || n.contains('repuesto')) {
      return Icons.build_outlined;
    }
    if (n.contains('planilla') ||
        n.contains('sueldo') ||
        n.contains('personal')) {
      return Icons.people_outline;
    }
    if (n.contains('material') || n.contains('insumo')) {
      return Icons.inventory_2_outlined;
    }
    if (n.contains('administrativo') || n.contains('oficina')) {
      return Icons.business_outlined;
    }
    return Icons.receipt_long_outlined;
  }

  Widget _kpiCard(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              titulo,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenItem(String titulo, String valor, Color color) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          titulo,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String mensaje, IconData icono) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            mensaje,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
