// lib/screens/ventas/requerimiento_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/notificacion_service.dart';

class RequerimientoPage extends StatefulWidget {
  final Map<String, dynamic> cotizacion;
  const RequerimientoPage({super.key, required this.cotizacion});
  @override
  State<RequerimientoPage> createState() => _RequerimientoPageState();
}

class _RequerimientoPageState extends State<RequerimientoPage> {
  int _paso = 0;
  DateTime _fecha = DateTime.now();
  final _bombas = <String, bool>{
    'CBP21': false, 'CBP17': false, 'CBP16': false,
    'CBP15': false, 'CBP13': false, 'CBP12': false, 'BE12': false,
  };
  bool _extensiones = false;
  String _mixer = 'Mixer Disponible';
  String _tiempo = '1';
  String _capacidad = 'Si';
  bool _calidad = false;
  final _aditivoCtrl = TextEditingController();
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.cotizacion['hora_entrega'];
    if (raw != null) _fecha = DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() { _aditivoCtrl.dispose(); _comentarioCtrl.dispose(); super.dispose(); }

  Map<String, dynamic> get _cot => widget.cotizacion;
  List get _items => (_cot['cotizacion_items'] as List? ?? []);

  // Solo el tipo sin prefijo YURA
  String _cleanCemento(String raw) {
    final s = raw.trim().toUpperCase();
    return s.startsWith('YURA ') ? s.substring(5) : s;
  }

  Future<void> _selFecha() async {
    final d = await showDatePicker(context: context, initialDate: _fecha,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (c, w) => Theme(data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryDark)), child: w!));
    if (d == null || !mounted) return;
    setState(() => _fecha = DateTime(d.year, d.month, d.day, _fecha.hour, _fecha.minute));
  }

  Future<void> _selHora() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fecha),
        builder: (c, w) => Theme(data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryDark)), child: w!));
    if (t == null || !mounted) return;
    setState(() => _fecha = DateTime(_fecha.year, _fecha.month, _fecha.day, t.hour, t.minute));
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final bombasStr = _bombas.entries.where((e) => e.value).map((e) => e.key).join(',');

      // Filtrar solo items de concreto
      final concretoItems = _items.where(
        (i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto'
      ).toList();

      if (concretoItems.isEmpty) {
        // Si no hay concreto, enviar con el primer item que haya
        concretoItems.add(_items.isNotEmpty ? _items.first : <String, dynamic>{});
      }

      int enviados = 0;
      final nroCot = (_cot['numero_cotizacion'] ?? '').toString().trim();
      final baseCode = nroCot.isNotEmpty ? nroCot : 'REQ-${DateTime.now().millisecondsSinceEpoch}';

      for (int idx = 0; idx < concretoItems.length; idx++) {
        final it = concretoItems[idx];
        final resistencia = it['resistencia']?.toString() ?? '';
        final fuerza = resistencia.isNotEmpty ? "F'c=$resistencia" : (it['descripcion'] ?? '');

        final claveUnicaSupabase = concretoItems.length > 1
            ? '$baseCode-ITEM${idx + 1}'
            : baseCode;

        final volItem = double.tryParse((it['cantidad'] ?? '0').toString()) ?? 0.0;

        final esBombeable = (it['bombeable'] == true) ||
            (it['tipo_vaciado']?.toString().toUpperCase() == 'BOMBEABLE') ||
            (it['descripcion']?.toString().toUpperCase().contains('BOMBA') ?? false);
        final bombaFinal = esBombeable
            ? (bombasStr.isNotEmpty ? bombasStr : 'BOMBA')
            : 'DIRECTO';

        final obsBase = _comentarioCtrl.text.trim();
        final obsItem = concretoItems.length > 1
            ? (obsBase.isNotEmpty ? '[$fuerza - ${it['elemento'] ?? ''}] $obsBase' : '[$fuerza - ${it['elemento'] ?? ''}]')
            : obsBase;

        final payload = {
          'asesor_comercial':       _cot['asesor_nombre'] ?? '',
          'fecha_entrega':          DateFormat('yyyy-MM-dd').format(_fecha),
          'hora_entrega':           DateFormat('HH:mm').format(_fecha),
          'nombre_razon_social':    (_cot['cliente_nombre'] ?? '').toString().toUpperCase(),
          'tipo_documento':         _cot['tipo_comprobante'] ?? 'Factura',
          'dni_ruc':                _cot['cliente_documento'] ?? '',
          'direccion':              _cot['obra_direccion'] ?? '',
          'telefono':               _cot['cliente_telefono'] ?? '',
          'distrito':               _cot['obra_distrito'] ?? '',
          'numero_atencion':        '${idx + 1}',
          'volumen':                volItem,
          'volumen_programado':     volItem,
          'volumen_despachado':     0.0,
          'diseno':                 fuerza,
          'elemento':               it['elemento'] ?? '',
          'huso':                   it['huso'] ?? '',
          'slump':                  it['slump'] ?? '',
          'aditivo':                _aditivoCtrl.text.trim().isNotEmpty ? _aditivoCtrl.text.trim() : (it['aditivo'] ?? ''),
          'aditivo_adicional':      '',
          'tipo_cemento':           _cleanCemento(it['tipo_cemento']?.toString() ?? ''),
          'bombas':                 bombaFinal,
          'cbp_12':                 (esBombeable && _bombas['CBP12'] == true) ? 'SI' : null,
          'cbp_13':                 (esBombeable && _bombas['CBP13'] == true) ? 'SI' : null,
          'cbp_15':                 (esBombeable && _bombas['CBP15'] == true) ? 'SI' : null,
          'cbp_16':                 (esBombeable && _bombas['CBP16'] == true) ? 'SI' : null,
          'cbp_17':                 (esBombeable && _bombas['CBP17'] == true) ? 'SI' : null,
          'cbp_21':                 (esBombeable && _bombas['CBP21'] == true) ? 'SI' : null,
          'be_12':                  (esBombeable && _bombas['BE12'] == true) ? 'SI' : null,
          'mixers':                 _mixer,
          'capacidad_maxima':       _capacidad,
          'tiempo_estimado_vaciado': _tiempo,
          'personal_calidad':       _calidad ? 'SI' : 'NO',
          'observaciones':          obsItem,
          'mapa_coordenadas':       _cot['obra_maps_link'] ?? '',
          'orden_pedido':           nroCot,
          'clave_unica':            claveUnicaSupabase,
        };

        await Supabase.instance.client.from('ventas_programacion').insert(payload);
        enviados++;
      }

      if (enviados > 0) {
        final cotId = _cot['id'];
        if (cotId != null) {
          await Supabase.instance.client
              .from('cotizaciones').update({'estado': 'enviada'}).eq('id', cotId);
        }

        // Notificar a Ventas y Programación
        await NotificationService().notificarPorRoles(
          roles: ['ventas', 'programacion', 'logistica'],
          titulo: '📝 Nuevo Requerimiento',
          cuerpo: 'El asesor ${_cot['asesor_nombre'] ?? ''} ha creado un requerimiento para ${_cot['cliente_nombre'] ?? ''} ($enviados ítem${enviados > 1 ? 's' : ''}).',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$enviados requerimiento${enviados > 1 ? 's generados' : ' generado'} exitosamente ✅'),
            backgroundColor: AppColors.primaryDark));
          Navigator.pop(context, true);
        }
      } else {
        _snack('Error al generar los requerimientos', err: true);
      }
    } catch (e) { _snack('Error: $e', err: true); }
    finally { setState(() => _enviando = false); }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m), backgroundColor: err ? Colors.red.shade700 : AppColors.primaryDark));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F5F2),
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Crear Requerimiento',
          style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
      centerTitle: true,
    ),
    body: Column(children: [
      _buildStepper(),
      Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: _paso == 0 ? _buildMaquinas() : _buildExtra())),
      _buildFooter(),
    ]),
  );

  Widget _buildStepper() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
    child: Row(children: [
      _circle(0, 'Máquinas', Icons.precision_manufacturing_outlined),
      Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 8),
          color: _paso >= 1 ? AppColors.primaryDark : Colors.grey.shade300)),
      _circle(1, 'Extra', Icons.tune_outlined),
    ]),
  );

  Widget _circle(int i, String label, IconData icon) {
    final active = i <= _paso;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(duration: const Duration(milliseconds: 250),
        width: 44, height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: active ? AppColors.primaryDark : Colors.grey.shade100,
            border: Border.all(color: active ? AppColors.primaryDark : Colors.grey.shade300, width: 2),
            boxShadow: active ? [BoxShadow(color: AppColors.primaryDark.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0, 3))] : []),
        child: Icon(i < _paso ? Icons.check_rounded : icon,
            color: active ? Colors.white : Colors.grey.shade400, size: 20)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11,
          fontWeight: i == _paso ? FontWeight.bold : FontWeight.normal,
          color: active ? AppColors.primaryDark : Colors.grey.shade400)),
    ]);
  }

  Widget _buildConcretosInfo(List concretoItems) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardHeader(Icons.inventory_2_outlined, 'Concretos a Requerir'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${concretoItems.length} tipo${concretoItems.length > 1 ? 's' : ''} de concreto',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...concretoItems.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final it = entry.value;
            final cant = double.tryParse((it['cantidad'] ?? '0').toString()) ?? 0.0;
            final resistencia = it['resistencia']?.toString() ?? '';
            final disenoStr = resistencia.isNotEmpty ? "F'c = $resistencia" : (it['descripcion'] ?? '');
            final elemento = (it['elemento']?.toString() ?? '').toUpperCase();
            final slump = it['slump']?.toString() ?? '4" - 6"';
            final huso = it['huso']?.toString() ?? '-';
            final cemento = _cleanCemento(it['tipo_cemento']?.toString() ?? '');
            final esBomb = (it['bombeable'] == true) ||
                (it['tipo_vaciado']?.toString().toUpperCase() == 'BOMBEABLE') ||
                (it['descripcion']?.toString().toUpperCase().contains('BOMBA') ?? false);
            final aditivo = it['aditivo']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ítem $idx',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          disenoStr,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        '${cant.toStringAsFixed(cant % 1 == 0 ? 0 : 1)} m³',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _specPill(Icons.foundation, 'Elemento', elemento.isNotEmpty ? elemento : 'General'),
                      _specPill(Icons.water_drop_outlined, 'Slump', slump),
                      _specPill(Icons.grain, 'Huso', huso),
                      _specPill(Icons.square_foot, 'Cemento', cemento.isNotEmpty ? cemento : 'YURA PRO'),
                      _specPill(
                        esBomb ? Icons.precision_manufacturing : Icons.local_shipping,
                        'Vaciado',
                        esBomb ? 'BOMBEABLE' : 'DIRECTO',
                        color: esBomb ? const Color(0xFF0284C7) : const Color(0xFF059669),
                      ),
                      if (aditivo.isNotEmpty)
                        _specPill(Icons.science_outlined, 'Aditivo', aditivo),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _specPill(IconData icon, String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildMaquinas() {
    final concretoItems = _items.where(
      (i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto'
    ).toList();
    if (concretoItems.isEmpty && _items.isNotEmpty) {
      concretoItems.add(_items.first);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (concretoItems.isNotEmpty) ...[
        _buildConcretosInfo(concretoItems),
        const SizedBox(height: 14),
      ],
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHeader(Icons.event_outlined, 'Fecha y hora de entrega'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dateBtn(Icons.calendar_month_outlined,
              DateFormat('dd / MM / yyyy').format(_fecha), _selFecha)),
          const SizedBox(width: 10),
          Expanded(child: _dateBtn(Icons.access_time_rounded,
              DateFormat('HH : mm').format(_fecha), _selHora)),
        ]),
      ])),
      const SizedBox(height: 14),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHeader(Icons.settings_outlined, 'Tipo de máquina'),
        const SizedBox(height: 4),
        const Text('Selecciona las que aplican', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 14),
        GridView.count(crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.4,
          children: _bombas.keys.map(_bombaTile).toList()),
      ])),
      const SizedBox(height: 14),
      _card(child: Row(children: [
        _iconBox(Icons.cable_outlined),
        const SizedBox(width: 12),
        const Expanded(child: Text('Agregar extensiones',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A2E1A)))),
        Switch(value: _extensiones, onChanged: (v) => setState(() => _extensiones = v),
            activeColor: AppColors.primaryDark),
      ])),
    ]);
  }

  Widget _buildExtra() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _card(child: Column(children: [
      _cardHeader(Icons.local_shipping_outlined, 'Consideraciones'),
      const SizedBox(height: 14),
      _ddRow(Icons.fire_truck_outlined, 'Disponible', _mixer,
          ['Mixer Disponible', 'Mixer No Disponible'], (v) => setState(() => _mixer = v!)),
      const Divider(height: 20, color: Color(0xFFF0F0F0)),
      _ddRow(Icons.timer_outlined, 'Tiempo estimado (h)', _tiempo,
          List.generate(8, (i) => '${i+1}'), (v) => setState(() => _tiempo = v!)),
      const Divider(height: 20, color: Color(0xFFF0F0F0)),
      _ddRow(Icons.speed_outlined, 'Capacidad máxima', _capacidad,
          ['Si', 'No'], (v) => setState(() => _capacidad = v!)),
    ])),
    const SizedBox(height: 14),
    _card(child: Row(children: [
      _iconBox(Icons.verified_user_outlined),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Personal de calidad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A2E1A))),
        Text('Inspector en obra', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
      Switch(value: _calidad, onChanged: (v) => setState(() => _calidad = v), activeColor: AppColors.primaryDark),
    ])),
    const SizedBox(height: 14),
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(Icons.science_outlined, 'Aditivo adicional'),
      const SizedBox(height: 10),
      _input(_aditivoCtrl, 'Ej: Sikafloor, Chema...'),
      const SizedBox(height: 14),
      _cardHeader(Icons.comment_outlined, 'Comentario requerimiento'),
      const SizedBox(height: 10),
      _input(_comentarioCtrl, 'Observaciones para producción...', maxLines: 3),
    ])),
  ]);

  Widget _buildFooter() => Container(
    color: Colors.white,
    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
    child: Row(children: [
      if (_paso == 1) ...[
        Expanded(child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark, size: 18),
          label: const Text('Atrás', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
          onPressed: () => setState(() => _paso = 0),
        )),
        const SizedBox(width: 12),
      ],
      Expanded(flex: 2, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        icon: _enviando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Icon(_paso == 0 ? Icons.arrow_forward : Icons.cloud_upload_outlined, color: Colors.white),
        label: Text(_paso == 0 ? 'Continuar' : 'Enviar al Drive',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        onPressed: _enviando ? null : () { if (_paso == 0) setState(() => _paso = 1); else _enviar(); },
      )),
    ]),
  );

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDE8)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: child);

  Widget _cardHeader(IconData icon, String title) => Row(children: [
    _iconBox(icon), const SizedBox(width: 12),
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A2E1A))),
  ]);

  Widget _iconBox(IconData icon) => Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primaryDark, size: 20));

  Widget _bombaTile(String k) {
    final sel = _bombas[k]!;
    return GestureDetector(onTap: () => setState(() => _bombas[k] = !sel),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
            color: sel ? AppColors.primaryDark : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppColors.primaryDark : Colors.grey.shade300, width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16, color: sel ? Colors.white : Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(k, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
              color: sel ? Colors.white : Colors.grey.shade600)),
        ])));
  }

  Widget _dateBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF0F7F0), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC8E6C9))),
        child: Row(children: [Icon(icon, color: AppColors.primaryDark, size: 18), const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2E1A))))]),
      ));

  Widget _ddRow(IconData icon, String label, String value, List<String> items, ValueChanged<String?> cb) =>
      Row(children: [
        Icon(icon, color: Colors.grey, size: 18), const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
        DropdownButton<String>(value: value, isDense: true, underline: const SizedBox(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2E1A)),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: cb),
      ]);

  Widget _input(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
    controller: ctrl, maxLines: maxLines,
    decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true, fillColor: const Color(0xFFF8FBF8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5))),
  );
}