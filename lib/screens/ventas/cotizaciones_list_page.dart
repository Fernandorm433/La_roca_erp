// lib/screens/ventas/cotizaciones_list_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/cotizacion_pdf_generator.dart';
import 'cotizacion_pdf_preview.dart';
import 'cotizaciones_page.dart';
import '../home/home_page.dart';
import 'cotizacion_detalle_page.dart';

class CotizacionesListPage extends StatefulWidget {
  final RolUsuario? rol;
  final String? nombreUsuario;

  const CotizacionesListPage({super.key, this.rol, this.nombreUsuario});
  @override
  State<CotizacionesListPage> createState() => _CotizacionesListPageState();
}

class _CotizacionesListPageState extends State<CotizacionesListPage> {
  final _sb = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _all = [], _shown = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _sb.from('cotizaciones')
          .select('*, cotizacion_items(*)')
          .order('created_at', ascending: false);
      setState(() { _all = List<Map<String, dynamic>>.from(d); _shown = _all; });
    } catch (e) { _snack('Error: $e', err: true); }
    finally { setState(() => _loading = false); }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _shown = q.isEmpty ? _all : _all.where((c) =>
      (c['cliente_nombre'] ?? '').toLowerCase().contains(q) ||
      (c['asesor_nombre'] ?? '').toLowerCase().contains(q) ||
      (c['numero_cotizacion'] ?? '').toLowerCase().contains(q)).toList());
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: err ? Colors.red.shade700 : AppColors.primaryDark,
      ));

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar cotización?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.from('cotizacion_items').delete().eq('cotizacion_id', id);
      await _sb.from('cotizaciones').delete().eq('id', id);
      _snack('Cotización eliminada');
      _load();
    } catch (e) { _snack('Error: $e', err: true); }
  }

  Future<void> _pdf(Map<String, dynamic> c) async {
    try {
      final items = (c['cotizacion_items'] as List? ?? []).map((i) => ItemCotizacion(
        tipo: i['tipo'] ?? 'Concreto',
        descripcion: i['descripcion'] ?? '',
        detalles: parseDetalles(i['detalles']),
        cantidad: double.tryParse(i['cantidad'].toString()) ?? 0,
        unidad: i['unidad'] ?? 'M³',
        precioUnitario: double.tryParse(i['precio_unitario'].toString()) ?? 0,
      )).toList();
      final rawItems = c['cotizacion_items'] as List? ?? [];
      final concretoItem = rawItems.firstWhere(
        (i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto',
        orElse: () => rawItems.isNotEmpty ? rawItems.first : null,
      );
      final horaEntregaDt = DateTime.tryParse(c['hora_entrega'] ?? '');
      final fechaCreacion = DateTime.tryParse(c['created_at'] ?? '') ?? DateTime.now();

      final datos = DatosCotizacion(
        numeroCotizacion: c['numero_cotizacion'] ?? '',
        fecha: fechaCreacion,
        fechaVencimiento: fechaCreacion.add(const Duration(days: 30)),
        horaEntrega: horaEntregaDt,
        clienteNombre: c['cliente_nombre'] ?? '',
        clienteDocumento: c['cliente_documento'] ?? '',
        clienteDireccion: c['obra_direccion'] ?? c['cliente_direccion'] ?? '',
        clienteTelefono: c['cliente_telefono'] ?? '',
        asesorNombre: c['asesor_nombre'] ?? '',
        asesorTelefono: c['asesor_telefono'] ?? '',
        contactoObra: c['cliente_nombre'] ?? '',
        contactoTelefono: c['cliente_telefono'] ?? '',
        tipoComprobante: c['tipo_comprobante'] ?? 'Factura',
        formaPago: 'DEPÓSITO',
        fechaVaciado: horaEntregaDt != null ? DateFormat('dd/MM/yyyy').format(horaEntregaDt) : null,
        elementoVaciar: concretoItem?['elemento']?.toString(),
        formaVaciado: (concretoItem?['bombeable'] == true) ? 'BOMBEABLE' : 'DIRECTO',
        igvPorcentaje: double.tryParse(c['igv_porcentaje']?.toString() ?? '18') ?? 18.0,
        subTotalCustom: double.tryParse(c['subtotal']?.toString() ?? ''),
        igvMontoCustom: double.tryParse(c['igv_monto']?.toString() ?? ''),
        totalCustom: double.tryParse(c['total']?.toString() ?? ''),
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
    } catch (e) { _snack('Error PDF: $e', err: true); }
  }

  void _open({Map<String, dynamic>? cot, bool dup = false}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CotizacionesPage(
        cotizacionExistente: dup ? null : cot,
        datosParaDuplicar: dup ? cot : null,
        rol: widget.rol,
        nombreUsuario: widget.nombreUsuario,
      ),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Cotizaciones',
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 26),
            onPressed: () => _open(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Buscador
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.greyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.greyBorder),
                ),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por cliente, asesor o N°...',
                    hintStyle: TextStyle(color: AppColors.grey, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _shown = _shown.reversed.toList()),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.greyBorder),
                ),
                child: const Icon(Icons.swap_vert, color: AppColors.primaryDark, size: 20),
              ),
            ),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
              : _shown.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No hay cotizaciones', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primaryDark,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _shown.length,
                        itemBuilder: (_, i) => _CotCard(
                          cot: _shown[i],
                          onTap: () async {
                            final updated = await Navigator.push<bool>(context, MaterialPageRoute(
                              builder: (_) => CotizacionDetallePage(cotizacion: _shown[i]),
                            ));
                            if (updated == true) _load();
                          },
                          onPDF: () => _pdf(_shown[i]),
                          onDup: () => _open(cot: _shown[i], dup: true),
                          onEdit: () => _open(cot: _shown[i]),
                          onDel: () => _delete(_shown[i]['id']),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ─── CARD ─────────────────────────────────────────────────────────────────────
class _CotCard extends StatelessWidget {
  final Map<String, dynamic> cot;
  final VoidCallback onTap, onPDF, onDup, onEdit, onDel;
  const _CotCard({required this.cot, required this.onTap, required this.onPDF,
      required this.onDup, required this.onEdit, required this.onDel});

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(cot['total']?.toString() ?? '0') ?? 0;
    final estado = cot['estado'] ?? 'borrador';
    final fmt = NumberFormat('#,##0.00', 'es_PE');
    final isDrive = estado == 'aprobada' || estado == 'enviada';

    String creado = '';
    String atencion = '';
    if (cot['created_at'] != null) {
      final dt = DateTime.tryParse(cot['created_at']);
      if (dt != null) creado = 'Creado: ${DateFormat('dd MMM · HH:mm').format(dt.toLocal())}';
    }
    if (cot['hora_entrega'] != null) {
      final dt = DateTime.tryParse(cot['hora_entrega']);
      if (dt != null) atencion = '   Atención: ${DateFormat('dd MMM · HH:mm').format(dt.toLocal())}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDrive ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDrive ? const Color(0xFFBAE6FD) : AppColors.greyBorder,
          width: isDrive ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Text(
              (cot['cliente_nombre'] ?? 'Sin nombre').toString().toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text('Asesor: ${cot['asesor_nombre'] ?? '—'}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.grey)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('${fmt.format(total)} S/',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.primary)),
            const SizedBox(width: 8),
            if (isDrive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                child: const Text('DRIVE',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            _IBtn(icon: Icons.picture_as_pdf_outlined, onTap: onPDF),
            _IBtn(icon: Icons.copy_outlined, onTap: onDup),
            _IBtn(icon: Icons.edit_outlined, onTap: onEdit),
            _IBtn(icon: Icons.delete_outline, color: Colors.red.shade400, onTap: onDel),
          ]),
          const SizedBox(height: 6),
          Text('$creado$atencion', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    ),  // Container
    );  // InkWell
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IBtn({required this.icon, required this.onTap, this.color = const Color(0xFF607D8B)});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Icon(icon, size: 20, color: color),
    ),
  );
}