import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GananciasPage extends StatefulWidget {
  const GananciasPage({super.key});

  @override
  State<GananciasPage> createState() => _GananciasPageState();
}

class _GananciasPageState extends State<GananciasPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  
  double _totalIngresosTesoreria = 0;
  double _totalEgresosTesoreria = 0;
  double _totalGastosOperativos = 0;
  double _totalFacturadoRecepcion = 0;
  
  @override
  void initState() {
    super.initState();
    _cargarDatosMesActual();
  }

  Future<void> _cargarDatosMesActual() async {
    setState(() => _loading = true);
    try {
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1).toIso8601String().split('T')[0];
      
      // 1. Tesorería
      final resTesoreria = await _sb.from('tesoreria_caja').select().gte('fecha', inicioMes);
      for (final row in resTesoreria) {
        final monto = (row['monto'] as num).toDouble();
        if (row['tipo'] == 'INGRESO') _totalIngresosTesoreria += monto;
        else _totalEgresosTesoreria += monto;
      }
      
      // 2. Gastos Operativos (Módulo Costos)
      final resGastos = await _sb.from('gastos_operativos').select('monto').gte('fecha', inicioMes);
      for (final row in resGastos) {
        _totalGastosOperativos += (row['monto'] as num).toDouble();
      }
      
      // 3. Facturado (Recepción Materiales)
      final resRecepcion = await _sb.from('recepcion_materiales').select('total').gte('fecha', inicioMes);
      for (final row in resRecepcion) {
        _totalFacturadoRecepcion += (row['total'] as num).toDouble();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error cargando ganancias: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    final gananciaNeta = (_totalIngresosTesoreria + _totalFacturadoRecepcion) - (_totalEgresosTesoreria + _totalGastosOperativos);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RESUMEN FINANCIERO DEL MES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          
          // Ganancia Neta Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GANANCIA NETA ESTIMADA', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('S/ ${gananciaNeta.toStringAsFixed(2)}', style: TextStyle(color: gananciaNeta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Desglose
          const Text('DESGLOSE DE MOVIMIENTOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          _itemDesglose('Ingresos Caja General', _totalIngresosTesoreria, true),
          _itemDesglose('Facturado Recepciones', _totalFacturadoRecepcion, true),
          const Divider(),
          _itemDesglose('Egresos Caja General', _totalEgresosTesoreria, false),
          _itemDesglose('Gastos Operativos (Costos)', _totalGastosOperativos, false),
        ],
      ),
    );
  }

  Widget _itemDesglose(String titulo, double monto, bool esIngreso) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(esIngreso ? Icons.trending_up : Icons.trending_down, color: esIngreso ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              const SizedBox(width: 12),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ],
          ),
          Text(
            '${esIngreso ? '+' : '-'} S/ ${monto.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: esIngreso ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }
}
