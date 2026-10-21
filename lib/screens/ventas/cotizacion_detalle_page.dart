import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        detalles: parseDetalles(i['detalles']),
        cantidad: double.tryParse(i['cantidad'].toString()) ?? 0,
        unidad: i['unidad'] ?? 'M³',
        precioUnitario: double.tryParse(i['precio_unitario'].toString()) ?? 0,
      )).toList();
      final concretoItem = _items.firstWhere(
        (i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto',
        orElse: () => _items.isNotEmpty ? _items.first : null,
      );
      final horaEntregaDt = DateTime.tryParse(_cot['hora_entrega'] ?? '');
      final fechaCreacion = DateTime.tryParse(_cot['created_at'] ?? '') ?? DateTime.now();

      double itemsTotal = 0;
      for (var it in items) {
        itemsTotal += it.subtotal;
      }
      double dbTotal = double.tryParse(_cot['total']?.toString() ?? '') ?? itemsTotal;
      if (itemsTotal > 0 && (dbTotal == 0 || (dbTotal > itemsTotal && (dbTotal - itemsTotal) > 0.05))) {
        dbTotal = itemsTotal;
      }
      final igvPct = double.tryParse(_cot['igv_porcentaje']?.toString() ?? '18') ?? 18;
      final subtotal = igvPct > 0 ? ((dbTotal / (1 + igvPct / 100) * 100).roundToDouble() / 100.0) : dbTotal;
      final igvMonto = ((dbTotal - subtotal) * 100).roundToDouble() / 100.0;

      final concretoItems = _items.where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto').toList();
      final elementosStr = concretoItems.map((c) => c['elemento']?.toString() ?? '').where((e) => e.isNotEmpty).toSet().join(' / ');
      final formasVaciadoSet = concretoItems.map((c) => ((c['bombeable'] == true) || (c['tipo_vaciado']?.toString().toUpperCase() == 'BOMBEABLE') || (c['descripcion']?.toString().toUpperCase().contains('BOMBA') ?? false)) ? 'BOMBEABLE' : 'DIRECTO').toSet();
      final formaVaciadoStr = formasVaciadoSet.isNotEmpty ? formasVaciadoSet.join(' / ') : 'DIRECTO';

      final datos = DatosCotizacion(
        numeroCotizacion: _cot['numero_cotizacion'] ?? '',
        fecha: fechaCreacion,
        fechaVencimiento: fechaCreacion.add(const Duration(days: 30)),
        horaEntrega: horaEntregaDt,
        clienteNombre: _cot['cliente_nombre'] ?? '',
        clienteDocumento: _cot['cliente_documento'] ?? '',
        clienteDireccion: _cot['obra_direccion'] ?? _cot['cliente_direccion'] ?? '',
        clienteTelefono: _cot['cliente_telefono'] ?? '',
        asesorNombre: _cot['asesor_nombre'] ?? '',
        asesorTelefono: _cot['asesor_telefono'] ?? '',
        contactoObra: _cot['cliente_nombre'] ?? '',
        contactoTelefono: _cot['cliente_telefono'] ?? '',
        tipoComprobante: _cot['tipo_comprobante'] ?? 'Factura',
        formaPago: 'DEPÓSITO',
        fechaVaciado: horaEntregaDt != null ? DateFormat('dd/MM/yyyy').format(horaEntregaDt) : null,
        elementoVaciar: elementosStr.isNotEmpty ? elementosStr : null,
        formaVaciado: formaVaciadoStr,
        igvPorcentaje: igvPct,
        subTotalCustom: subtotal,
        igvMontoCustom: igvMonto,
        totalCustom: dbTotal,
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
        onGuardar: (DateTime nuevaFecha, Map<String, double> nuevosVolumenes) async {
          await _actualizarRequerimiento(nuevaFecha, nuevosVolumenes);
        },
      ),
    );
  }

  Future<void> _actualizarRequerimiento(DateTime nuevaFecha, Map<String, double> nuevosVolumenes) async {
    setState(() => _loading = true);
    try {
      final cotId = _cot['id'];
      
      // Update each item in cotizacion_items
      for (var entry in nuevosVolumenes.entries) {
        await _sb.from('cotizacion_items').update({
          'cantidad': entry.value,
        }).eq('id', entry.key);
      }
      
      // Recalculate totals with new volumes
      double total = 0;
      for (var item in _items) {
        final itemId = item['id']?.toString() ?? '';
        final cant = nuevosVolumenes[itemId] ?? (double.tryParse(item['cantidad'].toString()) ?? 0);
        final pUnit = double.tryParse(item['precio_unitario'].toString()) ?? 0;
        total += cant * pUnit;
      }
      total = (total * 100).roundToDouble() / 100.0;
      double igvPct = double.tryParse(_cot['igv_porcentaje']?.toString() ?? '18') ?? 18;
      double subtotal = igvPct > 0 ? ((total / (1 + igvPct / 100) * 100).roundToDouble() / 100.0) : total;
      double igvMonto = ((total - subtotal) * 100).roundToDouble() / 100.0;

      // Update cotizaciones
      await _sb.from('cotizaciones').update({
        'hora_entrega': nuevaFecha.toIso8601String(),
        'subtotal': subtotal,
        'igv_monto': igvMonto,
        'total': total,
      }).eq('id', cotId);
      
      // Update ventas_programacion if exists
      final nroCot = (_cot['numero_cotizacion'] ?? '').toString().trim();
      final horaStr = DateFormat('HH:mm').format(nuevaFecha);
      final fechaStr = DateFormat('yyyy-MM-dd').format(nuevaFecha);
      
      if (nroCot.isNotEmpty) {
        // Update fecha y hora for all records with this orden_pedido
        await _sb.from('ventas_programacion').update({
          'fecha_entrega': fechaStr,
          'hora_entrega': horaStr,
        }).eq('orden_pedido', nroCot);

        // Update individual item volumes in ventas_programacion
        final concretoItems = _items.where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto').toList();
        for (int idx = 0; idx < concretoItems.length; idx++) {
          final it = concretoItems[idx];
          final itemId = it['id']?.toString() ?? '';
          if (nuevosVolumenes.containsKey(itemId)) {
            final nuevoVol = nuevosVolumenes[itemId]!;
            final claveUnica = concretoItems.length > 1 ? '$nroCot-ITEM${idx + 1}' : nroCot;
            await _sb.from('ventas_programacion').update({
              'volumen': nuevoVol,
              'volumen_programado': nuevoVol,
            }).eq('clave_unica', claveUnica);
          }
        }
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
    double itemsTotal = 0;
    for (var i in _items) {
      final c = double.tryParse(i['cantidad']?.toString() ?? '0') ?? 0;
      final p = double.tryParse(i['precio_unitario']?.toString() ?? '0') ?? 0;
      itemsTotal += c * p;
    }
    double total = double.tryParse(_cot['total']?.toString() ?? '0') ?? 0;
    if (itemsTotal > 0 && (total == 0 || (total > itemsTotal && (total - itemsTotal) > 0.05))) {
      total = itemsTotal;
    }
    final igvPct = double.tryParse(_cot['igv_porcentaje']?.toString() ?? '18') ?? 18;
    final subtotal = igvPct > 0 ? ((total / (1 + igvPct / 100) * 100).roundToDouble() / 100.0) : total;
    final igvMonto = ((total - subtotal) * 100).roundToDouble() / 100.0;
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, color: AppColors.primaryDark, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _items.where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto').length > 1
                                ? 'Requerimientos Generados (${_items.where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto').length} ítems de concreto)'
                                : 'Requerimiento Generado',
                            style: const TextStyle(color: AppColors.primaryDark,
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

                    // Totales con desglose de IGV
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal (Base Imponible):',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              Text('S/ ${fmt.format(subtotal)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('I.G.V. (${igvPct.toStringAsFixed(0)}%):',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              Text('S/ ${fmt.format(igvMonto)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                            ],
                          ),
                          const Divider(height: 18, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL',
                                  style: TextStyle(color: AppColors.primaryDark,
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('S/ ${fmt.format(total)}',
                                  style: const TextStyle(color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w900, fontSize: 22)),
                            ],
                          ),
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
                      label: Text(
                        _items.where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto').length > 1
                            ? 'GENERAR REQUERIMIENTOS (${_items.where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto').length} ÍTEMS)'
                            : 'GENERAR REQUERIMIENTO',
                        style: const TextStyle(color: Colors.white,
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
    final detalles = parseDetalles(item['detalles']);

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
  final Future<void> Function(DateTime, Map<String, double>) onGuardar;

  const _EditRequerimientoModal({required this.cotizacion, required this.onGuardar});

  @override
  State<_EditRequerimientoModal> createState() => _EditRequerimientoModalState();
}

class _EditRequerimientoModalState extends State<_EditRequerimientoModal> {
  DateTime? _fechaEntrega;
  final Map<String, TextEditingController> _volCtrls = {};
  bool _saving = false;
  List<Map<String, dynamic>> _concretoItems = [];

  @override
  void initState() {
    super.initState();
    _fechaEntrega = DateTime.tryParse(widget.cotizacion['hora_entrega'] ?? '')?.toLocal();
    final items = widget.cotizacion['cotizacion_items'] as List? ?? [];
    _concretoItems = items
        .where((i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto')
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (_concretoItems.isEmpty && items.isNotEmpty) {
      _concretoItems.add(Map<String, dynamic>.from(items.first));
    }
    for (var it in _concretoItems) {
      final id = it['id']?.toString() ?? '';
      _volCtrls[id] = TextEditingController(text: it['cantidad']?.toString() ?? '0');
    }
  }

  @override
  void dispose() {
    for (var c in _volCtrls.values) {
      c.dispose();
    }
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
    if (_fechaEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione la fecha y hora.')));
      return;
    }
    final Map<String, double> vols = {};
    for (var it in _concretoItems) {
      final id = it['id']?.toString() ?? '';
      final v = double.tryParse(_volCtrls[id]?.text ?? '0') ?? 0;
      if (v <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El volumen de "${it['descripcion'] ?? 'Concreto'}" debe ser mayor a 0.')));
        return;
      }
      vols[id] = v;
    }

    setState(() => _saving = true);
    await widget.onGuardar(_fechaEntrega!, vols);
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
            const SizedBox(height: 20),
            
            // Volúmenes de Concreto
            Text(
              _concretoItems.length > 1 ? 'Volúmenes de Concreto (${_concretoItems.length} ítems)' : 'Nuevo Volumen (m³)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ..._concretoItems.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final it = entry.value;
              final id = it['id']?.toString() ?? '';
              final ctrl = _volCtrls[id];
              final diseno = it['resistencia'] != null && it['resistencia'].toString().isNotEmpty
                  ? "F'c=${it['resistencia']}"
                  : (it['descripcion'] ?? '');
              final elem = (it['elemento']?.toString() ?? '').toUpperCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Ítem $idx', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$diseno ${elem.isNotEmpty ? '· $elem' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixText: 'm³',
                        ),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            const SizedBox(height: 24),
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