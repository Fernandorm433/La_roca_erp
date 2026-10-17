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
      backgroundColor: const Color(0xFFF4F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004899)))
          : LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 800 || constraints.maxHeight < 800;
                if (isMobile) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHero(),
                        _buildAccionesRapidas(),
                        _buildFilterRow(),
                        SizedBox(height: 560, child: _buildTabla()),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(),
                    _buildAccionesRapidas(),
                    _buildFilterRow(),
                    Expanded(child: _buildTabla()),
                  ],
                );
              },
            ),
    );
  }

  // ── HERO CABECERA corporativo NovaConcret ────────────────────
  Widget _buildHero() {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF002244), // Deep Navy
            Color(0xFF003366),
            Color(0xFF004899), // Nova Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Ambient brand circles
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0284C7).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 80,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF004899).withOpacity(0.2),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Logística y Materiales',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Recepción diaria de agregados y control de insumos · NovaConcret',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const comparativa_consumos_page.ComparativaConsumosPage(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Comparativa Mensual',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Tooltip(
                            message: 'Actualizar registros',
                            child: InkWell(
                              onTap: _cargar,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 650;
                      if (isSmall) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                _kpiHero('Volumen Hoy', '${_totalVolumen.toStringAsFixed(0)} m³', Icons.layers_rounded, const Color(0xFF38BDF8)),
                                const SizedBox(width: 10),
                                _kpiHero('Total Facturado', 'S/ ${_totalFacturado.toStringAsFixed(2)}', Icons.receipt_long_rounded, const Color(0xFF0284C7)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _kpiHero('Entradas', '${_registros.length}', Icons.local_shipping_rounded, const Color(0xFF004899)),
                                const SizedBox(width: 10),
                                _kpiHero('Sin OP', '$_pendientesOp', Icons.pending_actions_rounded, const Color(0xFF64748B)),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          _kpiHero('Volumen Hoy', '${_totalVolumen.toStringAsFixed(0)} m³', Icons.layers_rounded, const Color(0xFF38BDF8)),
                          const SizedBox(width: 10),
                          _kpiHero('Total Facturado', 'S/ ${_totalFacturado.toStringAsFixed(2)}', Icons.receipt_long_rounded, const Color(0xFF0284C7)),
                          const SizedBox(width: 10),
                          _kpiHero('Entradas Registradas', '${_registros.length}', Icons.local_shipping_rounded, const Color(0xFF004899)),
                          const SizedBox(width: 10),
                          _kpiHero('Pendientes Sin OP', '$_pendientesOp', Icons.pending_actions_rounded, const Color(0xFF64748B)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiHero(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 18),
              SizedBox(width: 6),
              Text(
                'ACCIONES RÁPIDAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF003366),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _btnRapido('Piedra Chancada', Icons.terrain_rounded, const [Color(0xFF002244), Color(0xFF003366)], 'PIEDRA'),
                const SizedBox(width: 12),
                _btnRapido('Arena', Icons.grain_rounded, const [Color(0xFF004899), Color(0xFF0284C7)], 'ARENA'),
                const SizedBox(width: 12),
                _btnRapido('Cemento', Icons.shopping_bag_rounded, const [Color(0xFF0284C7), Color(0xFF38BDF8)], 'CEMENTO'),
                const SizedBox(width: 12),
                _btnRapido('Otro Material', Icons.add_box_rounded, const [Color(0xFF334155), Color(0xFF64748B)], ''),
              ],
            ),
          )
        ],
      ),
    ).animate().fade(delay: 50.ms).slideX(begin: 0.05);
  }

  Widget _btnRapido(String texto, IconData icono, List<Color> grad, String categoria) {
    return InkWell(
      onTap: () => _abrirFormulario(categoriaBase: categoria),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003366).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: grad[0].withOpacity(0.35), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(icono, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            Text(
              texto,
              style: const TextStyle(
                color: Color(0xFF002244),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
  }

  // ── FILA DE FILTROS ──────────────────────────────────────────
  Widget _buildFilterRow() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return Column(
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003366).withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _busqueda = v),
                      decoration: const InputDecoration(
                        hintText: 'Buscar material, proveedor o guía...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, size: 19, color: Color(0xFF0284C7)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final s = await showDatePicker(
                              context: context,
                              initialDate: _fechaFiltro,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (s != null) {
                              setState(() => _fechaFiltro = s);
                              _cargar();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF003366).withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              Text(
                                '${_fechaFiltro.day.toString().padLeft(2, '0')}/${_fechaFiltro.month.toString().padLeft(2, '0')}/${_fechaFiltro.year}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF002244), fontSize: 13),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF003366).withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF004899), size: 20),
                          tooltip: 'Actualizar',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(children: [
              // Búsqueda
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003366).withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por descripción, proveedor, guía o factura...',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 19, color: Color(0xFF0284C7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Selector de fecha
              InkWell(
                onTap: () async {
                  final s = await showDatePicker(
                    context: context,
                    initialDate: _fechaFiltro,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (s != null) {
                    setState(() => _fechaFiltro = s);
                    _cargar();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003366).withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      '${_fechaFiltro.day.toString().padLeft(2, '0')}/${_fechaFiltro.month.toString().padLeft(2, '0')}/${_fechaFiltro.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF002244), fontSize: 13),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003366).withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF004899), size: 20),
                  tooltip: 'Actualizar',
                ),
              ),
            ]);
          },
        ),
      );

  // ── TABLA PRINCIPAL (Modern UI) ──────────────────────────────
  Widget _buildTabla() {
    final cols = [
      _ColDef('FECHA', 100),
      _ColDef('VOL.', 80),
      _ColDef('DESCRIPCIÓN', 210),
      _ColDef('PROVEEDOR', 170),
      _ColDef('P. UNIT.', 80),
      _ColDef('TOTAL', 90),
      _ColDef('GUÍA', 80),
      _ColDef('FACTURA', 90),
      _ColDef('DEPÓSITOS', 130),
      _ColDef('DIA', 50),
      _ColDef('ERP', 50),
      _ColDef('OP', 50),
      _ColDef('', 50), // acciones
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SizedBox(
                    width: 1230,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Cabecera tabla
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5))
                        ),
                        child: Row(
                          children: cols.map((c) => SizedBox(
                            width: c.width,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              child: Text(c.label, style: const TextStyle(color: Color(0xFF003366), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
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
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filtrados.length,
                            itemBuilder: (_, i) => _buildFila(_filtrados[i], i),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    ).animate().fade(delay: 80.ms);
  }

  Widget _buildFila(RecepcionMaterial r, int i) {
    Color? rowColor;
    final d = r.descripcion.toLowerCase();
    if (d.contains('cancelado')) rowColor = const Color(0xFFFEF9C3).withOpacity(0.3);
    else if (r.factura.isNotEmpty) rowColor = const Color(0xFFF0FDF4).withOpacity(0.4);

    return Container(
      decoration: BoxDecoration(
        color: rowColor ?? Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          hoverColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              _celdaFecha(r.fecha, 100),
              _celdaVolumen(r.volumenM3, 80),
              _celdaDesc(r.descripcion, 210),
              _celdaProveedor(r.proveedor, r.ruc, 170),
              _celdaText('S/ ${r.precioUnitario.toStringAsFixed(2)}', 80, color: const Color(0xFF475569)),
              _celdaTotal(r.total, 90),
              _celdaBadge(r.guia, 80, isGuia: true),
              _celdaBadge(r.factura.isNotEmpty ? r.factura : 'PAGADO', 90, isFactura: true, pagado: r.factura.isEmpty),
              _celdaText(r.depositos, 130, color: const Color(0xFF64748B)),
              
              // Checkboxes
              _celdaCheck(r.dia, (v) => _toggleBool(r, 'dia', v), 50),
              _celdaCheck(r.erp, (v) => _toggleBool(r, 'erp', v), 50),
              _celdaCheck(r.op, (v) => _toggleBool(r, 'op', v), 50),
              
              // Botón Editar
              SizedBox(width: 50, child: Center(
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: const Color(0xFF004899),
                  splashRadius: 20,
                  hoverColor: const Color(0xFFE2E8F0),
                  onPressed: () => _abrirFormulario(reg: r),
                  tooltip: 'Editar',
                ),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _celdaFecha(DateTime f, double w) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF0284C7)),
            const SizedBox(width: 6),
            Text('${f.day.toString().padLeft(2,'0')}/${f.month.toString().padLeft(2,'0')}', 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF002244))),
          ],
        ),
      ),
    );
  }

  Widget _celdaVolumen(double vol, double w) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE).withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${vol.toStringAsFixed(0)}', 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
        ),
      ),
    );
  }

  Widget _celdaDesc(String desc, double w) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(desc, 
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF002244), height: 1.2)),
      ),
    );
  }

  Widget _celdaProveedor(String prov, String ruc, double w) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(prov.isEmpty ? '-' : prov, 
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            if (ruc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(ruc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _celdaTotal(double total, double w) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('S/ ${total.toStringAsFixed(2)}', 
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF004899))),
      ),
    );
  }

  Widget _celdaBadge(String text, double w, {bool isGuia = false, bool isFactura = false, bool pagado = false}) {
    Color bg = Colors.transparent;
    Color tc = const Color(0xFF64748B);
    Color? borderColor;
    
    if (text.isEmpty || text == '-') {
      text = '-';
    } else {
      if (isGuia) {
        bg = const Color(0xFFE0F2FE);
        tc = const Color(0xFF0284C7);
        borderColor = const Color(0xFFBAE6FD);
      } else if (isFactura) {
        if (pagado) {
          bg = const Color(0xFFF0FDF4);
          tc = const Color(0xFF15803D);
          borderColor = const Color(0xFFBBF7D0);
        } else {
          bg = const Color(0xFFEFF6FF);
          tc = const Color(0xFF004899);
          borderColor = const Color(0xFFBFDBFE);
        }
      }
    }

    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: text == '-' 
          ? const Center(child: Text('-', style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold)))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
              ),
              child: Text(text, 
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tc, letterSpacing: 0.5)),
            ),
      ),
    );
  }

  Widget _celdaCheck(bool val, Function(bool) onChanged, double w) {
    return SizedBox(
      width: w,
      child: Center(
        child: Transform.scale(
          scale: 0.85,
          child: Checkbox(
            value: val,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: const Color(0xFF003366),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _celdaText(String txt, double w, {Color? color}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(txt,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? const Color(0xFF334155), height: 1.2)),
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
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF004899).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF004899))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.registro != null ? 'Editar Registro' : 'Nuevo Registro de Materiales',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF002244))),
                  const Text('Ingreso de áridos y agregados · NovaConcret', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                  child: Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
                ),
              )).toList()),
              const SizedBox(height: 14),

              // Row: volumen + precio
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label(widget.categoriaBase == 'CEMENTO' ? 'Cantidad (Big Bags)' : (widget.categoriaBase == 'ARENA' || widget.categoriaBase == 'PIEDRA' ? 'Volumen (M3)' : 'Volumen / Cantidad')),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, color: Color(0xFF0284C7), size: 18),
                  const SizedBox(width: 8),
                  Text('TOTAL: S/ ${_totalCalc.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF003366), fontSize: 15)),
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
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF003366), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0284C7)),
            const SizedBox(width: 10),
            const Text('Fecha del registro:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13)),
            const Spacer(),
            Text('${_fecha.day.toString().padLeft(2,'0')}/${_fecha.month.toString().padLeft(2,'0')}/${_fecha.year}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF003366), fontSize: 14)),
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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF004899), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
      );
} 
