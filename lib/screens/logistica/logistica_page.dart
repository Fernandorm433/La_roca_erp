// Archivo: lib/screens/logistica/logistica_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// MODELO — fuente: despachos_produccion
// ─────────────────────────────────────────────────────────────

class GuiaDespacho {
  final String id;
  final String numeroGuia; // orden_carguio
  final String estado;
  final String cliente;
  final double volumen; // volumen_guias (lo que realmente despachó el mixer)
  final double volumenProg; // volumen (lo programado)
  final String diseno;
  final String conductor; // operador
  final String mixer;
  final String bomba;
  final String fecha;

  GuiaDespacho({
    required this.id,
    required this.numeroGuia,
    required this.estado,
    required this.cliente,
    required this.volumen,
    required this.volumenProg,
    required this.diseno,
    required this.conductor,
    required this.mixer,
    required this.bomba,
    required this.fecha,
  });

  /// Mapea directamente desde despachos_produccion
  factory GuiaDespacho.fromDespacho(Map<String, dynamic> m) {
    final volGuias =
        double.tryParse(m['volumen_guias']?.toString() ?? '0') ?? 0;
    final volProg = double.tryParse(m['volumen']?.toString() ?? '0') ?? 0;

    return GuiaDespacho(
      id: m['id']?.toString() ?? '',
      // orden_carguio como número de guía; si es null mostramos "—"
      numeroGuia: m['orden_carguio'] != null ? 'OC-${m['orden_carguio']}' : '—',
      estado: m['estado']?.toString() ?? 'programada',
      cliente: m['cliente']?.toString() ?? 'Sin cliente',
      volumen: volGuias,
      volumenProg: volProg,
      diseno: m['diseno_guias']?.toString().isNotEmpty == true
          ? m['diseno_guias'].toString()
          : m['diseno']?.toString() ?? '—',
      conductor: m['operador']?.toString() ?? '—',
      mixer: m['mixer']?.toString() ?? '—',
      bomba: m['bomba']?.toString() ?? '—',
      fecha: m['fecha']?.toString() ?? '',
    );
  }
}

class ConductorModel {
  final String id;
  final String nombre;
  final String placa;
  final String tipoLicencia;
  final String marca;

  ConductorModel({
    required this.id,
    required this.nombre,
    required this.placa,
    required this.tipoLicencia,
    required this.marca,
  });

  factory ConductorModel.fromMap(Map<String, dynamic> m) => ConductorModel(
    id: m['id']?.toString() ?? '',
    nombre: m['nombre']?.toString() ?? '',
    placa: m['placa']?.toString() ?? '—',
    tipoLicencia:
        m['tipo_licencia']?.toString() ?? m['licencia']?.toString() ?? '—',
    marca: m['marca']?.toString() ?? '—',
  );
}

// ─────────────────────────────────────────────────────────────
// CONFIG DE ESTADOS
// ─────────────────────────────────────────────────────────────

const Map<String, Map<String, dynamic>> _estadoCfg = {
  'programada': {
    'color': Color(0xFF6366F1),
    'bg': Color(0xFFEEF2FF),
    'label': 'Programada',
    'icon': Icons.schedule_outlined,
  },
  'en_transito': {
    'color': Color(0xFFF59E0B),
    'bg': Color(0xFFFFFBEB),
    'label': 'En Tránsito',
    'icon': Icons.local_shipping_outlined,
  },
  'entregada': {
    'color': Color(0xFF10B981),
    'bg': Color(0xFFECFDF5),
    'label': 'Entregada',
    'icon': Icons.check_circle_outline,
  },
  'anulada': {
    'color': Color(0xFFEF4444),
    'bg': Color(0xFFFEF2F2),
    'label': 'Anulada',
    'icon': Icons.cancel_outlined,
  },
};

// ─────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL
// ─────────────────────────────────────────────────────────────

class LogisticaPage extends StatefulWidget {
  const LogisticaPage({super.key});
  @override
  State<LogisticaPage> createState() => _LogisticaPageState();
}

class _LogisticaPageState extends State<LogisticaPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<GuiaDespacho> _guias = [];
  List<ConductorModel> _conductores = [];
  bool _loading = true;
  String _filtroEstado = 'todos';
  DateTime _fecha = DateTime.now();

  // ── Métricas calculadas ──────────────────────────────────────
  int get _programadas => _guias.where((g) => g.estado == 'programada').length;
  int get _enTransito => _guias.where((g) => g.estado == 'en_transito').length;
  int get _entregadas => _guias.where((g) => g.estado == 'entregada').length;

  /// Suma de volumen_guias (real despachado) excluyendo anuladas
  double get _volTotal => _guias
      .where((g) => g.estado != 'anulada')
      .fold(0, (s, g) => s + g.volumen);

  /// Suma del volumen programado (para comparar vs real)
  double get _volProgramado => _guias
      .where((g) => g.estado != 'anulada')
      .fold(0, (s, g) => s + g.volumenProg);

  List<GuiaDespacho> get _filtradas => _filtroEstado == 'todos'
      ? _guias
      : _guias.where((g) => g.estado == _filtroEstado).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    await Future.wait([_cargarGuias(), _cargarConductores()]);
    if (mounted) setState(() => _loading = false);
  }

  // ── Carga desde despachos_produccion ─────────────────────────
  Future<void> _cargarGuias() async {
    try {
      final fecha = _fecha.toIso8601String().split('T')[0];
      final data = await supabase
          .from('despachos_produccion')
          .select(
            'id, orden_carguio, cliente, operador, mixer, bomba, '
            'volumen, volumen_guias, diseno, diseno_guias, estado, fecha',
          )
          .eq('fecha', fecha)
          .order('orden_carguio');

      if (mounted) {
        setState(() {
          _guias = (data as List)
              .map((m) => GuiaDespacho.fromDespacho(m))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('guias error: $e');
    }
  }

  Future<void> _cargarConductores() async {
    try {
      final data = await supabase.from('conductores').select().order('nombre');
      if (mounted) {
        setState(() {
          _conductores = (data as List)
              .map((m) => ConductorModel.fromMap(m))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('conductores error: $e');
    }
  }

  /// Actualiza el campo estado en despachos_produccion
  Future<void> _actualizarEstado(String id, String nuevoEstado) async {
    try {
      await supabase
          .from('despachos_produccion')
          .update({'estado': nuevoEstado})
          .eq('id', id);
      _cargarGuias();
    } catch (e) {
      debugPrint('update estado: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Column(
              children: [
                _buildHeader(),
                _buildMetricas(),
                _buildFechaYTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_tabGuias(), _tabConductores()],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primaryDark, Color(0xFF1E3A5F)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logística',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_guias.length} despachos · ${_conductores.length} conductores',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _cargarDatos,
        ),
      ],
    ),
  ).animate().fade().slideY(begin: -0.05);

  // ── Métricas ─────────────────────────────────────────────────
  Widget _buildMetricas() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        _metCard('Prog.', _programadas, const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        _metCard('En Ruta', _enTransito, AppColors.warning),
        const SizedBox(width: 8),
        _metCard('Entregadas', _entregadas, AppColors.success),
        const SizedBox(width: 8),
        // Muestra volumen real (volumen_guias)
        _metCard(
          '${_volTotal.toStringAsFixed(1)}m³',
          null,
          AppColors.accent,
          sub: 'Volumen',
        ),
      ],
    ),
  ).animate().fade(delay: 80.ms);

  Widget _metCard(String val, int? count, Color c, {String? sub}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            count != null ? '$count' : val,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            sub ?? val,
            style: TextStyle(
              color: c.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  // ── Fecha + Tabs ─────────────────────────────────────────────
  Widget _buildFechaYTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Column(
      children: [
        InkWell(
          onTap: () async {
            final sel = await showDatePicker(
              context: context,
              initialDate: _fecha,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primaryDark,
                  ),
                ),
                child: child!,
              ),
            );
            if (sel != null) {
              setState(() => _fecha = sel);
              _cargarGuias();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.expand_more, size: 16, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.accent,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Guías (${_guias.length})',
              ),
              Tab(
                icon: const Icon(Icons.person_outline, size: 18),
                text: 'Conductores (${_conductores.length})',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── TAB 1: GUÍAS ─────────────────────────────────────────────

  Widget _tabGuias() => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            _filtroChip('todos', 'Todas (${_guias.length})'),
            ..._estadoCfg.entries.map((e) {
              final c = e.value['color'] as Color;
              final cnt = _guias.where((g) => g.estado == e.key).length;
              return _filtroChip(e.key, '${e.value['label']} ($cnt)', color: c);
            }),
          ],
        ),
      ),
      // Barra de comparación volumen programado vs real (solo si hay datos)
      if (_guias.isNotEmpty && _volProgramado > 0) _buildBarraVolumen(),
      Expanded(
        child: _filtradas.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sin guías para esta fecha',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _filtradas.length,
                itemBuilder: (ctx, i) => _guiaCard(_filtradas[i], i),
              ),
      ),
    ],
  );

  /// Barra de progreso: volumen real vs programado
  Widget _buildBarraVolumen() {
    final pct = _volProgramado > 0
        ? (_volTotal / _volProgramado).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Volumen despachado vs programado',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_volTotal.toStringAsFixed(1)} / ${_volProgramado.toStringAsFixed(1)} m³',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 1.0 ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtroChip(String estado, String label, {Color? color}) {
    final activo = _filtroEstado == estado;
    final c = color ?? AppColors.primaryDark;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = estado),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? c : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: activo ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _guiaCard(GuiaDespacho g, int i) {
    final cfg = _estadoCfg[g.estado] ?? _estadoCfg['programada']!;
    final color = cfg['color'] as Color;
    final bgColor = cfg['bg'] as Color;
    final icon = cfg['icon'] as IconData;
    final label = cfg['label'] as String;

    // Diferencia entre volumen programado y real
    final diff = g.volumen - g.volumenProg;
    final hasDiff = diff.abs() > 0.01;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _DetalleDespachoSheet(
            guia: g,
            onCambiarEstado: _actualizarEstado,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Número de orden
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      g.numeroGuia,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 11, color: color),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Volumen real (volumen_guias)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${g.volumen.toStringAsFixed(1)} m³',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      // Diferencia vs programado (si existe)
                      if (hasDiff)
                        Text(
                          '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} vs prog.',
                          style: TextStyle(
                            fontSize: 10,
                            color: diff > 0
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Cliente
              Text(
                g.cliente,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Chips: mixer, operador, diseño, bomba
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _chip(Icons.local_shipping_outlined, g.mixer),
                  _chip(Icons.person_outline, g.conductor),
                  if (g.diseno != '—') _chip(Icons.science_outlined, g.diseno),
                  if (g.bomba.isNotEmpty && g.bomba != '—' && g.bomba != 'null')
                    _chip(Icons.fire_truck_outlined, g.bomba),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(delay: (i * 50).ms).slideX(begin: 0.04);
  }

  Widget _chip(IconData icon, String txt) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Text(
        txt,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  // ── TAB 2: CONDUCTORES ───────────────────────────────────────

  Widget _tabConductores() {
    if (_conductores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin conductores registrados',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: _conductores.length,
      itemBuilder: (ctx, i) {
        final c = _conductores[i];
        // Busca cuántos despachos del día tienen a este conductor (operador)
        final despacchosHoy = _guias
            .where(
              (g) => g.conductor.toLowerCase().contains(c.nombre.toLowerCase()),
            )
            .length;
        final volHoy = _guias
            .where(
              (g) =>
                  g.conductor.toLowerCase().contains(c.nombre.toLowerCase()) &&
                  g.estado != 'anulada',
            )
            .fold(0.0, (s, g) => s + g.volumen);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent.withOpacity(0.1),
                  child: Text(
                    c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        children: [
                          _chip(Icons.directions_car_outlined, c.placa),
                          _chip(Icons.badge_outlined, c.tipoLicencia),
                          if (c.marca != '—')
                            _chip(Icons.local_shipping_outlined, c.marca),
                        ],
                      ),
                    ],
                  ),
                ),
                // Resumen del día para este conductor
                if (despacchosHoy > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$despacchosHoy despacho${despacchosHoy > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (volHoy > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${volHoy.toStringAsFixed(1)} m³',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ).animate().fade(delay: (i * 60).ms).slideX(begin: 0.05);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET — DETALLE Y CAMBIO DE ESTADO
// ─────────────────────────────────────────────────────────────

class _DetalleDespachoSheet extends StatelessWidget {
  final GuiaDespacho guia;
  final Future<void> Function(String id, String estado) onCambiarEstado;

  const _DetalleDespachoSheet({
    required this.guia,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _estadoCfg[guia.estado] ?? _estadoCfg['programada']!;
    final color = cfg['color'] as Color;

    const transiciones = {
      'programada': 'en_transito',
      'en_transito': 'entregada',
    };
    final sig = transiciones[guia.estado];
    final sigCfg = sig != null ? _estadoCfg[sig] : null;

    final diff = guia.volumen - guia.volumenProg;
    final hasDiff = diff.abs() > 0.01;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Encabezado
              Row(
                children: [
                  Text(
                    guia.numeroGuia,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cfg['label'] as String,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Grid de datos
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _dato(
                      context,
                      Icons.person_outline,
                      'Cliente',
                      guia.cliente,
                    ),
                    _dato(
                      context,
                      Icons.science_outlined,
                      'Diseño',
                      guia.diseno,
                    ),
                    _dato(
                      context,
                      Icons.water_drop_outlined,
                      'Vol. real (guías)',
                      '${guia.volumen.toStringAsFixed(2)} m³',
                    ),
                    _dato(
                      context,
                      Icons.architecture_outlined,
                      'Vol. programado',
                      '${guia.volumenProg.toStringAsFixed(2)} m³',
                    ),
                    if (hasDiff)
                      _dato(
                        context,
                        diff > 0 ? Icons.trending_up : Icons.trending_down,
                        'Diferencia',
                        '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)} m³',
                        valueColor: diff > 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    _dato(
                      context,
                      Icons.local_shipping_outlined,
                      'Mixer',
                      guia.mixer,
                    ),
                    _dato(
                      context,
                      Icons.badge_outlined,
                      'Operador',
                      guia.conductor,
                    ),
                    if (guia.bomba != '—' && guia.bomba.isNotEmpty)
                      _dato(
                        context,
                        Icons.fire_truck_outlined,
                        'Bomba',
                        guia.bomba,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Botón avanzar estado
              if (sigCfg != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onCambiarEstado(guia.id, sig!);
                    },
                    icon: Icon(sigCfg['icon'] as IconData),
                    label: Text('Marcar como ${sigCfg['label']}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: sigCfg['color'] as Color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Botón anular
              if (guia.estado != 'anulada' && guia.estado != 'entregada')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onCambiarEstado(guia.id, 'anulada');
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Anular despacho',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _dato(
    BuildContext context,
    IconData icon,
    String label,
    String valor, {
    Color? valueColor,
  }) => SizedBox(
    width: (MediaQuery.of(context).size.width - 80) / 2,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
