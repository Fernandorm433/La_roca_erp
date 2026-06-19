import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
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

  void _mostrarBottomEdicion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRequerimientoModal(
        cotizacion: _cot,
        onGuardar: (DateTime nuevaFecha, double nuevoVolumen) async {
          await _actualizarRequerimiento(nuevaFecha, nuevoVolumen);
        },
      ),
    );
  }

  Future<void> _actualizarRequerimiento(DateTime nuevaFecha, double nuevoVolumen) async {
    setState(() => _loading = true);
    try {
      final cotId = _cot['id'];
      
      // Update cotizacion_items (only 'Concreto')
      final concretoItem = _items.firstWhere((i) => i['tipo'] == 'Concreto', orElse: () => null);
      if (concretoItem != null) {
        await _sb.from('cotizacion_items').update({
          'cantidad': nuevoVolumen,
        }).eq('id', concretoItem['id']);
      }
      
      // Recalculate totals
      double subtotal = 0;
      for (var item in _items) {
        if (item['tipo'] == 'Concreto') {
          double pUnit = double.tryParse(item['precio_unitario'].toString()) ?? 0;
          subtotal += nuevoVolumen * pUnit;
        } else {
          double cant = double.tryParse(item['cantidad'].toString()) ?? 0;
          double pUnit = double.tryParse(item['precio_unitario'].toString()) ?? 0;
          subtotal += cant * pUnit;
        }
      }
      double igvPct = double.tryParse(_cot['igv_porcentaje']?.toString() ?? '18') ?? 18;
      double igvMonto = subtotal * (igvPct / 100);
      double total = subtotal + igvMonto;

      // Update cotizaciones
      await _sb.from('cotizaciones').update({
        'hora_entrega': nuevaFecha.toIso8601String(),
        'subtotal': subtotal,
        'igv_monto': igvMonto,
        'total': total,
      }).eq('id', cotId);
      
      // Update ventas_programacion if exists
      final oldFechaStr = DateTime.tryParse(_cot['hora_entrega'] ?? '')?.toIso8601String().split('T')[0];
      
      if (oldFechaStr != null) {
        final ventas = await _sb.from('ventas_programacion')
            .select()
            .eq('fecha_entrega', oldFechaStr)
            .ilike('nombre_razon_social', _cot['cliente_nombre'] ?? '')
            .limit(1);
            
        if (ventas.isNotEmpty) {
           final idVenta = ventas[0]['id'];
           final horaStr = DateFormat('HH:mm:ss').format(nuevaFecha);
           final fechaStr = DateFormat('yyyy-MM-dd').format(nuevaFecha);
           await _sb.from('ventas_programacion').update({
             'fecha_entrega': fechaStr,
             'hora_entrega': horaStr,
             'volumen': nuevoVolumen,
           }).eq('id', idVenta);
        }
      }

      // Send to Drive
      try {
        final params = {
          'asesor': _cot['asesor_nombre'] ?? '',
          'day': DateFormat('dd/MM/yyyy').format(nuevaFecha),
          'hour': DateFormat('HH:mm').format(nuevaFecha),
          'client': (_cot['cliente_nombre'] ?? '').toString().toUpperCase(),
          'tipoDocumento': _cot['tipo_comprobante'] ?? 'Factura',
          'document': _cot['cliente_documento'] ?? '',
          'address': _cot['obra_direccion'] ?? '',
          'phone': _cot['cliente_telefono'] ?? '',
          'distrito': _cot['obra_distrito'] ?? '',
          'volumen': nuevoVolumen.toString(),
          'fuerza': concretoItem != null ? (concretoItem['resistencia']?.toString().isNotEmpty == true ? "F'c=${concretoItem['resistencia']}" : concretoItem['descripcion'] ?? '') : '',
          'elemento': concretoItem?['elemento'] ?? '',
          'huso': concretoItem?['huso'] ?? '',
          'slump': concretoItem?['slump'] ?? '',
          'aditivo': concretoItem?['aditivo'] ?? '',
          'cemento': concretoItem?['tipo_cemento'] ?? '',
          'bombas': '',
          'extensiones': '',
          'selectedMixer': '',
          'selectedCapacity': '',
          'time': DateFormat('HH:mm').format(nuevaFecha),
          'quality': '',
          'commentReturn': 'MODIFICADO DESDE APP',
          'location': _cot['obra_maps_link'] ?? '',
          'urlVoucher': '',
          'emisionReq': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
          'observaciones': 'EDICIÓN',
        };

        final body = params.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');

        const gasUrl = 'https://script.google.com/macros/s/AKfycbzKlmfOBqCQSewWueYIdBwvjj_RP7uUty2qGRjGeS3i1XrS3a0qiLeUMl8I8SfT3ut2Fg/exec';
        
        await http.post(Uri.parse(gasUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: body);
      } catch (e) {
        debugPrint('Error enviando a Drive: $e');
      }
      
      // Reload
      final d = await _sb.from('cotizaciones')
          .select('*, cotizacion_items(*)')
          .eq('id', cotId)
          .single();
      if (mounted) setState(() => _cot = d);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Requerimiento actualizado correctamente ✅'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF39C12), // Accent orange for edit
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit_calendar, color: Colors.white),
                      label: const Text('MODIFICAR REQUERIMIENTO',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: _mostrarBottomEdicion,
                    ),
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

// ─── BOTTOM SHEET EDICIÓN REQUERIMIENTO ──────────────────────────────────────────
class _EditRequerimientoModal extends StatefulWidget {
  final Map<String, dynamic> cotizacion;
  final Future<void> Function(DateTime, double) onGuardar;

  const _EditRequerimientoModal({required this.cotizacion, required this.onGuardar});

  @override
  State<_EditRequerimientoModal> createState() => _EditRequerimientoModalState();
}

class _EditRequerimientoModalState extends State<_EditRequerimientoModal> {
  DateTime? _fechaEntrega;
  final _volCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fechaEntrega = DateTime.tryParse(widget.cotizacion['hora_entrega'] ?? '')?.toLocal();
    final items = widget.cotizacion['cotizacion_items'] as List? ?? [];
    final concretoItem = items.firstWhere((i) => i['tipo'] == 'Concreto', orElse: () => null);
    if (concretoItem != null) {
      _volCtrl.text = concretoItem['cantidad']?.toString() ?? '0';
    }
  }

  @override
  void dispose() {
    _volCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaHora() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryDark)),
        child: child!,
      ),
    );
    if (f == null || !mounted) return;
    
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaEntrega ?? DateTime.now()),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryDark)),
        child: child!,
      ),
    );
    if (h == null || !mounted) return;
    
    setState(() {
      _fechaEntrega = DateTime(f.year, f.month, f.day, h.hour, h.minute);
    });
  }

  Future<void> _guardar() async {
    final vol = double.tryParse(_volCtrl.text) ?? 0;
    if (_fechaEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione la fecha y hora.')));
      return;
    }
    if (vol <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El volumen debe ser mayor a 0.')));
      return;
    }

    setState(() => _saving = true);
    await widget.onGuardar(_fechaEntrega!, vol);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24, left: 24, right: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Modificar Requerimiento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fecha y hora
            const Text('Nueva Fecha y Hora de Entrega', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _seleccionarFechaHora,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_month, color: AppColors.primaryDark, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _fechaEntrega != null ? DateFormat('dd MMM yyyy · HH:mm').format(_fechaEntrega!) : 'Seleccione...',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, color: Colors.grey, size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            
            // Volumen
            const Text('Nuevo Volumen (m³)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _volCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixText: 'm³',
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _guardar,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}