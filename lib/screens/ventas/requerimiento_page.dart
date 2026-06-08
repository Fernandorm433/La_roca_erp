// lib/screens/ventas/requerimiento_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

const _GAS_URL =
    'https://script.google.com/macros/s/AKfycbzKlmfOBqCQSewWueYIdBwvjj_RP7uUty2qGRjGeS3i1XrS3a0qiLeUMl8I8SfT3ut2Fg/exec';

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
  Map<String, dynamic> get _item => _items.firstWhere(
    (i) => (i['tipo'] ?? '').toString().toLowerCase() == 'concreto',
    orElse: () => _items.isNotEmpty ? _items.first : <String, dynamic>{},
  );

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
      final it = _item;
      final resistencia = it['resistencia']?.toString() ?? '';
      final fuerza = resistencia.isNotEmpty ? "F'c=$resistencia" : (it['descripcion'] ?? '');
      final bombasStr = _bombas.entries.where((e) => e.value).map((e) => e.key).join(',');

      final params = {
        'asesor':           _cot['asesor_nombre'] ?? '',
        'day':              DateFormat('dd/MM/yyyy').format(_fecha),
        'hour':             DateFormat('HH:mm').format(_fecha),
        'client':           (_cot['cliente_nombre'] ?? '').toString().toUpperCase(),
        'tipoDocumento':    _cot['tipo_comprobante'] ?? 'Factura',
        'document':         _cot['cliente_documento'] ?? '',
        'address':          _cot['obra_direccion'] ?? '',
        'phone':            _cot['cliente_telefono'] ?? '',
        'distrito':         _cot['obra_distrito'] ?? '',
        'volumen':          (it['cantidad'] ?? '').toString(),
        'fuerza':           fuerza,
        'elemento':         it['elemento'] ?? '',
        'huso':             it['huso'] ?? '',
        'slump':            it['slump'] ?? '',
        'aditivo':          _aditivoCtrl.text.trim().isNotEmpty
                                ? _aditivoCtrl.text.trim() : (it['aditivo'] ?? ''),
        'cemento':          _cleanCemento(it['tipo_cemento']?.toString() ?? ''),
        'bombas':           bombasStr,
        'extensiones':      _extensiones ? 'SI' : '',
        'selectedMixer':    _mixer,
        'selectedCapacity': _capacidad,
        'time':             _tiempo,
        'quality':          _calidad ? 'SI' : '',
        'commentReturn':    _comentarioCtrl.text.trim(),
        'location':         _cot['obra_maps_link'] ?? '',
        'urlVoucher':       '',
        'emisionReq':       DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        'observaciones':    '',
      };

      final body = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final res = await http.post(Uri.parse(_GAS_URL),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: body);

      // GAS retorna 302 en POST exitoso → es éxito
      final ok = res.statusCode == 200 || res.statusCode == 302;
      if (ok) {
        final cotId = _cot['id'];
        if (cotId != null) {
          await Supabase.instance.client
              .from('cotizaciones').update({'estado': 'enviada'}).eq('id', cotId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Requerimiento enviado al Drive'),
            backgroundColor: AppColors.primaryDark));
          Navigator.pop(context, true);
        }
      } else {
        _snack('Error al enviar (${res.statusCode})', err: true);
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
            boxShadow: active ? [BoxShadow(color: AppColors.primaryDark.withOpacity(.25), blurRadius: 8, offset: const Offset(0, 3))] : []),
        child: Icon(i < _paso ? Icons.check_rounded : icon,
            color: active ? Colors.white : Colors.grey.shade400, size: 20)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11,
          fontWeight: i == _paso ? FontWeight.bold : FontWeight.normal,
          color: active ? AppColors.primaryDark : Colors.grey.shade400)),
    ]);
  }

  Widget _buildMaquinas() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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