import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OrdenesPedidoPage extends StatefulWidget {
  const OrdenesPedidoPage({super.key});

  @override
  State<OrdenesPedidoPage> createState() => _OrdenesPedidoPageState();
}

class _OrdenesPedidoPageState extends State<OrdenesPedidoPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<dynamic> _ordenes = [];
  String _filtroEstado = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarOrdenes();
  }

  Future<void> _cargarOrdenes() async {
    setState(() => _isLoading = true);
    try {
      final req = _supabase
          .from('cotizaciones')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      final data = await req;
      
      setState(() {
        if (_filtroEstado == 'TODOS') {
          _ordenes = data;
        } else {
          _ordenes = data.where((o) => o['estado'] == _filtroEstado || o['estado_facturacion'] == _filtroEstado).toList();
        }
      });
    } catch (e) {
      debugPrint("Error cargando órdenes: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFiltroBtn(String titulo, String valor, IconData icono) {
    final activo = _filtroEstado == valor;
    return InkWell(
      onTap: () {
        setState(() => _filtroEstado = valor);
        _cargarOrdenes();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? const Color(0xFF0F172A) : Colors.grey.shade300),
          boxShadow: activo ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Icon(icono, size: 16, color: activo ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                color: activo ? Colors.white : Colors.grey.shade700,
                fontWeight: activo ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? estado) {
    Color bg = Colors.blue.shade50;
    Color tx = Colors.blue.shade700;
    String lbl = estado ?? 'PENDIENTE';

    if (lbl.contains('FACTURADO')) {
      bg = Colors.green.shade50;
      tx = Colors.green.shade700;
    } else if (lbl == 'ANULADO') {
      bg = Colors.red.shade50;
      tx = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(lbl, style: TextStyle(color: tx, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // HEADER PREMIUM
          Container(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.list_alt_rounded, color: Color(0xFF0F172A), size: 32),
                    SizedBox(width: 12),
                    Text('Órdenes de Pedido', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Gestión centralizada de requerimientos y despachos', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14)),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFiltroBtn('Todas', 'TODOS', Icons.all_inbox_rounded),
                      const SizedBox(width: 12),
                      _buildFiltroBtn('Pendientes', 'PENDIENTE', Icons.pending_actions_rounded),
                      const SizedBox(width: 12),
                      _buildFiltroBtn('Facturadas', 'FACTURADO_FINAL', Icons.check_circle_outline_rounded),
                    ],
                  ),
                )
              ],
            ),
          ),

          // LISTA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _ordenes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 80, color: Colors.blueGrey.shade100),
                            const SizedBox(height: 16),
                            Text('No se encontraron órdenes.', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ).animate().fade()
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _ordenes.length,
                        itemBuilder: (context, index) {
                          final o = _ordenes[index];
                          final nro = o['numero'] ?? o['id'].toString().substring(0,8);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                              ]
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // Ver detalle de la orden
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF475569)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text('ORD-$nro', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                                const SizedBox(width: 12),
                                                _buildStatusBadge(o['estado_facturacion']),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(o['cliente_nombre'] ?? 'Sin cliente', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('S/ ${o['total'] ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                                          const SizedBox(height: 4),
                                          const Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fade(delay: Duration(milliseconds: 30 * index)).slideX(begin: 0.02);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
