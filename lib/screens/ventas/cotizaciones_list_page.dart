// lib/screens/ventas/cotizaciones_list_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/cotizacion_pdf_generator.dart';
import 'cotizaciones_page.dart';

class CotizacionesListPage extends StatefulWidget {
  const CotizacionesListPage({super.key});

  @override
  State<CotizacionesListPage> createState() => _CotizacionesListPageState();
}

class _CotizacionesListPageState extends State<CotizacionesListPage> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _cotizaciones = [];
  List<Map<String, dynamic>> _filtradas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase
          .from('cotizaciones')
          .select('*, cotizacion_items(*)')
          .order('created_at', ascending: false);
      setState(() {
        _cotizaciones = List<Map<String, dynamic>>.from(data);
        _filtradas = _cotizaciones;
      });
    } catch (e) {
      _snack('Error al cargar: $e', error: true);
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtradas = q.isEmpty
          ? _cotizaciones
          : _cotizaciones.where((c) {
              return (c['cliente_nombre'] ?? '').toLowerCase().contains(q) ||
                  (c['asesor_nombre'] ?? '').toLowerCase().contains(q) ||
                  (c['numero_cotizacion'] ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF2E7D32),
    ));
  }

  Future<void> _eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar cotización?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supabase.from('cotizacion_items').delete().eq('cotizacion_id', id);
      await _supabase.from('cotizaciones').delete().eq('id', id);
      _snack('Cotización eliminada');
      _cargar();
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _generarPDF(Map<String, dynamic> cot) async {
    try {
      final items = (cot['cotizacion_items'] as List? ?? [])
          .map((i) => ItemCotizacion(
                tipo: i['tipo'] ?? 'Concreto',
                descripcion: i['descripcion'] ?? '',
                detalles: List<String>.from(i['detalles'] ?? []),
                cantidad: double.tryParse(i['cantidad'].toString()) ?? 0,
                unidad: i['unidad'] ?? 'M³',
                precioUnitario: double.tryParse(i['precio_unitario'].toString()) ?? 0,
              ))
          .toList();

      final datos = DatosCotizacion(
        numeroCotizacion: cot['numero_cotizacion'] ?? '',
        fecha: DateTime.tryParse(cot['created_at'] ?? '') ?? DateTime.now(),
        clienteNombre: cot['cliente_nombre'] ?? '',
        clienteDocumento: cot['cliente_documento'] ?? '',
        clienteDireccion: cot['obra_direccion'] ?? cot['cliente_direccion'] ?? '',
        clienteTelefono: cot['cliente_telefono'] ?? '',
        asesorNombre: cot['asesor_nombre'] ?? '',
        asesorTelefono: cot['asesor_telefono'] ?? '',
        igvPorcentaje: double.tryParse(cot['igv_porcentaje'].toString()) ?? 18.0,
        items: items,
      );

      final bytes = await CotizacionPdfGenerator.generar(cotizacion: datos);
      await Printing.sharePdf(bytes: bytes, filename: '${datos.numeroCotizacion}.pdf');
    } catch (e) {
      _snack('Error PDF: $e', error: true);
    }
  }

  void _abrir({Map<String, dynamic>? cotizacion, bool duplicar = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CotizacionesPage(
          cotizacionExistente: duplicar ? null : cotizacion,
          datosParaDuplicar: duplicar ? cotizacion : null,
        ),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text('Cotizaciones',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF2E7D32), size: 28),
            onPressed: () => _abrir(),
          ),
          const SizedBox(width: 8), // Ícono de notificaciones eliminado
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Buscar por cliente...',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_upward, color: Colors.black87),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                : _filtradas.isEmpty
                    ? const Center(child: Text('No hay cotizaciones', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        color: const Color(0xFF2E7D32),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtradas.length,
                          itemBuilder: (_, i) => _CotizacionCard(
                            cot: _filtradas[i],
                            onPDF: () => _generarPDF(_filtradas[i]),
                            onDuplicar: () => _abrir(cotizacion: _filtradas[i], duplicar: true),
                            onEditar: () => _abrir(cotizacion: _filtradas[i]),
                            onEliminar: () => _eliminar(_filtradas[i]['id']),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CotizacionCard extends StatelessWidget {
  final Map<String, dynamic> cot;
  final VoidCallback onPDF, onDuplicar, onEditar, onEliminar;

  const _CotizacionCard({
    required this.cot, required this.onPDF, required this.onDuplicar, required this.onEditar, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(cot['total']?.toString() ?? '0') ?? 0;
    final estado = cot['estado'] ?? 'borrador';
    final fmt = NumberFormat('#,##0.00', 'es_PE');

    final creado = cot['created_at'] != null ? DateFormat("dd MMM · HH:mm", "es").format(DateTime.parse(cot['created_at']).toLocal()) : '-';
    final atencion = cot['hora_entrega'] != null ? DateFormat("dd MMM · HH:mm", "es").format(DateTime.parse(cot['hora_entrega']).toLocal()) : '-';

    final isDestacada = estado == 'aprobada' || estado == 'enviada';
    final cardColor = isDestacada ? const Color(0xFFA5D6A7) : const Color(0xFFF9FBE7);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text((cot['cliente_nombre'] ?? 'Sin nombre').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Asesor: ${cot['asesor_nombre'] ?? '—'}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            if (estado == 'editada')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFB2EBF2), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_note, size: 14, color: Color(0xFF006064)), SizedBox(width: 4),
                  Text('Editada · 1 cambio', style: TextStyle(fontSize: 11, color: Color(0xFF006064), fontWeight: FontWeight.bold)),
                ]),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('${fmt.format(total)} s/', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                    if (isDestacada) ...[
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF424242), borderRadius: BorderRadius.circular(20)), child: const Text('DRIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ]
                  ],
                ),
                Row(
                  children: [
                    _IconBtn(icon: Icons.picture_as_pdf_outlined, onTap: onPDF),
                    _IconBtn(icon: Icons.copy_outlined, onTap: onDuplicar),
                    _IconBtn(icon: Icons.edit_outlined, onTap: onEditar),
                    _IconBtn(icon: Icons.delete_outline, color: Colors.red.shade700, onTap: onEliminar),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Creado: $creado   Atención: $atencion', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _IconBtn({required this.icon, this.color = Colors.black87, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(6), color: Colors.white.withOpacity(0.5)),
      child: Icon(icon, size: 20, color: color),
    ),
  );
}