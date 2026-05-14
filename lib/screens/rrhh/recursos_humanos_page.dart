// ══════════════════════════════════════════════════════════════════
// Archivo: lib/screens/rrhh/recursos_humanos_page.dart
// VERSIÓN UNIFICADA: Estética moderna + funcionalidad completa
// ══════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart' as official_picker;
import '../../core/theme/app_colors.dart';

// ──────────────────────────────────────────────────────────────────
// MODELO
// ──────────────────────────────────────────────────────────────────

class Empleado {
  final String id;
  final String nombres;
  final String apellidos;
  final String cargo;
  final String area;
  final String dni;
  final double sueldoBase;
  final bool activo;
  final String? telefono;
  final String? fechaIngreso;

  Empleado({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.cargo,
    required this.area,
    required this.dni,
    required this.sueldoBase,
    required this.activo,
    this.telefono,
    this.fechaIngreso,
  });

  factory Empleado.fromMap(Map<String, dynamic> m) => Empleado(
    id: m['id']?.toString() ?? '',
    nombres: m['nombres']?.toString() ?? '',
    apellidos: m['apellidos']?.toString() ?? '',
    cargo: m['cargo']?.toString() ?? '—',
    area: m['area']?.toString() ?? '—',
    dni: m['dni']?.toString() ?? '—',
    sueldoBase: double.tryParse(m['sueldo_base']?.toString() ?? '0') ?? 0,
    activo: m['activo'] == true,
    telefono: m['telefono']?.toString(),
    fechaIngreso: m['fecha_ingreso']?.toString(),
  );

  String get iniciales {
    final n = nombres.isNotEmpty ? nombres[0] : '';
    final a = apellidos.isNotEmpty ? apellidos[0] : '';
    return '$n$a'.toUpperCase();
  }

  String get nombreCompleto => '$nombres $apellidos'.trim();
}

// ──────────────────────────────────────────────────────────────────
// PALETA DE AVATARES
// ──────────────────────────────────────────────────────────────────

const _avatarPalette = [
  Color(0xFF4F46E5),
  Color(0xFF0D9488),
  Color(0xFFD97706),
  Color(0xFFDB2777),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFDC2626),
  Color(0xFF2563EB),
];

Color _avatarColor(String id) {
  final hash = id.codeUnits.fold(0, (s, c) => s + c);
  return _avatarPalette[hash % _avatarPalette.length];
}

// ──────────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL
// ──────────────────────────────────────────────────────────────────

class RecursosHumanosPage extends StatefulWidget {
  const RecursosHumanosPage({super.key});

  @override
  State<RecursosHumanosPage> createState() => _RecursosHumanosPageState();
}

class _RecursosHumanosPageState extends State<RecursosHumanosPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  // ── Estructura organizacional ──────────────────────────────────
  final Map<String, List<String>> _estructuraEmpresa = {
    'Administración': ['Gerente General', 'RRHH', 'Contabilidad'],
    'Ventas': ['Jefatura de Ventas', 'Asesor de Ventas', 'Atención al Cliente'],
    'Calidad': [
      'Jefatura de Calidad',
      'Técnico de Calidad',
      'Practicante de Calidad',
    ],
    'Producción': [
      'Jefe de Planta',
      'Operador de Mixer',
      'Operador de Bomba',
      'Ayudante',
    ],
    'Logística': [
      'Jefatura de Logística',
      'Asistente de Logística',
      'Almacenero',
    ],
  };

  // ── Estado ────────────────────────────────────────────────────
  List<Empleado> _empleados = [];
  List<Map<String, dynamic>> _asistencias = [];
  List<Map<String, dynamic>> _planilla = [];
  List<Map<String, dynamic>> _comunicados = [];
  List<Map<String, dynamic>> _usuarios = [];

  bool _loadingE = true,
      _loadingA = true,
      _loadingP = true,
      _loadingC = true,
      _loadingU = true;

  String _busqueda = '';
  String _filtroArea = 'todos';
  int _mesSeleccionado = DateTime.now().month;
  final int _anio = DateTime.now().year;

  // ── Getters ───────────────────────────────────────────────────
  double get _planillaTotal => _planilla.fold(
    0,
    (s, p) => s + ((p['total_neto'] as num?)?.toDouble() ?? 0),
  );

  List<Empleado> get _filtrados {
    var lista = _empleados;
    if (_filtroArea != 'todos') {
      lista = lista.where((e) => e.area == _filtroArea).toList();
    }
    if (_busqueda.isNotEmpty) {
      lista = lista
          .where(
            (e) =>
                e.nombreCompleto.toLowerCase().contains(
                  _busqueda.toLowerCase(),
                ) ||
                e.cargo.toLowerCase().contains(_busqueda.toLowerCase()),
          )
          .toList();
    }
    return lista;
  }

  List<String> get _areas =>
      _empleados.map((e) => e.area).where((a) => a != '—').toSet().toList()
        ..sort();

  // ══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // CARGA DE DATOS
  // ══════════════════════════════════════════════════════════════

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarEmpleados(),
      _cargarAsistencias(),
      _cargarPlanilla(),
      _cargarComunicados(),
      _cargarUsuarios(),
    ]);
  }

  Future<void> _cargarEmpleados() async {
    setState(() => _loadingE = true);
    try {
      final data = await supabase.from('empleados').select().order('apellidos');
      if (mounted) {
        setState(() {
          _empleados = (data as List).map((m) => Empleado.fromMap(m)).toList();
          _loadingE = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingE = false);
    }
  }

  Future<void> _cargarAsistencias() async {
    setState(() => _loadingA = true);
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final data = await supabase
          .from('asistencia_empleados')
          .select('*, empleados(nombres, apellidos, cargo, area)')
          .eq('fecha', hoy)
          .order('hora_entrada');
      if (mounted) {
        setState(() {
          _asistencias = List<Map<String, dynamic>>.from(data);
          _loadingA = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingA = false);
    }
  }

  Future<void> _cargarPlanilla() async {
    setState(() => _loadingP = true);
    try {
      final mes = '$_anio-${_mesSeleccionado.toString().padLeft(2, '0')}';
      final data = await supabase
          .from('planilla_mensual')
          .select('*, empleados(nombres, apellidos, cargo)')
          .like('periodo', '$mes%')
          .order('id');
      if (mounted) {
        setState(() {
          _planilla = List<Map<String, dynamic>>.from(data);
          _loadingP = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingP = false);
    }
  }

  Future<void> _cargarComunicados() async {
    setState(() => _loadingC = true);
    try {
      final data = await supabase
          .from('comunicados')
          .select()
          .order('fecha', ascending: false);
      if (mounted) {
        setState(() {
          _comunicados = List<Map<String, dynamic>>.from(data);
          _loadingC = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingC = false);
    }
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _loadingU = true);
    try {
      final data = await supabase
          .from('usuarios')
          .select()
          .order('creado_en', ascending: false);
      if (mounted) {
        setState(() {
          _usuarios = List<Map<String, dynamic>>.from(data);
          _loadingU = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
      if (mounted) setState(() => _loadingU = false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: Column(
        children: [
          _buildHero(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _tabPersonal(),
                _tabAsistencia(),
                _tabPlanilla(),
                _tabComunicados(),
                _tabAccesos(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (ctx, _) {
          switch (_tabController.index) {
            case 0:
              return FloatingActionButton.extended(
                onPressed: () => _abrirFormEmpleado(),
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Empleado'),
              );
            case 1:
              return FloatingActionButton.extended(
                onPressed: _registrarAsistencia,
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.how_to_reg_outlined),
                label: const Text('Asistencia'),
              );
            case 3:
              return FloatingActionButton.extended(
                onPressed: _abrirFormComunicado,
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Nuevo Aviso'),
              );
            case 4:
              return FloatingActionButton.extended(
                onPressed: () => _abrirFormUsuario(),
                backgroundColor: Colors.indigo.shade800,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Nuevo Acceso'),
              );
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HERO CABECERA con gradiente y KPIs
  // ══════════════════════════════════════════════════════════════

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recursos Humanos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gestión integral del capital humano',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cargarTodo,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _kpiHero(
                    'Personal',
                    '${_empleados.length}',
                    Icons.people_alt_outlined,
                    const Color(0xFF818CF8),
                  ),
                  const SizedBox(width: 10),
                  _kpiHero(
                    'Accesos',
                    '${_usuarios.length}',
                    Icons.vpn_key_outlined,
                    const Color(0xFF34D399),
                  ),
                  const SizedBox(width: 10),
                  _kpiHero(
                    'Avisos',
                    '${_comunicados.length}',
                    Icons.campaign_outlined,
                    const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 10),
                  _kpiHero(
                    'Planilla',
                    'S/${_planillaTotal >= 1000 ? '${(_planillaTotal / 1000).toStringAsFixed(1)}K' : _planillaTotal.toStringAsFixed(0)}',
                    Icons.payments_outlined,
                    const Color(0xFFF472B6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().slideY(begin: -0.05);
  }

  Widget _kpiHero(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB BAR MODERNO
  // ══════════════════════════════════════════════════════════════

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF4F46E5),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicator: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined, size: 16), text: 'Personal'),
            Tab(
              icon: Icon(Icons.calendar_today_outlined, size: 16),
              text: 'Asistencia',
            ),
            Tab(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 16),
              text: 'Planilla',
            ),
            Tab(icon: Icon(Icons.campaign_outlined, size: 16), text: 'Avisos'),
            Tab(icon: Icon(Icons.security_outlined, size: 16), text: 'Accesos'),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 1: PERSONAL
  // ══════════════════════════════════════════════════════════════

  Widget _tabPersonal() {
    if (_loadingE) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }

    return Column(
      children: [
        // Buscador
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o cargo...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5)),
              filled: true,
              fillColor: const Color(0xFFF4F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
        ),
        // Filtro por área
        Container(
          color: Colors.white,
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _areaChip('todos', 'Todos (${_empleados.length})'),
              ..._areas.map(
                (a) => _areaChip(
                  a,
                  '$a (${_empleados.where((e) => e.area == a).length})',
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        // Lista
        Expanded(
          child: _filtrados.isEmpty
              ? _emptyState(
                  'No se encontraron empleados',
                  Icons.people_outline,
                  accion: 'Agregar Empleado',
                  onAccion: () => _abrirFormEmpleado(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _filtrados.length,
                  itemBuilder: (ctx, i) => _empleadoCard(_filtrados[i], i),
                ),
        ),
      ],
    );
  }

  Widget _areaChip(String val, String label) {
    final selected = _filtroArea == val;
    return GestureDetector(
      onTap: () => setState(() => _filtroArea = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : const Color(0xFFF4F7FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _empleadoCard(Empleado e, int i) {
    final color = _avatarColor(e.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _verPerfilEmpleado(e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  e.iniciales,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.nombreCompleto,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.cargo,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _miniTag(
                          e.area,
                          const Color(0xFFEDE9FE),
                          const Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 6),
                        _miniTag(
                          e.activo ? 'Activo' : 'Inactivo',
                          e.activo
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          e.activo
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sueldo + acciones
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/${e.sueldoBase.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconAction(
                        Icons.edit_outlined,
                        const Color(0xFF4F46E5),
                        () => _abrirFormEmpleado(empleado: e),
                        'Editar',
                      ),
                      const SizedBox(width: 2),
                      _iconAction(
                        Icons.receipt_long_outlined,
                        const Color(0xFF0D9488),
                        () => _mostrarDialogBoleta(e),
                        'Boleta',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
  }

  Widget _iconAction(
    IconData icon,
    Color color,
    VoidCallback onTap,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );

  // ══════════════════════════════════════════════════════════════
  // TAB 2: ASISTENCIA
  // ══════════════════════════════════════════════════════════════

  Widget _tabAsistencia() {
    if (_loadingA) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }

    final hoy = DateTime.now();
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final fechaFmt = '${hoy.day} de ${meses[hoy.month - 1]} de ${hoy.year}';

    // Resumen del día
    final presentes = _asistencias
        .where((a) => a['estado'] == 'presente')
        .length;
    final tarde = _asistencias.where((a) => a['estado'] == 'tarde').length;
    final faltas = _asistencias.where((a) => a['estado'] == 'falta').length;

    return Column(
      children: [
        // Header del día
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Asistencia de Hoy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          fechaFmt,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_asistencias.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _asistResumen(
                      '$presentes',
                      'Presentes',
                      const Color(0xFFD1FAE5),
                      const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    _asistResumen(
                      '$tarde',
                      'Tarde',
                      const Color(0xFFFEF3C7),
                      const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    _asistResumen(
                      '$faltas',
                      'Faltas',
                      const Color(0xFFFEE2E2),
                      const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    _asistResumen(
                      '${_asistencias.length}',
                      'Total',
                      const Color(0xFFEDE9FE),
                      const Color(0xFF4F46E5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _asistencias.isEmpty
              ? _emptyState(
                  'Sin asistencias registradas hoy',
                  Icons.event_busy_outlined,
                  accion: 'Registrar Asistencia',
                  onAccion: _registrarAsistencia,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _asistencias.length,
                  itemBuilder: (ctx, i) {
                    final a = _asistencias[i];
                    final emp = a['empleados'] as Map<String, dynamic>?;
                    final nombre = emp != null
                        ? '${emp['nombres']} ${emp['apellidos']}'
                        : 'Empleado';
                    final cargo = emp?['cargo'] ?? '—';
                    final estado = a['estado']?.toString() ?? 'presente';
                    final horaE = a['hora_entrada']?.toString() ?? '—';
                    final horaS = a['hora_salida']?.toString() ?? 'Sin salida';
                    final (iconD, colorD) = _estadoAsist(estado);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorD.withOpacity(0.15),
                            child: Icon(iconD, color: colorD, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  cargo,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _miniTag(
                                estado.toUpperCase(),
                                colorD.withOpacity(0.12),
                                colorD,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '↑ $horaE  ↓ $horaS',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fade(delay: (i * 40).ms);
                  },
                ),
        ),
      ],
    );
  }

  Widget _asistResumen(String valor, String label, Color bg, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _estadoAsist(String estado) {
    switch (estado.toLowerCase()) {
      case 'tarde':
        return (Icons.access_time, const Color(0xFFD97706));
      case 'falta':
        return (Icons.cancel_outlined, const Color(0xFFDC2626));
      case 'permiso':
        return (Icons.verified_outlined, const Color(0xFF2563EB));
      default:
        return (Icons.check_circle_outline, const Color(0xFF059669));
    }
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 3: PLANILLA
  // ══════════════════════════════════════════════════════════════

  static const _meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  Widget _tabPlanilla() {
    return Column(
      children: [
        // Selector de mes
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    color: Color(0xFF4F46E5),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Planilla $_anio — Selecciona el mes',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 12,
                  itemBuilder: (ctx, i) {
                    final sel = _mesSeleccionado == i + 1;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _mesSeleccionado = i + 1);
                        _cargarPlanilla();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFF4F7FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF4F46E5)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          _meses[i],
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_loadingP && _planilla.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Planilla: S/${_planillaTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_planilla.length} empleados',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Lista de planillas
        Expanded(
          child: _loadingP
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                )
              : _planilla.isEmpty
              ? _emptyState(
                  'Sin planilla para ${_meses[_mesSeleccionado - 1]} $_anio',
                  Icons.account_balance_wallet_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _planilla.length,
                  itemBuilder: (ctx, i) {
                    final p = _planilla[i];
                    final emp = p['empleados'] as Map<String, dynamic>?;
                    final nombre = emp != null
                        ? '${emp['nombres']} ${emp['apellidos']}'
                        : 'Empleado';
                    final cargo = emp?['cargo'] ?? '—';
                    final bruto = (p['sueldo_bruto'] as num?)?.toDouble() ?? 0;
                    final descuentos =
                        (p['total_descuentos'] as num?)?.toDouble() ?? 0;
                    final neto = (p['total_neto'] as num?)?.toDouble() ?? 0;
                    final color = _avatarColor(
                      p['empleado_id']?.toString() ?? i.toString(),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: color.withOpacity(0.15),
                                child: Text(
                                  nombre.isNotEmpty ? nombre[0] : '?',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      cargo,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'S/${neto.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  Text(
                                    'Neto a pagar',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _planillaFila(
                                'Sueldo Bruto',
                                bruto,
                                const Color(0xFF059669),
                              ),
                              const SizedBox(width: 8),
                              _planillaFila(
                                'Descuentos',
                                descuentos,
                                const Color(0xFFDC2626),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fade(delay: (i * 40).ms);
                  },
                ),
        ),
      ],
    );
  }

  Widget _planillaFila(String label, double valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'S/${valor.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 4: AVISOS / COMUNICADOS
  // ══════════════════════════════════════════════════════════════

  Widget _tabComunicados() {
    if (_loadingC) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }
    if (_comunicados.isEmpty) {
      return _emptyState(
        'No hay avisos publicados',
        Icons.campaign_outlined,
        accion: 'Publicar Aviso',
        onAccion: _abrirFormComunicado,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _comunicados.length,
      itemBuilder: (ctx, i) {
        final c = _comunicados[i];
        final importancia = c['importancia']?.toString() ?? 'media';

        final (bgColor, iconColor, iconD) = switch (importancia) {
          'alta' => (
            const Color(0xFFFEF2F2),
            const Color(0xFFDC2626),
            Icons.warning_amber_rounded,
          ),
          'baja' => (
            const Color(0xFFF0FDF4),
            const Color(0xFF059669),
            Icons.info_outline,
          ),
          _ => (
            const Color(0xFFEFF6FF),
            const Color(0xFF2563EB),
            Icons.campaign_outlined,
          ),
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconD, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c['titulo'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _miniTag(importancia.toUpperCase(), bgColor, iconColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c['mensaje'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c['fecha'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 5: ACCESOS
  // ══════════════════════════════════════════════════════════════

  Widget _tabAccesos() {
    if (_loadingU) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }
    if (_usuarios.isEmpty) {
      return _emptyState(
        'No hay usuarios creados',
        Icons.vpn_key_off_outlined,
        accion: 'Crear Acceso',
        onAccion: () => _abrirFormUsuario(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _usuarios.length,
      itemBuilder: (ctx, i) {
        final u = _usuarios[i];
        final nombre = u['nombre'] ?? 'Sin Nombre';
        final rol = u['rol'] ?? 'empleados';
        final color = _avatarColor(u['id'] ?? i.toString());
        final (rolColor, rolBg) = _rolColors(rol);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _miniTag(rol.toUpperCase(), rolBg, rolColor),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF4F46E5),
                  ),
                  tooltip: 'Editar Acceso',
                  onPressed: () => _abrirFormUsuario(usuario: u),
                ),
              ],
            ),
          ),
        ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
      },
    );
  }

  (Color, Color) _rolColors(String rol) {
    return switch (rol) {
      'admin' => (const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      'programacion' => (const Color(0xFF0D9488), const Color(0xFFF0FDFA)),
      'calidad' => (const Color(0xFFD97706), const Color(0xFFFFFBEB)),
      'ventas' => (const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      'asesor' => (const Color(0xFFDB2777), const Color(0xFFFDF2F8)),
      'operador' => (const Color(0xFF059669), const Color(0xFFF0FDF4)),
      _ => (const Color(0xFF64748B), const Color(0xFFF8FAFC)),
    };
  }

  // ══════════════════════════════════════════════════════════════
  // PERFIL DE EMPLEADO (Bottom Sheet)
  // ══════════════════════════════════════════════════════════════

  void _verPerfilEmpleado(Empleado e) {
    final color = _avatarColor(e.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 40,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  e.iniciales,
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                e.nombreCompleto,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                e.cargo,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniTag(
                    e.area,
                    const Color(0xFFEDE9FE),
                    const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 8),
                  _miniTag(
                    e.activo ? 'Activo' : 'Inactivo',
                    e.activo
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    e.activo
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _perfilFila(Icons.badge, 'DNI', e.dni),
              _perfilFila(
                Icons.payments_outlined,
                'Sueldo Base',
                'S/${e.sueldoBase.toStringAsFixed(2)}',
                color: const Color(0xFF4F46E5),
              ),
              if (e.telefono != null && e.telefono!.isNotEmpty)
                _perfilFila(Icons.phone_outlined, 'Teléfono', e.telefono!),
              if (e.fechaIngreso != null && e.fechaIngreso!.isNotEmpty)
                _perfilFila(
                  Icons.calendar_today_outlined,
                  'Fecha de Ingreso',
                  e.fechaIngreso!,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _abrirFormEmpleado(empleado: e);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mostrarDialogBoleta(e);
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Subir Boleta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _perfilFila(
    IconData icon,
    String label,
    String valor, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const Spacer(),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // FORM: EMPLEADO (crear / editar)
  // ══════════════════════════════════════════════════════════════

  void _abrirFormEmpleado({Empleado? empleado}) {
    final esEdicion = empleado != null;
    final nombresCtrl = TextEditingController(text: empleado?.nombres ?? '');
    final apellidosCtrl = TextEditingController(
      text: empleado?.apellidos ?? '',
    );
    final dniCtrl = TextEditingController(text: empleado?.dni ?? '');
    final sueldoCtrl = TextEditingController(
      text: (empleado?.sueldoBase ?? 0) > 0
          ? empleado!.sueldoBase.toStringAsFixed(0)
          : '',
    );
    final telefonoCtrl = TextEditingController(text: empleado?.telefono ?? '');

    String area = (empleado?.area != null && empleado!.area != '—')
        ? empleado.area
        : _estructuraEmpresa.keys.first;
    String cargo = (empleado?.cargo != null && empleado!.cargo != '—')
        ? empleado.cargo
        : _estructuraEmpresa[area]!.first;
    bool activo = empleado?.activo ?? true;
    bool guardando = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      esEdicion
                          ? 'Editar Perfil de Empleado'
                          : 'Registrar Nuevo Empleado',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            nombresCtrl,
                            'Nombres *',
                            Icons.person_outline,
                            requerido: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _input(
                            apellidosCtrl,
                            'Apellidos *',
                            Icons.person,
                            requerido: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            dniCtrl,
                            'DNI *',
                            Icons.badge,
                            requerido: true,
                            kb: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _input(
                            sueldoCtrl,
                            'Sueldo Base (S/) *',
                            Icons.attach_money,
                            requerido: true,
                            kb: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _input(
                      telefonoCtrl,
                      'Teléfono (opcional)',
                      Icons.phone_outlined,
                      kb: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    // Dropdown Área
                    DropdownButtonFormField<String>(
                      initialValue: area,
                      decoration: InputDecoration(
                        labelText: 'Área de Trabajo *',
                        prefixIcon: const Icon(
                          Icons.business_outlined,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: _estructuraEmpresa.keys
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (val) => setS(() {
                        area = val!;
                        cargo = _estructuraEmpresa[val]!.first;
                      }),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown Cargo (dinámico según área)
                    DropdownButtonFormField<String>(
                      initialValue: cargo,
                      decoration: InputDecoration(
                        labelText: 'Cargo Específico *',
                        prefixIcon: const Icon(
                          Icons.work_outline,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: _estructuraEmpresa[area]!
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) => setS(() => cargo = val!),
                    ),
                    const SizedBox(height: 16),
                    // Toggle activo
                    Row(
                      children: [
                        const Text(
                          'Estado del empleado:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Switch(
                          value: activo,
                          activeThumbColor: const Color(0xFF4F46E5),
                          onChanged: (v) => setS(() => activo = v),
                        ),
                        _miniTag(
                          activo ? 'Activo' : 'Inactivo',
                          activo
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          activo
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setS(() => guardando = true);
                                try {
                                  final datos = {
                                    'nombres': nombresCtrl.text.trim(),
                                    'apellidos': apellidosCtrl.text.trim(),
                                    'dni': dniCtrl.text.trim(),
                                    'sueldo_base':
                                        double.tryParse(
                                          sueldoCtrl.text.trim(),
                                        ) ??
                                        0,
                                    'area': area,
                                    'cargo': cargo,
                                    'activo': activo,
                                    'telefono': telefonoCtrl.text.trim().isEmpty
                                        ? null
                                        : telefonoCtrl.text.trim(),
                                  };
                                  if (esEdicion) {
                                    await supabase
                                        .from('empleados')
                                        .update(datos)
                                        .eq('id', empleado.id);
                                  } else {
                                    await supabase
                                        .from('empleados')
                                        .insert(datos);
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  _cargarEmpleados();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        esEdicion
                                            ? 'Empleado actualizado correctamente'
                                            : 'Empleado registrado exitosamente',
                                      ),
                                      backgroundColor: const Color(0xFF059669),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint('Error empleado: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Error al guardar. Revisa la consola.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  setS(() => guardando = false);
                                }
                              },
                        icon: guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          guardando
                              ? 'Guardando...'
                              : esEdicion
                              ? 'Actualizar Ficha'
                              : 'Registrar Empleado',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // FORM: REGISTRAR ASISTENCIA
  // ══════════════════════════════════════════════════════════════

  void _registrarAsistencia() {
    String? empId;
    String estado = 'presente';
    final horaCtrl = TextEditingController(
      text: TimeOfDay.now().format(context),
    );
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Registrar Asistencia',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: empId,
                  decoration: InputDecoration(
                    labelText: 'Empleado *',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF0D9488),
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  hint: const Text('Selecciona el empleado'),
                  items: _empleados
                      .where((e) => e.activo)
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.nombreCompleto),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setS(() => empId = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: const Icon(
                      Icons.flag_outlined,
                      color: Color(0xFF0D9488),
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'presente',
                      child: Text('✅  PRESENTE'),
                    ),
                    DropdownMenuItem(value: 'tarde', child: Text('⚠️  TARDE')),
                    DropdownMenuItem(
                      value: 'permiso',
                      child: Text('🔵  PERMISO'),
                    ),
                    DropdownMenuItem(value: 'falta', child: Text('❌  FALTA')),
                  ],
                  onChanged: (val) => setS(() => estado = val!),
                ),
                const SizedBox(height: 16),
                _input(horaCtrl, 'Hora de Entrada', Icons.access_time_outlined),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (guardando || empId == null)
                        ? null
                        : () async {
                            setS(() => guardando = true);
                            try {
                              final hoy = DateTime.now()
                                  .toIso8601String()
                                  .split('T')[0];
                              await supabase
                                  .from('asistencia_empleados')
                                  .insert({
                                    'empleado_id': empId,
                                    'fecha': hoy,
                                    'estado': estado,
                                    'hora_entrada': horaCtrl.text.trim(),
                                  });
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              _cargarAsistencias();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Asistencia registrada'),
                                  backgroundColor: Color(0xFF059669),
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error asistencia: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error al registrar'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setS(() => guardando = false);
                            }
                          },
                    icon: guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.how_to_reg_outlined),
                    label: const Text('Guardar Asistencia'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BOLETAS DE PAGO (PDF Upload a Supabase Storage)
  // ══════════════════════════════════════════════════════════════

  void _mostrarDialogBoleta(Empleado e) {
    final mesCtrl = TextEditingController(
      text: '$_anio-${_mesSeleccionado.toString().padLeft(2, '0')}',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Subir Boleta de Pago',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _avatarColor(e.id).withOpacity(0.2),
                    child: Text(
                      e.iniciales,
                      style: TextStyle(
                        color: _avatarColor(e.id),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.nombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          e.cargo,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mesCtrl,
              decoration: InputDecoration(
                labelText: 'Periodo (YYYY-MM)',
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _subirBoleta(e.id, mesCtrl.text.trim());
            },
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Seleccionar PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _subirBoleta(String empleadoId, String mesAnio) async {
    try {
      final result = await official_picker.FilePicker.pickFiles(
        type: official_picker.FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final Uint8List fileBytes = result.files.single.bytes!;
        final String fileName = 'boleta_${empleadoId}_$mesAnio.pdf';

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Subiendo boleta...')));

        await supabase.storage
            .from('boletas')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Boleta subida exitosamente'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error subiendo boleta: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al subir la boleta'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // FORM: COMUNICADO
  // ══════════════════════════════════════════════════════════════

  void _abrirFormComunicado() {
    final tituloCtrl = TextEditingController();
    final mensajeCtrl = TextEditingController();
    String importancia = 'media';
    bool publicando = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Publicar Nuevo Aviso',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _input(
                      tituloCtrl,
                      'Título del Aviso *',
                      Icons.title,
                      requerido: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: mensajeCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Mensaje *',
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF4F46E5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: importancia,
                      decoration: InputDecoration(
                        labelText: 'Importancia',
                        prefixIcon: const Icon(
                          Icons.priority_high,
                          color: Color(0xFF4F46E5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'baja',
                          child: Text('🟢  BAJA'),
                        ),
                        DropdownMenuItem(
                          value: 'media',
                          child: Text('🔵  MEDIA'),
                        ),
                        DropdownMenuItem(
                          value: 'alta',
                          child: Text('🔴  ALTA / URGENTE'),
                        ),
                      ],
                      onChanged: (val) => setS(() => importancia = val!),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: publicando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setS(() => publicando = true);
                                try {
                                  await supabase.from('comunicados').insert({
                                    'titulo': tituloCtrl.text.trim(),
                                    'mensaje': mensajeCtrl.text.trim(),
                                    'importancia': importancia,
                                    'fecha': DateTime.now()
                                        .toIso8601String()
                                        .split('T')[0],
                                  });
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  _cargarComunicados();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Aviso publicado exitosamente',
                                      ),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint('Error: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Error al publicar el aviso',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  setS(() => publicando = false);
                                }
                              },
                        icon: publicando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Publicar Aviso'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // FORM: USUARIO / ACCESO ERP
  // ══════════════════════════════════════════════════════════════

  void _abrirFormUsuario({Map<String, dynamic>? usuario}) {
    final esEdicion = usuario != null;
    final nombreCtrl = TextEditingController(
      text: esEdicion ? usuario['nombre'] : '',
    );
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String rol = esEdicion ? (usuario['rol'] ?? 'empleados') : 'empleados';
    const roles = [
      'admin',
      'programacion',
      'calidad',
      'ventas',
      'asesor',
      'operador',
      'empleados',
    ];
    bool guardando = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      esEdicion
                          ? 'Editar Acceso Existente'
                          : 'Crear Nuevo Acceso ERP',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      esEdicion
                          ? 'Modifica el nombre o rol del usuario en el sistema.'
                          : 'Se creará una cuenta con el rol asignado.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _input(
                      nombreCtrl,
                      'Nombre Completo *',
                      Icons.person_outline,
                      requerido: true,
                    ),
                    if (!esEdicion) ...[
                      const SizedBox(height: 16),
                      _input(
                        emailCtrl,
                        'Correo Electrónico *',
                        Icons.email_outlined,
                        requerido: true,
                        kb: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _input(
                        passCtrl,
                        'Contraseña (mín. 6 caracteres) *',
                        Icons.lock_outline,
                        requerido: true,
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: rol,
                      decoration: InputDecoration(
                        labelText: 'Rol en el Sistema *',
                        prefixIcon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Color(0xFF4F46E5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setS(() => rol = val!),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                if (!esEdicion && passCtrl.text.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'La contraseña debe tener al menos 6 caracteres',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setS(() => guardando = true);
                                try {
                                  if (esEdicion) {
                                    await supabase
                                        .from('usuarios')
                                        .update({
                                          'nombre': nombreCtrl.text.trim(),
                                          'rol': rol,
                                        })
                                        .eq('id', usuario['id']);
                                  } else {
                                    final tempClient = SupabaseClient(
                                      // ⚠️ REEMPLAZA con tus propias credenciales si cambian
                                      "https://rppchistprnodthwtuxt.supabase.co",
                                      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwcGNoaXN0cHJub2R0aHd0dXh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzkzODIsImV4cCI6MjA4ODIxNTM4Mn0.w-6cx-VTGPs-y5rlLh48nrPlQtVoo2FMF6KwfH52YeE",
                                      authOptions: const AuthClientOptions(
                                        authFlowType: AuthFlowType.implicit,
                                      ),
                                    );
                                    final AuthResponse res = await tempClient
                                        .auth
                                        .signUp(
                                          email: emailCtrl.text.trim(),
                                          password: passCtrl.text.trim(),
                                        );
                                    if (res.user != null) {
                                      await supabase.from('usuarios').insert({
                                        'id': res.user!.id,
                                        'nombre': nombreCtrl.text.trim(),
                                        'rol': rol,
                                      });
                                    } else {
                                      throw Exception(
                                        'No se pudo crear el usuario.',
                                      );
                                    }
                                    tempClient.dispose();
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  _cargarUsuarios();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        esEdicion
                                            ? 'Acceso actualizado'
                                            : 'Usuario creado exitosamente',
                                      ),
                                      backgroundColor: const Color(0xFF059669),
                                    ),
                                  );
                                } on AuthException catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error Auth: ${e.message}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  setS(() => guardando = false);
                                } catch (e) {
                                  debugPrint('Error acceso: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Error al guardar. Revisa la consola.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  setS(() => guardando = false);
                                }
                              },
                        icon: guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          esEdicion
                              ? 'Actualizar Acceso'
                              : 'Crear y Otorgar Acceso',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS REUTILIZABLES
  // ══════════════════════════════════════════════════════════════

  Widget _input(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool requerido = false,
    TextInputType kb = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: kb,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      validator: requerido
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : null,
    );
  }

  Widget _emptyState(
    String msg,
    IconData icon, {
    String? accion,
    VoidCallback? onAccion,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (accion != null && onAccion != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAccion,
                icon: const Icon(Icons.add),
                label: Text(accion),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _StrExt on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}
