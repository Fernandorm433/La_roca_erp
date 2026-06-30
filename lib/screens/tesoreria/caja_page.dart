import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class CajaPage extends StatefulWidget {
  const CajaPage({super.key});

  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _movimientos = [];
  
  double get _totalIngresos => _movimientos.where((m) => m['tipo'] == 'INGRESO').fold(0.0, (s, m) => s + m['monto']);
  double get _totalSalidas => _movimientos.where((m) => m['tipo'] == 'SALIDA').fold(0.0, (s, m) => s + m['monto']);
  double get _totalSalidasLogistica => _movimientos.where((m) => m['tipo'] == 'SALIDA' && m['origen'] == 'LOGISTICA').fold(0.0, (s, m) => s + m['monto']);
  double get _totalSalidasManuales => _movimientos.where((m) => m['tipo'] == 'SALIDA' && m['origen'] == 'MANUAL').fold(0.0, (s, m) => s + m['monto']);
  
  double get _saldoCaja => _totalIngresos - _totalSalidas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final manualRes = await _sb.from('tesoreria_caja').select();
      final logisticaRes = await _sb.from('recepcion_materiales').select();

      List<Map<String, dynamic>> fusionados = [];

      for(var m in manualRes) {
        fusionados.add({
          'id': m['id'],
          'fecha': m['fecha'].toString(),
          'tipo': m['tipo'],
          'monto': (m['monto'] as num).toDouble(),
          'descripcion': m['descripcion'],
          'origen': 'MANUAL',
        });
      }

      for(var m in logisticaRes) {
        double monto = (m['total'] as num).toDouble();
        if (monto > 0) {
          fusionados.add({
            'id': m['id'],
            'fecha': m['fecha'].toString(),
            'tipo': 'SALIDA',
            'monto': monto,
            'descripcion': 'Agregados: ${m['descripcion']}',
            'origen': 'LOGISTICA',
          });
        }
      }

      fusionados.sort((a,b) => b['fecha'].toString().compareTo(a['fecha'].toString()));

      if (mounted) {
        setState(() {
          _movimientos = fusionados;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirFormulario() {
    final formKey = GlobalKey<FormState>();
    String tipo = 'INGRESO';
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (context, setStateModal) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                const Text('Nuevo Movimiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                const Text('Registro manual en Caja General', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),
                
                // Toggle Tipo Moderno
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setStateModal(() => tipo = 'INGRESO'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: tipo == 'INGRESO' ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(color: tipo == 'INGRESO' ? const Color(0xFF10B981) : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('INGRESO (+)', style: TextStyle(fontWeight: FontWeight.bold, color: tipo == 'INGRESO' ? const Color(0xFF10B981) : Colors.grey))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setStateModal(() => tipo = 'SALIDA'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: tipo == 'SALIDA' ? const Color(0xFFEF4444).withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(color: tipo == 'SALIDA' ? const Color(0xFFEF4444) : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('SALIDA (-)', style: TextStyle(fontWeight: FontWeight.bold, color: tipo == 'SALIDA' ? const Color(0xFFEF4444) : Colors.grey))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Monto (S/)', 
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC)
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Descripción / Motivo', 
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC)
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A), 
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await _sb.from('tesoreria_caja').insert({
                        'tipo': tipo,
                        'monto': double.parse(montoCtrl.text),
                        'descripcion': descCtrl.text,
                      });
                      if (context.mounted) Navigator.pop(context);
                      _cargar();
                    },
                    child: const Text('GUARDAR MOVIMIENTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMainBalanceCard().animate().fade().slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  _buildStatsRow().animate().fade(delay: 100.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('HISTORIAL DE MOVIMIENTOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF64748B), letterSpacing: 1.0)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        label: const Text('NUEVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: _abrirFormulario,
                      ),
                    ],
                  ).animate().fade(delay: 200.ms),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final m = _movimientos[i];
                  return _buildTransactionCard(m).animate().fade(delay: (200 + (i * 50)).ms).slideX(begin: 0.05);
                },
                childCount: _movimientos.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildMainBalanceCard() {
    final df = NumberFormat('#,##0.00', 'en_US');
    final bool balanceNegativo = _saldoCaja < 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x400F172A), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo Actual Caja General', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13)),
              Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'S/ ${df.format(_saldoCaja)}',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: balanceNegativo ? const Color(0xFFFCA5A5) : Colors.white, letterSpacing: -1.0),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.arrow_downward, color: Color(0xFF34D399), size: 16), SizedBox(width: 6), Text('INGRESOS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 4),
                      Text('S/ ${df.format(_totalIngresos)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.arrow_upward, color: Color(0xFFF87171), size: 16), SizedBox(width: 6), Text('SALIDAS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 4),
                      Text('S/ ${df.format(_totalSalidas)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    double sumSalidas = _totalSalidas == 0 ? 1 : _totalSalidas;
    double pctLogistica = (_totalSalidasLogistica / sumSalidas) * 100;
    double pctManual = (_totalSalidasManuales / sumSalidas) * 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.pie_chart_rounded, color: Color(0xFFD97706), size: 20)),
              const SizedBox(width: 12),
              const Text('Distribución de Egresos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(color: const Color(0xFF3B82F6), value: pctLogistica, title: '${pctLogistica.toStringAsFixed(0)}%', radius: 20, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(color: const Color(0xFFEF4444), value: pctManual, title: '${pctManual.toStringAsFixed(0)}%', radius: 20, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPieLegend(const Color(0xFF3B82F6), 'Logística y Agregados', 'Automático'),
                    const SizedBox(height: 12),
                    _buildPieLegend(const Color(0xFFEF4444), 'Gastos Operativos', 'Manual'),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPieLegend(Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        )
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> m) {
    final df = NumberFormat('#,##0.00', 'en_US');
    final esIngreso = m['tipo'] == 'INGRESO';
    final esLogistica = m['origen'] == 'LOGISTICA';

    Color iconBgColor;
    Color iconColor;
    IconData iconData;

    if (esIngreso) {
      iconBgColor = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF10B981);
      iconData = Icons.arrow_downward_rounded;
    } else {
      if (esLogistica) {
        iconBgColor = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.local_shipping_rounded;
      } else {
        iconBgColor = const Color(0xFFFEF2F2);
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.arrow_upward_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(m['descripcion'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(m['fecha'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
              if (esLogistica) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(4)),
                  child: const Text('AUTO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                ),
              ]
            ],
          ),
        ),
        trailing: Text(
          '${esIngreso ? '+' : '-'} S/ ${df.format(m['monto'])}',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: iconColor),
        ),
      ),
    );
  }
}
