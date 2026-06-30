import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class CajaChicaPage extends StatefulWidget {
  const CajaChicaPage({super.key});

  @override
  State<CajaChicaPage> createState() => _CajaChicaPageState();
}

class _CajaChicaPageState extends State<CajaChicaPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _movimientos = [];
  
  double get _totalIngresos => _movimientos.where((m) => m['tipo'] == 'INGRESO').fold(0.0, (s, m) => s + (m['monto'] as num).toDouble());
  double get _totalSalidas => _movimientos.where((m) => m['tipo'] == 'SALIDA').fold(0.0, (s, m) => s + (m['monto'] as num).toDouble());
  double get _saldoCajaChica => _totalIngresos - _totalSalidas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await _sb.from('tesoreria_caja_chica').select().order('fecha', ascending: false);
      if (mounted) setState(() {
        _movimientos = List<Map<String, dynamic>>.from(res);
        // Retrocompatibilidad: Si un registro antiguo no tiene 'tipo', asumimos SALIDA
        for (var m in _movimientos) {
          if (m['tipo'] == null) {
            m['tipo'] = 'SALIDA';
          }
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirFormulario() {
    final formKey = GlobalKey<FormState>();
    String tipo = 'SALIDA'; // Por defecto salidas para caja chica
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final respCtrl = TextEditingController();

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
                const Text('Registro manual en Caja Chica', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                            color: tipo == 'SALIDA' ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(color: tipo == 'SALIDA' ? const Color(0xFFF59E0B) : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('SALIDA (-)', style: TextStyle(fontWeight: FontWeight.bold, color: tipo == 'SALIDA' ? const Color(0xFFF59E0B) : Colors.grey))),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: respCtrl,
                  decoration: InputDecoration(
                    labelText: 'Responsable', 
                    prefixIcon: const Icon(Icons.person_outline),
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
                      await _sb.from('tesoreria_caja_chica').insert({
                        'tipo': tipo,
                        'monto': double.parse(montoCtrl.text),
                        'descripcion': descCtrl.text,
                        'responsable': respCtrl.text,
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('HISTORIAL DE CAJA CHICA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF64748B), letterSpacing: 1.0)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        label: const Text('NUEVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: _abrirFormulario,
                      ),
                    ],
                  ).animate().fade(delay: 100.ms),
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
                  return _buildTransactionCard(m).animate().fade(delay: (100 + (i * 50)).ms).slideX(begin: 0.05);
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
    final bool balanceNegativo = _saldoCajaChica < 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x40D97706), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo Actual Caja Chica', style: TextStyle(color: Color(0xFFFEF3C7), fontWeight: FontWeight.bold, fontSize: 13)),
              Icon(Icons.savings_outlined, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'S/ ${df.format(_saldoCajaChica)}',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: balanceNegativo ? const Color(0xFF7F1D1D) : Colors.white, letterSpacing: -1.0),
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
                      const Row(children: [Icon(Icons.arrow_downward, color: Colors.white, size: 16), SizedBox(width: 6), Text('REPOSICIÓN (+)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
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
                      const Row(children: [Icon(Icons.arrow_upward, color: Color(0xFF7F1D1D), size: 16), SizedBox(width: 6), Text('GASTOS (-)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
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

  Widget _buildTransactionCard(Map<String, dynamic> m) {
    final df = NumberFormat('#,##0.00', 'en_US');
    final esIngreso = m['tipo'] == 'INGRESO';

    Color iconBgColor = esIngreso ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
    Color iconColor = esIngreso ? const Color(0xFF10B981) : const Color(0xFFD97706);
    IconData iconData = esIngreso ? Icons.arrow_downward_rounded : Icons.receipt_long;

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
              if (m['responsable'] != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.person, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(m['responsable'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
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
