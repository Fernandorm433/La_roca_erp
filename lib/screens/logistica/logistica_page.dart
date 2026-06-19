// Archivo: lib/screens/logistica/logistica_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'comparativa_consumos_page.dart' as comparativa_consumos_page;

// ─────────────────────────────────────────────────────────────
// MODELO — tabla: recepcion_materiales
// ─────────────────────────────────────────────────────────────

class RecepcionMaterial {
  final String id;
  final DateTime fecha;
  final double volumenM3;
  final String descripcion;
  final String proveedor;
  final String ruc;
  final double precioUnitario;
  final double total;
  final String guia;
  final String factura;
  final String depositos;
  final bool dia;
  final bool erp;
  final bool op;

  RecepcionMaterial({
    required this.id,
    required this.fecha,
    required this.volumenM3,
    required this.descripcion,
    required this.proveedor,
    required this.ruc,
    required this.precioUnitario,
    required this.total,
    required this.guia,
    required this.factura,
    required this.depositos,
    required this.dia,
    required this.erp,
    required this.op,
  });

  factory RecepcionMaterial.fromMap(Map<String, dynamic> m) {
    final vol = double.tryParse(m['volumen_m3']?.toString() ?? '0') ?? 0;
    final pu = double.tryParse(m['precio_unitario']?.toString() ?? '0') ?? 0;
    return RecepcionMaterial(
      id: m['id']?.toString() ?? '',
      fecha: DateTime.tryParse(m['fecha']?.toString() ?? '') ?? DateTime.now(),
      volumenM3: vol,
      descripcion: m['descripcion']?.toString() ?? '',
      proveedor: m['proveedor']?.toString() ?? '',
      ruc: m['ruc']?.toString() ?? '',
      precioUnitario: pu,
      total: double.tryParse(m['total']?.toString() ?? '${vol * pu}') ?? (vol * pu),
      guia: m['guia']?.toString() ?? '',
      factura: m['factura']?.toString() ?? '',
      depositos: m['depositos']?.toString() ?? '',
      dia: m['dia'] == true,
      erp: m['erp'] == true,
      op: m['op'] == true,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL
// ─────────────────────────────────────────────────────────────

class LogisticaPage extends StatefulWidget {
  const LogisticaPage({super.key});
  @override
  State<LogisticaPage> createState() => _LogisticaPageState();
}

class _LogisticaPageState extends State<LogisticaPage> {
  final _sb = Supabase.instance.client;
  List<RecepcionMaterial> _registros = [];
  bool _loading = true;
  DateTime _fechaFiltro = DateTime.now();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final fecha = _fechaFiltro.toIso8601String().split('T')[0];
      final data = await _sb
          .from('recepcion_materiales')
          .select()
          .eq('fecha', fecha)
          .order('created_at');
      if (mounted) {
        setState(() {
          _registros = (data as List).map((e) => RecepcionMaterial.fromMap(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RecepcionMaterial> get _filtrados {
    if (_busqueda.isEmpty) return _registros;
    final q = _busqueda.toLowerCase();
    return _registros.where((r) =>
      r.descripcion.toLowerCase().contains(q) ||
      r.proveedor.toLowerCase().contains(q) ||
      r.guia.toLowerCase().contains(q) ||
      r.factura.toLowerCase().contains(q),
    ).toList();
  }

  // ── KPIs ────────────────────────────────────────────────────
  double get _totalVolumen => _registros.fold(0.0, (s, r) => s + r.volumenM3);
  double get _totalFacturado => _registros.fold(0.0, (s, r) => s + r.total);
  int get _pendientesOp => _registros.where((r) => !r.op).length;

  // ── TOGGLE BOOL EN BD ────────────────────────────────────────
  Future<void> _toggleBool(RecepcionMaterial reg, String campo, bool val) async {
    await _sb.from('recepcion_materiales').update({campo: val}).eq('id', reg.id);
    _cargar();
  }

  void _abrirFormulario({RecepcionMaterial? reg, String? categoriaBase}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _FormularioSheet(onGuardado: _cargar, registro: reg, categoriaBase: categoriaBase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildAccionesRapidas(),
                _buildKpis(),
                _buildFilterRow(),
                Expanded(child: _buildTabla()),
              ],
            ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────
  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('RECEPCIÓN DE MATERIALES',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text('Registro diario de áridos y agregados',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ]),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
              label: const Text('Comparativa Mensual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const comparativa_consumos_page.ComparativaConsumosPage()));
              },
            ),
          ],
        ),
      ).animate().fade().slideY(begin: -0.02);

  Widget _buildAccionesRapidas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NUEVO REGISTRO RÁPIDO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _btnRapido('Piedra Chancada', Icons.terrain, const Color(0xFF64748B), 'PIEDRA'),
                const SizedBox(width: 12),
                _btnRapido('Arena', Icons.grain, const Color(0xFFD97706), 'ARENA'),
                const SizedBox(width: 12),
                _btnRapido('Cemento', Icons.shopping_bag, const Color(0xFF0284C7), 'CEMENTO'),
                const SizedBox(width: 12),
                _btnRapido('Otro', Icons.add_box_outlined, const Color(0xFF0F172A), ''),
              ],
            ),
          )
        ],
      ),
    ).animate().fade(delay: 50.ms).slideX(begin: 0.05);
  }

  Widget _btnRapido(String texto, IconData icono, Color color, String categoria) {
    return InkWell(
      onTap: () => _abrirFormulario(categoriaBase: categoria),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 8),
            Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── KPI CARDS ───────────────────────────────────────────────
  Widget _buildKpis() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Row(children: [
          _kpi('VOLUMEN HOY', '${_totalVolumen.toStringAsFixed(0)} m³', Icons.layers_outlined, const Color(0xFFE2E8F0), const Color(0xFF475569)),
          const SizedBox(width: 12),
          _kpi('TOTAL FACTURADO', 'S/ ${_totalFacturado.toStringAsFixed(2)}', Icons.receipt_long_outlined, const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
          const SizedBox(width: 12),
          _kpi('ENTRADAS HOY', '${_registros.length}', Icons.local_shipping_outlined, const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
          const SizedBox(width: 12),
          _kpi('SIN OP', '$_pendientesOp', Icons.pending_actions_outlined, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
        ]),
      ).animate().fade(delay: 50.ms);

  Widget _kpi(String t, String v, IconData icon, Color bg, Color ic) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: bg, child: Icon(icon, color: ic, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            ])),
          ]),
        ),
      );

  // ── FILA DE FILTROS ──────────────────────────────────────────
  Widget _buildFilterRow() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
        child: Row(children: [
          // Búsqueda
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por descripción, proveedor, guía...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Selector de fecha
          InkWell(
            onTap: () async {
              final s = await showDatePicker(context: context, initialDate: _fechaFiltro, firstDate: DateTime(2025), lastDate: DateTime(2030));
              if (s != null) { setState(() => _fechaFiltro = s); _cargar(); }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                Text(
                  '${_fechaFiltro.day.toString().padLeft(2,'0')}/${_fechaFiltro.month.toString().padLeft(2,'0')}/${_fechaFiltro.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Actualizar',
            style: IconButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0)))),
          ),
        ]),
      );

  // ── TABLA PRINCIPAL (estilo Excel) ───────────────────────────
  Widget _buildTabla() {
    final cols = [
      _ColDef('FECHA', 90),
      _ColDef('VOL. (m³)', 70),
      _ColDef('DESCRIPCIÓN', 200),
      _ColDef('PROVEEDOR / RUC', 160),
      _ColDef('P. UNIT.', 80),
      _ColDef('TOTAL', 90),
      _ColDef('GUÍA', 70),
      _ColDef('FACTURA', 80),
      _ColDef('DEPÓSITOS', 120),
      _ColDef('DIA', 44),
      _ColDef('ERP', 44),
      _ColDef('OP', 44),
      _ColDef('', 70), // acciones
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Cabecera tabla
            Container(
              color: const Color(0xFF0F172A),
              child: Row(
                children: cols.map((c) => SizedBox(
                  width: c.width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text(c.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                  ),
                )).toList(),
              ),
            ),
            // Filas
            if (_filtrados.isEmpty)
              Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text('Sin registros para esta fecha', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ])))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _buildFila(_filtrados[i], i),
                ),
              ),
          ]),
        ),
      ),
    ).animate().fade(delay: 80.ms);
  }

  Widget _buildFila(RecepcionMaterial r, int i) {
    final bg = i.isOdd ? const Color(0xFFFAFAFA) : Colors.white;
    // Color de fila según descripción (como el Excel)
    Color? rowColor;
    final d = r.descripcion.toLowerCase();
    if (d.contains('cancelado') || d.contains('cancelado')) rowColor = const Color(0xFFFFF9C4);
    else if (r.factura.isNotEmpty) rowColor = const Color(0xFFE8F5E9);

    return Container(
      color: rowColor ?? bg,
      child: Row(children: [
        _celda('${r.fecha.day.toString().padLeft(2,'0')}/${r.fecha.month.toString().padLeft(2,'0')}/${r.fecha.year}', 90,
            bold: true, color: _colorFecha(i)),
        _celda('${r.volumenM3.toStringAsFixed(0)}', 70, center: true),
        _celda(r.descripcion, 200, bold: true, color: const Color(0xFF334155)),
        _celda('${r.proveedor}\n${r.ruc}', 160, small: true),
        _celda('S/ ${r.precioUnitario.toStringAsFixed(2)}', 80, center: true),
        _celda('S/ ${r.total.toStringAsFixed(2)}', 90, bold: true, center: true, color: const Color(0xFF16A34A)),
        _celdaGuia(r.guia, 70),
        _celda(r.factura.isNotEmpty ? r.factura : 'PAGADO', 80,
            bold: r.factura.isEmpty, color: r.factura.isEmpty ? const Color(0xFF0284C7) : null),
        _celda(r.depositos, 120, small: true),
        // Checkboxes DIA / ERP / OP
        SizedBox(width: 44, child: Checkbox(
          value: r.dia, onChanged: (v) => _toggleBool(r, 'dia', v ?? false),
          activeColor: const Color(0xFF0F172A), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )),
        SizedBox(width: 44, child: Checkbox(
          value: r.erp, onChanged: (v) => _toggleBool(r, 'erp', v ?? false),
          activeColor: const Color(0xFF0F172A), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )),
        SizedBox(width: 44, child: Checkbox(
          value: r.op, onChanged: (v) => _toggleBool(r, 'op', v ?? false),
          activeColor: const Color(0xFF0F172A), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )),
        SizedBox(width: 70, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextButton(
            onPressed: () => _abrirFormulario(reg: r),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF475569), backgroundColor: const Color(0xFFF1F5F9), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: const Text('Editar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        )),
      ]),
    );
  }

  // Simula el color de fecha del Excel (verde/cian/blanco alternado)
  Color? _colorFecha(int i) {
    if (i % 4 == 0) return const Color(0xFF16A34A);
    if (i % 4 == 2) return const Color(0xFF0891B2);
    return null;
  }

  Widget _celda(String txt, double w, {bool bold = false, Color? color, bool center = false, bool small = false}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(txt,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: TextStyle(fontSize: small ? 10 : 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? const Color(0xFF334155), height: 1.3)),
        ),
      );

  Widget _celdaGuia(String guia, double w) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: guia.isNotEmpty ? const Color(0xFFFFF9C4) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: guia.isNotEmpty ? Border.all(color: const Color(0xFFF59E0B)) : null,
            ),
            child: Text(guia, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
          ),
        ),
      );
}

class _ColDef { final String label; final double width; const _ColDef(this.label, this.width); }

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET — FORMULARIO (sin agua/aditivo)
// ─────────────────────────────────────────────────────────────

class _FormularioSheet extends StatefulWidget {
  final VoidCallback onGuardado;
  final RecepcionMaterial? registro;
  final String? categoriaBase;
  const _FormularioSheet({required this.onGuardado, this.registro, this.categoriaBase});
  @override
  State<_FormularioSheet> createState() => _FormularioSheetState();
}

class _FormularioSheetState extends State<_FormularioSheet> {
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  DateTime _fecha = DateTime.now();

  late final TextEditingController _volCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _provCtrl;
  late final TextEditingController _rucCtrl;
  late final TextEditingController _puCtrl;
  late final TextEditingController _guiaCtrl;
  late final TextEditingController _factCtrl;
  late final TextEditingController _depCtrl;

  // Sugerencias rápidas de descripción
  final List<String> _sugerencias = [
    'BIG BAG DE CEMENTO YURA', 'CEMENTO WARI',
    'ARENA CANTERA 3 PASTORCITOS', 'ARENA TEJADA (L Y M)',
    'PIEDRA 1/2"', 'PIEDRA 3/4"', 'PIEDRA 3/8"',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.registro;
    _fecha = r?.fecha ?? DateTime.now();
    _volCtrl = TextEditingController(text: r?.volumenM3.toStringAsFixed(0) ?? '');
    
    // Si hay una categoría base y no estamos editando, usarla como inicio de descripción
    String descText = r?.descripcion ?? '';
    if (widget.registro == null && widget.categoriaBase != null && widget.categoriaBase!.isNotEmpty) {
      descText = widget.categoriaBase!;
    }
    _descCtrl = TextEditingController(text: descText);
    
    _provCtrl = TextEditingController(text: r?.proveedor ?? '');
    _rucCtrl = TextEditingController(text: r?.ruc ?? '');
    _puCtrl = TextEditingController(text: r?.precioUnitario.toStringAsFixed(2) ?? '');
    _guiaCtrl = TextEditingController(text: r?.guia ?? '');
    _factCtrl = TextEditingController(text: r?.factura ?? '');
    _depCtrl = TextEditingController(text: r?.depositos ?? '');
  }

  @override
  void dispose() {
    for (final c in [_volCtrl, _descCtrl, _provCtrl, _rucCtrl, _puCtrl, _guiaCtrl, _factCtrl, _depCtrl]) c.dispose();
    super.dispose();
  }

  double get _totalCalc => (double.tryParse(_volCtrl.text) ?? 0) * (double.tryParse(_puCtrl.text) ?? 0);

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'fecha': _fecha.toIso8601String().split('T')[0],
        'volumen_m3': double.tryParse(_volCtrl.text) ?? 0,
        'descripcion': _descCtrl.text.trim().toUpperCase(),
        'proveedor': _provCtrl.text.trim().toUpperCase(),
        'ruc': _rucCtrl.text.trim(),
        'precio_unitario': double.tryParse(_puCtrl.text) ?? 0,
        'guia': _guiaCtrl.text.trim(),
        'factura': _factCtrl.text.trim(),
        'depositos': _depCtrl.text.trim(),
      };
      final sb = Supabase.instance.client;
      if (widget.registro != null) {
        await sb.from('recepcion_materiales').update(payload).eq('id', widget.registro!.id);
      } else {
        await sb.from('recepcion_materiales').insert(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${widget.registro != null ? "Actualizado" : "Guardado"} correctamente'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        widget.onGuardado();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              
              // Título
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.registro != null ? 'Editar Registro' : 'Nuevo Registro de Materiales',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Text('Ingreso de áridos y agregados', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ]),
              const SizedBox(height: 20),

              // Fecha
              _dateBox(),
              const SizedBox(height: 16),

              // Descripción con sugerencias
              _label('Descripción del Material'),
              _field('Ej: PUESTO EN OBRA 1/2', _descCtrl, required: true),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: _sugerencias
                  .where((s) => widget.categoriaBase == null || widget.categoriaBase!.isEmpty || s.contains(widget.categoriaBase!))
                  .map((s) => GestureDetector(
                onTap: () => setState(() => _descCtrl.text = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
              )).toList()),
              const SizedBox(height: 14),

              // Row: volumen + precio
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label(widget.categoriaBase == 'CEMENTO' ? 'Cantidad (Big Bags)' : (widget.categoriaBase == 'ARENA' || widget.categoriaBase == 'PIEDRA' ? 'Volumen (KG)' : 'Volumen / Cantidad')),
                  _numField('Ej: 25', _volCtrl, onChanged: (_) => setState((){})),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Precio Unitario (S/)'),
                  _numField('Ej: 79.00', _puCtrl, onChanged: (_) => setState((){})),
                ])),
              ]),
              const SizedBox(height: 8),

              // Total calculado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Text('TOTAL: S/ ${_totalCalc.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D), fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 14),

              // Proveedor + RUC
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Proveedor'),
                  _field('Ej: MIGUEL MAMANI FAC', _provCtrl),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('RUC / Nota'),
                  _field('Ej: 20559331547', _rucCtrl),
                ])),
              ]),
              const SizedBox(height: 14),

              // Guía + Factura + Depósitos
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('N° Guía'), _field('Ej: 3543', _guiaCtrl)])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('N° Factura'), _field('Ej: 568', _factCtrl)])),
              ]),
              const SizedBox(height: 14),
              _label('Depósitos / Estado de pago'),
              _field('Ej: DEP PASADO / PAGADO X 4 VIAJE', _depCtrl),
              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _guardar,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(widget.registro != null ? 'Actualizar Registro' : 'Guardar Registro',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))));

  Widget _dateBox() => InkWell(
        onTap: () async {
          final s = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime(2025), lastDate: DateTime(2030));
          if (s != null) setState(() => _fecha = s);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF475569)),
            const SizedBox(width: 10),
            const Text('Fecha del registro:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13)),
            const Spacer(),
            Text('${_fecha.day.toString().padLeft(2,'0')}/${_fecha.month.toString().padLeft(2,'0')}/${_fecha.year}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 14)),
          ]),
        ),
      );

  Widget _field(String hint, TextEditingController ctrl, {bool required = false}) => TextFormField(
        controller: ctrl,
        textCapitalization: TextCapitalization.characters,
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Requerido' : null : null,
        decoration: _deco(hint),
      );

  Widget _numField(String hint, TextEditingController ctrl, {void Function(String)? onChanged}) => TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        onChanged: onChanged,
        decoration: _deco(hint),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
      );
} 
