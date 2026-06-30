import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_database/services/sunat_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FacturacionSunatPage extends StatefulWidget {
  const FacturacionSunatPage({super.key});

  @override
  State<FacturacionSunatPage> createState() => _FacturacionSunatPageState();
}

class _FacturacionSunatPageState extends State<FacturacionSunatPage> {
  final _supabase = Supabase.instance.client;
  final SunatService _sunatService = SunatService();
  bool _isLoading = false;
  List<dynamic> _ordenes = [];
  
  // Métricas
  double _totalPendiente = 0.0;
  double _totalFacturadoMes = 0.0;
  int _cantidadPendientes = 0;

  @override
  void initState() {
    super.initState();
    _cargarOrdenesYMetricas();
  }

  Future<void> _cargarOrdenesYMetricas() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('cotizaciones')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
          
      double pendiente = 0.0;
      double facturado = 0.0;
      int cantPend = 0;
      List<dynamic> listaPendientes = [];

      for (var o in data) {
        double total = (o['total'] ?? 0.0).toDouble();
        String estado = o['estado_facturacion'] ?? 'PENDIENTE';
        
        if (estado != 'FACTURADO_FINAL') {
          pendiente += total;
          cantPend++;
          listaPendientes.add(o);
        } else {
          facturado += total;
        }
      }

      setState(() {
        _ordenes = listaPendientes;
        _totalPendiente = pendiente;
        _totalFacturadoMes = facturado;
        _cantidadPendientes = cantPend;
      });
    } catch (e) {
      debugPrint("Error cargando facturación: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _emitirFactura(Map<String, dynamic> orden, bool esAdelantada) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conectando con SUNAT BETA...', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF0F172A)),
    );

    final res = await _sunatService.emitirComprobante(
      tipoDoc: '01', 
      serie: 'F001',
      correlativo: 100, 
      clienteDocumento: orden['documento'] ?? '20123456789',
      montoTotal: (orden['total'] ?? 0.0).toDouble(),
    );

    if (res != null) {
      await _supabase.from('cotizaciones').update({
        'estado_facturacion': esAdelantada ? 'FACTURADO_ANTICIPADO' : 'FACTURADO_FINAL'
      }).eq('id', orden['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Éxito: ${res['sunat_response']?['mensaje']}', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade600),
        );
      }
      _cargarOrdenesYMetricas();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al emitir comprobante'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // DASHBOARD HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 0, 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildMetricCard('Total por Facturar', 'S/ ${_totalPendiente.toStringAsFixed(2)}', Icons.pending_actions_rounded, Colors.orange.shade700),
                  _buildMetricCard('Pendientes', '$_cantidadPendientes Docs', Icons.receipt_long_rounded, Colors.blue.shade700),
                  _buildMetricCard('Facturado (Mes)', 'S/ ${_totalFacturadoMes.toStringAsFixed(2)}', Icons.check_circle_rounded, Colors.green.shade700),
                  const SizedBox(width: 8), // Extra padding al final
                ],
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Documentos Pendientes de Emisión (SUNAT)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _ordenes.isEmpty 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                              child: Icon(Icons.verified_rounded, size: 60, color: Colors.green.shade400),
                            ),
                            const SizedBox(height: 24),
                            const Text("Todo está al día", style: TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text("No hay órdenes pendientes de facturar en este momento.", style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                          ],
                        ).animate().fade().scale(duration: 400.ms),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemCount: _ordenes.length,
                        itemBuilder: (context, index) {
                          final orden = _ordenes[index];
                          final estadoFac = orden['estado_facturacion'] ?? 'PENDIENTE';
                          final nroOrden = orden['numero'] ?? orden['id'].toString().substring(0,8);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                              ],
                              border: Border.all(color: const Color(0xFFE2E8F0))
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: const Color(0xFF0F172A).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.request_quote_rounded, color: Color(0xFF0F172A), size: 28),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              children: [
                                                Text('ORDEN #$nroOrden', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                                  child: Text('Pendiente', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 10)),
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(orden['cliente_nombre'] ?? 'Cliente no registrado', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Monto a Facturar', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                          Text('S/ ${orden['total'] ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _emitirFactura(orden, true),
                                        icon: const Icon(Icons.business_center, size: 16),
                                        label: const Text('Anticipo Corp.'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade700, side: BorderSide(color: Colors.orange.shade200),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _emitirFactura(orden, false),
                                        icon: const Icon(Icons.receipt, size: 16),
                                        label: const Text('Emitir Factura'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
