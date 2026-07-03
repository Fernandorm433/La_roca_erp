import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_database/services/sunat_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:app_database/core/utils/sunat_pdf_generator.dart';
import 'package:printing/printing.dart';

class FacturacionSunatPage extends StatefulWidget {
  const FacturacionSunatPage({super.key});

  @override
  State<FacturacionSunatPage> createState() => _FacturacionSunatPageState();
}

class _FacturacionSunatPageState extends State<FacturacionSunatPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final SunatService _sunatService = SunatService();
  late TabController _tabController;
  
  bool _isLoading = false;
  List<dynamic> _pendientes = [];
  List<dynamic> _emitidas = [];
  
  // Métricas
  double _totalPendiente = 0.0;
  double _totalFacturadoMes = 0.0;
  int _cantidadPendientes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarOrdenesYMetricas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarOrdenesYMetricas() async {
    setState(() => _isLoading = true);
    try {
      final cotizacionesData = await _supabase.from('cotizaciones').select().order('created_at', ascending: false).limit(100);
      final facturasData = await _supabase.from('facturacion_sunat').select().order('created_at', ascending: false);
      
      final Map<String, dynamic> facturasPorCotizacion = {};
      for (var f in facturasData) {
        if (f['estado_sunat'] == 'ACEPTADO') {
          facturasPorCotizacion[f['cotizacion_id'].toString()] = f;
        }
      }

      double pendiente = 0.0;
      double facturado = 0.0;
      int cantPend = 0;
      List<dynamic> listaPendientes = [];
      List<dynamic> listaEmitidas = [];

      for (var o in cotizacionesData) {
        double total = (o['total'] ?? 0.0).toDouble();
        String estado = o['estado_facturacion'] ?? 'PENDIENTE';
        
        final factura = facturasPorCotizacion[o['id'].toString()];

        if (factura == null) {
          pendiente += total;
          cantPend++;
          listaPendientes.add(o);
        } else {
          facturado += total;
          final map = Map<String, dynamic>.from(o);
          map['factura_data'] = factura;
          listaEmitidas.add(map);
        }
      }

      setState(() {
        _pendientes = listaPendientes;
        _emitidas = listaEmitidas;
        _totalPendiente = pendiente;
        _totalFacturadoMes = facturado;
        _cantidadPendientes = cantPend;
      });
    } catch (e) {
      debugPrint("Error cargando facturación: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _emitirFactura(Map<String, dynamic> orden, bool esAdelantada) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conectando con SUNAT BETA...', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF0F172A)),
    );

    final res = await _sunatService.emitirComprobante(
      tipoDoc: '01', 
      serie: 'F001',
      correlativo: 100, // Idealmente esto vendría del servidor
      clienteDocumento: orden['documento'] ?? '20123456789',
      montoTotal: (orden['total'] ?? 0.0).toDouble(),
      cotizacionId: orden['id'],
      anticipada: esAdelantada,
    );

    if (res != null) {
      await _supabase.from('cotizaciones').update({
        'estado_facturacion': esAdelantada ? 'FACTURADO_ANTICIPADO' : 'FACTURADO_FINAL'
      }).eq('id', orden['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Éxito: ${res['sunat_response']?['mensaje'] ?? 'Comprobante Aceptado'}', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade600),
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

  Future<void> _verPdfFactura(Map<String, dynamic> orden) async {
    final facturaData = orden['factura_data'] ?? {};
    final total = (orden['total'] ?? 0.0).toDouble();
    final subtotal = total / 1.18;
    final igv = total - subtotal;
    final volumen = (orden['volumen'] ?? 0.0).toDouble();
    final unitario = volumen > 0 ? (subtotal / volumen) : 0.0;

    final dataPDF = {
      'tipo_doc': '01',
      'serie_correlativo': 'F001 - ${facturaData['correlativo'] ?? '00000000'}',
      'fecha_emision': (facturaData['created_at'] ?? '').toString().split('T').first,
      'cliente_nombre': orden['cliente_nombre'] ?? '',
      'cliente_documento': orden['documento'] ?? '',
      'cliente_direccion': orden['direccion'] ?? 'Av. Siempre Viva 123',
      'descripcion': 'CONCRETO PRE-MEZCLADO\\nRESISTENCIA ${orden['resistencia'] ?? '175'} KG/CM2\\nBOMBABLE',
      'volumen': volumen.toStringAsFixed(2),
      'unitario': unitario.toStringAsFixed(2),
      'total_item': subtotal.toStringAsFixed(2),
      'subtotal': subtotal,
      'igv': igv,
      'total': total,
    };

    try {
      final pdfBytes = await SunatPdfGenerator.generarFactura(dataPDF);
      await Printing.sharePdf(bytes: pdfBytes, filename: 'FACTURA_${dataPDF['serie_correlativo']}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando PDF: $e')));
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
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
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
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: Colors.indigo.shade700, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tesorería', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Facturación Electrónica', style: TextStyle(color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w900)),
                      ],
                    )
                  ],
                ).animate().fade().slideX(),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMetricCard('Pendiente de Facturar', 'S/ ${_totalPendiente.toStringAsFixed(2)}', Icons.hourglass_empty_rounded, Colors.orange),
                      _buildMetricCard('Facturado (Mes)', 'S/ ${_totalFacturadoMes.toStringAsFixed(2)}', Icons.check_circle_outline_rounded, Colors.green),
                      _buildMetricCard('Órdenes Pendientes', '$_cantidadPendientes', Icons.receipt_rounded, Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF0F172A),
                  tabs: [
                    Tab(text: 'Pendientes (${_pendientes.length})'),
                    Tab(text: 'Emitidas (${_emitidas.length})'),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: PENDIENTES
                      _pendientes.isEmpty 
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 60, color: Colors.green.shade400),
                                  const SizedBox(height: 16),
                                  const Text("Todo está al día", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                  const Text("No hay órdenes pendientes de facturación.", style: TextStyle(color: Colors.grey)),
                                ],
                              ).animate().fade(),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              itemCount: _pendientes.length,
                              itemBuilder: (context, index) {
                                final orden = _pendientes[index];
                                final nroOrden = orden['numero'] ?? orden['id'].toString().substring(0,8);
                                final monto = (orden['total'] ?? 0.0).toDouble();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.request_quote_rounded, color: Colors.amber),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('ORDEN #$nroOrden', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                                  Text('S/ ${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.indigo)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(orden['cliente_nombre'] ?? 'Sin cliente', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  _badge(orden['estado_facturacion'] ?? 'PENDIENTE', Colors.orange),
                                                  const SizedBox(width: 8),
                                                  _badge('Volumen: ${orden['volumen']} m³', Colors.blueGrey),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => _emitirFactura(orden, false),
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                                              child: const Text('Facturar'),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.1);
                              },
                            ),

                      // TAB 2: EMITIDAS
                      _emitidas.isEmpty 
                          ? const Center(child: Text("Aún no hay facturas emitidas", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              itemCount: _emitidas.length,
                              itemBuilder: (context, index) {
                                final orden = _emitidas[index];
                                final facturaData = orden['factura_data'] ?? {};
                                final nroOrden = orden['numero'] ?? orden['id'].toString().substring(0,8);
                                final monto = (orden['total'] ?? 0.0).toDouble();
                                final correlativo = facturaData['correlativo'] ?? '00000000';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.green.shade200),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('F001-$correlativo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                                  Text('S/ ${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text('ORDEN #$nroOrden', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              Text(orden['cliente_nombre'] ?? 'Sin cliente', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        ElevatedButton.icon(
                                          onPressed: () => _verPdfFactura(orden),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                          label: const Text('Ver PDF'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade50,
                                            foregroundColor: Colors.blue.shade700,
                                            elevation: 0,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.1);
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
