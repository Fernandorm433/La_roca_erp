// lib/screens/ventas/cotizacion_detalle_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/cotizacion_pdf_generator.dart';
import 'cotizacion_pdf_preview.dart';
import 'cotizaciones_page.dart';
import 'requerimiento_page.dart';

class CotizacionDetallePage extends StatefulWidget {
  final Map<String, dynamic> cotizacion;
  const CotizacionDetallePage({super.key, required this.cotizacion});

  @override
  State<CotizacionDetallePage> createState() => _CotizacionDetallePageState();
}

class _CotizacionDetallePageState extends State<CotizacionDetallePage> {
  final _sb = Supabase.instance.client;
  late Map<String, dynamic> _cot;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cot = widget.cotizacion;
  }

  List get _items => (_cot['cotizacion_items'] as List? ?? []);
  bool get _tieneRequerimiento => (_cot['estado'] ?? '') == 'enviada';

  Future<void> _abrirRequerimiento() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RequerimientoPage(cotizacion: _cot)),
    );
    if (result == true && mounted) {
      // Recargar cotización actualizada
      setState(() => _loading = true);
      try {
        final d = await _sb.from('cotizaciones')
            .select('*, cotizacion_items(*)')
            .eq('id', _cot['id'])
            .single();
        setState(() => _cot = d);
      } catch (_) {}
      finally { setState(() => _loading = false); }
    }
  }

  Future<void> _generarPdf() async {
    try {
      final items = _items.map((i) => ItemCotizacion(
        tipo: i['tipo'] ?? 'Concreto',
        descripcion: i['descripcion'] ?? '',
        detalles: List<String>.from(i['detalles'] ?? []),
        cantidad: double.tryParse(i['cantidad'].toString()) ?? 0,
        unidad: i['unidad'] ?? 'M³',
        precioUnitario: double.tryParse(i['precio_unitario'].toString()) ?? 0,
      )).toList();
      final datos = DatosCotizacion(
        numeroCotizacion: _cot['numero_cotizacion'] ?? '',
        fecha: DateTime.tryParse(_cot['created_at'] ?? '') ?? DateTime.now(),
        clienteNombre: _cot['cliente_nombre'] ?? '',
        clienteDocumento: _cot['cliente_documento'] ?? '',
        clienteDireccion: _cot['obra_direccion'] ?? '',
        clienteTelefono: _cot['cliente_telefono'] ?? '',
        asesorNombre: _cot['asesor_nombre'] ?? '',
        asesorTelefono: _cot['asesor_telefono'] ?? '',
        igvPorcentaje: double.tryParse(_cot['igv_porcentaje']?.toString() ?? '18') ?? 18,
        items: items,
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CotizacionPdfPreview(cotizacion: datos),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'es_PE');
    final total = double.tryParse(_cot['total']?.toString() ?? '0') ?? 0;
    final fecha = DateTime.tryParse(_cot['created_at'] ?? '')?.toLocal();
    final horaEntrega = DateTime.tryParse(_cot['hora_entrega'] ?? '')?.toLocal();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context, _tieneRequerimiento),
        ),
        title: Text(_cot['numero_cotizacion'] ?? 'Cotización',
            style: const TextStyle(color: AppColors.primaryDark,
                fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryDark),
            onPressed: _generarPdf,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryDark),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => CotizacionesPage(cotizacionExistente: _cot),
              ));
              // Reload
              final d = await _sb.from('cotizaciones')
                  .select('*, cotizacion_items(*)')
                  .eq('id', _cot['id'])
                  .single();
              if (mounted) setState(() => _cot = d);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Estado badge
                    if (_tieneRequerimiento)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle, color: AppColors.primaryDark, size: 16),
                          SizedBox(width: 6),
                          Text('Requerimiento enviado al Drive',
                              style: TextStyle(color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),

                    // Info cliente
                    _Section(title: 'CLIENTE', children: [
                      _Row('Nombre:', _cot['cliente_nombre'] ?? '—'),
                      _Row('Documento:', _cot['cliente_documento'] ?? '—'),
                      _Row('Teléfono:', _cot['cliente_telefono'] ?? '—'),
                      _Row('Asesor:', _cot['asesor_nombre'] ?? '—'),
                      if (fecha != null)
                        _Row('Creado:', DateFormat('dd MMM yyyy · HH:mm').format(fecha)),
                      if (horaEntrega != null)
                        _Row('Entrega:', DateFormat('dd MMM yyyy · HH:mm').format(horaEntrega)),
                    ]),
                    const SizedBox(height: 12),

                    // Dirección obra
                    if ((_cot['obra_direccion'] ?? '').isNotEmpty)
                      _Section(title: 'OBRA', children: [
                        _Row('Dirección:', _cot['obra_direccion'] ?? ''),
                        if ((_cot['obra_distrito'] ?? '').isNotEmpty)
                          _Row('Distrito:', _cot['obra_distrito'] ?? ''),
                      ]),
                    if ((_cot['obra_direccion'] ?? '').isNotEmpty) const SizedBox(height: 12),

                    // Items
                    const Text('PRODUCTOS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark, letterSpacing: .8)),
                    const SizedBox(height: 8),
                    ..._items.map((i) => _ItemTile(item: i, fmt: fmt)),
                    const SizedBox(height: 12),

                    // Total
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('S/ ${fmt.format(total)}',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w900, fontSize: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),

              // Botón inferior fijo
              if (!_tieneRequerimiento)
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                      label: const Text('GENERAR REQUERIMIENTO',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: _abrirRequerimiento,
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: AppColors.primaryDark, size: 20),
                      SizedBox(width: 8),
                      Text('Requerimiento ya enviado',
                          style: TextStyle(color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

// ─── WIDGETS ──────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
        color: AppColors.primaryDark, letterSpacing: .8)),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  ]);
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label ', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1A2E1A), fontWeight: FontWeight.w600))),
    ]),
  );
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat fmt;
  const _ItemTile({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cant = double.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
    final precio = double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0;
    final sub = cant * precio;
    final detalles = List<String>.from(item['detalles'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['descripcion'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2E1A))),
        if (detalles.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...detalles.map((d) => Text('• $d',
              style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${cant.toStringAsFixed(cant.truncateToDouble() == cant ? 0 : 1)} ${item['unidad'] ?? ''} × S/ ${fmt.format(precio)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('S/ ${fmt.format(sub)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
        ]),
      ]),
    );
  }
}