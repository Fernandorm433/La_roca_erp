import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_database/services/sunat_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:app_database/core/utils/sunat_pdf_generator.dart';
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────

enum _GREStatus { pendiente, enviado, aceptado }

class _FilaGuiaGRE {
  final String idCarguio;
  final String ordenCarga;
  final String numeroCarguioCA;
  final double volumen;
  final String operadorNombre;
  final String codigoMixer;
  final String precinto;
  final String horaSalida;
  final Map<String, dynamic> ventaData;
  Map<String, dynamic>? guiaSunatData;

  _FilaGuiaGRE({
    required this.idCarguio,
    required this.ordenCarga,
    required this.numeroCarguioCA,
    required this.volumen,
    required this.operadorNombre,
    required this.codigoMixer,
    required this.precinto,
    required this.horaSalida,
    required this.ventaData,
    this.guiaSunatData,
  });

  _GREStatus get status {
    if (guiaSunatData == null) return _GREStatus.pendiente;
    final estado = (guiaSunatData!['estado_sunat'] ?? '').toString().toUpperCase();
    if (estado == 'ACEPTADO') return _GREStatus.aceptado;
    if (estado == 'ENVIADO') return _GREStatus.enviado;
    return _GREStatus.pendiente;
  }

  String get serieCorrelativo {
    if (guiaSunatData != null) {
      return 'T001 - ${guiaSunatData!['correlativo'] ?? '00000000'}';
    }
    return 'T001 - PENDIENTE';
  }

  String get clienteNombre => ventaData['nombre_razon_social'] ?? 'Sin cliente';
  String get clienteRuc => ventaData['dni_ruc'] ?? '';
  String get direccionDestino => ventaData['direccion'] ?? 'Dirección no registrada';
  String get fechaEmision {
    if (guiaSunatData != null && guiaSunatData!['created_at'] != null) {
      return guiaSunatData!['created_at'].toString().split('T').first;
    }
    return DateTime.now().toString().split(' ').first;
  }
}

// ─────────────────────────────────────────────────────────────
// COLORS & CONSTANTS
// ─────────────────────────────────────────────────────────────

const _kDarkBg = Color(0xFF0F172A);
const _kDarkCard = Color(0xFF1E293B);
const _kDarkSurface = Color(0xFF162032);
const _kAccentPurple = Color(0xFF8B5CF6);
const _kAccentBlue = Color(0xFF3B82F6);
const _kAccentCyan = Color(0xFF06B6D4);
const _kAccentGreen = Color(0xFF10B981);
const _kAccentAmber = Color(0xFFF59E0B);
const _kAccentRed = Color(0xFFEF4444);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);
const _kBorder = Color(0xFF334155);

// ─────────────────────────────────────────────────────────────
// MAIN PAGE WIDGET
// ─────────────────────────────────────────────────────────────

class GuiasSunatPage extends StatefulWidget {
  const GuiasSunatPage({super.key});

  @override
  State<GuiasSunatPage> createState() => _GuiasSunatPageState();
}

class _GuiasSunatPageState extends State<GuiasSunatPage>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final SunatService _sunatService = SunatService();

  bool _isLoading = false;
  List<_FilaGuiaGRE> _allItems = [];

  // Date range filter
  DateTimeRange? _dateRange;

  // Search
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter
  _GREStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Computed filtered list ──────────────────────────────
  List<_FilaGuiaGRE> get _filteredItems {
    var items = List<_FilaGuiaGRE>.from(_allItems);

    // Status filter
    if (_statusFilter != null) {
      items = items.where((i) => i.status == _statusFilter).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) {
        return i.clienteNombre.toLowerCase().contains(q) ||
            i.clienteRuc.contains(q) ||
            i.codigoMixer.toLowerCase().contains(q) ||
            i.operadorNombre.toLowerCase().contains(q) ||
            i.serieCorrelativo.toLowerCase().contains(q);
      }).toList();
    }

    return items;
  }

  int get _totalCount => _allItems.length;
  int get _pendientesCount =>
      _allItems.where((i) => i.status == _GREStatus.pendiente).length;
  int get _enviadasCount =>
      _allItems.where((i) => i.status == _GREStatus.enviado).length;
  int get _aceptadasCount =>
      _allItems.where((i) => i.status == _GREStatus.aceptado).length;

  // ─── DATA LOADING ────────────────────────────────────────
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ventas FACTURA/BOLETA
      var ventasQuery = _supabase
          .from('ventas_programacion')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      final ventasRes = await ventasQuery;

      List<Map<String, dynamic>> ventasFiltradas = [];
      for (var v in ventasRes) {
        String tipo = (v['tipo_documento']?.toString() ?? '').toUpperCase();
        if (tipo == 'FACTURA' || tipo == 'BOLETA') {
          // Date range filter
          if (_dateRange != null && v['created_at'] != null) {
            final createdAt = DateTime.tryParse(v['created_at'].toString());
            if (createdAt != null) {
              final start = DateTime(
                  _dateRange!.start.year,
                  _dateRange!.start.month,
                  _dateRange!.start.day);
              final end = DateTime(_dateRange!.end.year,
                  _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
              if (createdAt.isBefore(start) || createdAt.isAfter(end)) continue;
            }
          }
          ventasFiltradas.add(v);
        }
      }

      if (ventasFiltradas.isEmpty) {
        setState(() {
          _allItems = [];
          _isLoading = false;
        });
        return;
      }

      List<String> idsVentas =
          ventasFiltradas.map((e) => e['id'].toString()).toList();

      // 2. Carguios
      final carguiosRes = await _supabase
          .from('carguio_mezcla')
          .select()
          .inFilter('id_venta', idsVentas)
          .order('orden_carga', ascending: true);

      // 3. Guías de remisión existentes (all states)
      final guiasRes =
          await _supabase.from('guias_remision').select();

      // Map guías by carguio id (stored in cotizacion_id)
      final Map<String, dynamic> guiasPorCarguio = {};
      for (var g in guiasRes) {
        guiasPorCarguio[g['cotizacion_id'].toString()] = g;
      }

      List<_FilaGuiaGRE> allItems = [];

      for (var c in carguiosRes) {
        final idVenta = c['id_venta'].toString();
        final venta = ventasFiltradas.firstWhere(
            (v) => v['id'].toString() == idVenta,
            orElse: () => {});

        if (venta.isEmpty) continue;

        final idCarguio = c['id'].toString();
        final guia = guiasPorCarguio[idCarguio];

        allItems.add(_FilaGuiaGRE(
          idCarguio: idCarguio,
          ordenCarga: c['orden_carga']?.toString() ?? '',
          numeroCarguioCA: c['numero_carguio']?.toString() ?? '',
          volumen: double.tryParse(c['volumen_carguio'].toString()) ?? 0.0,
          operadorNombre: c['operador_nombre']?.toString() ?? '',
          codigoMixer: c['codigo_mixer']?.toString() ?? '',
          precinto: c['precinto']?.toString() ?? '',
          horaSalida: c['hora_salida']?.toString() ?? '',
          ventaData: venta,
          guiaSunatData: guia,
        ));
      }

      setState(() => _allItems = allItems);
    } catch (e) {
      debugPrint('Error cargando guías: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── ACTIONS ─────────────────────────────────────────────
  Future<void> _emitirGRE(_FilaGuiaGRE fila) async {
    if (fila.precinto.isEmpty || fila.horaSalida.isEmpty) {
      _showSnackbar(
        'Complete el precinto y hora de salida en Despachos antes de emitir.',
        _kAccentAmber,
        Icons.warning_amber_rounded,
      );
      return;
    }

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kDarkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kAccentPurple, _kAccentBlue]),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            const Text('Emitir GRE',
                style: TextStyle(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
          ],
        ),
        content: Text(
          '¿Enviar Guía de Remisión a SUNAT para el viaje #${fila.ordenCarga} del mixer ${fila.codigoMixer}?',
          style: const TextStyle(color: _kTextSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _kTextSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kAccentPurple, _kAccentBlue]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Emitir',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showSnackbar(
        'Conectando con SUNAT...', _kAccentBlue, Icons.cloud_upload_outlined);

    final res = await _sunatService.emitirGuiaRemision(
      serie: 'T001',
      correlativo: 101,
      clienteDocumento: fila.ventaData['dni_ruc'] ?? '20123456789',
      cotizacionId: fila.idCarguio,
    );

    if (res != null) {
      if (mounted) {
        _showSnackbar(
          'GRE emitida exitosamente — Viaje #${fila.ordenCarga}',
          _kAccentGreen,
          Icons.check_circle_rounded,
        );
      }
      _cargarDatos();
    } else {
      if (mounted) {
        _showSnackbar(
            'Error al emitir la GRE', _kAccentRed, Icons.error_outline);
      }
    }
  }

  Future<void> _verPdfGuia(_FilaGuiaGRE fila) async {
    final guiaData = fila.guiaSunatData ?? {};
    final venta = fila.ventaData;

    final dataPDF = {
      'serie_correlativo': 'T001 - ${guiaData['correlativo'] ?? '00002048'}',
      'fecha_emision': fila.fechaEmision,
      'fecha_traslado': fila.fechaEmision,
      'op_nro': venta['orden_pedido'] ?? '',
      'domicilio_llegada': venta['direccion'] ?? 'Obra registrada',
      'cliente_nombre': venta['nombre_razon_social'] ?? '',
      'cliente_documento': venta['dni_ruc'] ?? '',
      'conductor': fila.operadorNombre,
      'licencia': '',
      'placa': fila.codigoMixer,
      'factura_ref': '',
      'diseno': venta['diseno'] ?? '',
      'slump': venta['slump'] ?? '',
      'huso': venta['huso'] ?? '',
      'aditivo': venta['aditivo'] ?? '',
      'bomba': venta['bomba'] ?? '',
      'cemento': venta['tipo_cemento'] ?? '',
      'hora_salida': fila.horaSalida,
      'precinto': fila.precinto,
      'volumen': fila.volumen.toStringAsFixed(2),
    };

    try {
      final pdfBytes = await SunatPdfGenerator.generarGRE(dataPDF);
      await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'GRE_${dataPDF['serie_correlativo']}.pdf');
    } catch (e) {
      if (mounted) {
        _showSnackbar(
            'Error generando PDF: $e', _kAccentRed, Icons.error_outline);
      }
    }
  }

  void _descargarXml(_FilaGuiaGRE fila) {
    // Generate a simple XML representation and share
    final guiaData = fila.guiaSunatData ?? {};
    final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<GuiaRemision>
  <Serie>T001</Serie>
  <Correlativo>${guiaData['correlativo'] ?? '00000000'}</Correlativo>
  <FechaEmision>${fila.fechaEmision}</FechaEmision>
  <Destinatario>
    <Nombre>${fila.clienteNombre}</Nombre>
    <Documento>${fila.clienteRuc}</Documento>
  </Destinatario>
  <DirLlegada>${fila.direccionDestino}</DirLlegada>
  <Conductor>${fila.operadorNombre}</Conductor>
  <Placa>${fila.codigoMixer}</Placa>
  <Volumen>${fila.volumen}</Volumen>
  <EstadoSunat>${guiaData['estado_sunat'] ?? 'PENDIENTE'}</EstadoSunat>
</GuiaRemision>''';

    // Use Printing to share as text via PDF (simplest cross-platform approach)
    _showSnackbar(
      'XML generado (${xml.length} bytes) — compartir no disponible aún',
      _kAccentCyan,
      Icons.code_rounded,
    );
  }

  void _showSnackbar(String msg, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
    ));
  }

  // ─── DATE PICKER ─────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kAccentPurple,
              onPrimary: Colors.white,
              surface: _kDarkCard,
              onSurface: _kTextPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _kDarkBg),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _cargarDatos();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Container(
      color: _kDarkBg,
      child: Column(
        children: [
          _buildHeader(),
          _buildStatsBar(),
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildGreList(filtered),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1040),
            Color(0xFF0F172A),
            Color(0xFF0C1929),
          ],
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kAccentPurple, _kAccentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kAccentPurple.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 28),
          ).animate().scale(
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(width: 20),

          // Title / Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historial de Guías de Remisión',
                  style: TextStyle(
                    color: _kTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fade(duration: 500.ms)
                    .slideX(begin: -0.1, duration: 500.ms),
                const SizedBox(height: 4),
                Text(
                  '$_totalCount guías registradas  •  GRE — SUNAT',
                  style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                )
                    .animate()
                    .fade(delay: 200.ms, duration: 500.ms)
                    .slideX(begin: -0.1, delay: 200.ms, duration: 500.ms),
              ],
            ),
          ),

          // Date range button
          _GlassButton(
            onTap: _pickDateRange,
            icon: Icons.calendar_month_rounded,
            label: _dateRange != null
                ? '${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}'
                : 'Filtrar fechas',
          ).animate().fade(delay: 300.ms, duration: 500.ms),

          if (_dateRange != null) ...[
            const SizedBox(width: 8),
            _GlassButton(
              onTap: () {
                setState(() => _dateRange = null);
                _cargarDatos();
              },
              icon: Icons.close_rounded,
              label: '',
              compact: true,
            ).animate().fade(delay: 350.ms, duration: 400.ms),
          ],

          const SizedBox(width: 12),

          // Refresh button
          _GlassButton(
            onTap: _cargarDatos,
            icon: Icons.refresh_rounded,
            label: '',
            compact: true,
          ).animate().fade(delay: 400.ms, duration: 500.ms),
        ],
      ),
    );
  }

  // ─── STATS BAR ───────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: _kDarkSurface,
        border: Border(
          bottom: BorderSide(color: _kBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildStatCard(
            'Total Guías',
            _totalCount.toString(),
            Icons.description_outlined,
            _kAccentBlue,
            0,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Pendientes',
            _pendientesCount.toString(),
            Icons.hourglass_bottom_rounded,
            _kAccentAmber,
            1,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Enviadas',
            _enviadasCount.toString(),
            Icons.cloud_upload_outlined,
            _kAccentCyan,
            2,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Aceptadas',
            _aceptadasCount.toString(),
            Icons.verified_rounded,
            _kAccentGreen,
            3,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String count, IconData icon, Color color, int index) {
    final isActive = (_statusFilter == null && index == 0) ||
        (_statusFilter == _GREStatus.pendiente && index == 1) ||
        (_statusFilter == _GREStatus.enviado && index == 2) ||
        (_statusFilter == _GREStatus.aceptado && index == 3);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (index == 0) {
              _statusFilter = null;
            } else if (index == 1) {
              _statusFilter =
                  _statusFilter == _GREStatus.pendiente ? null : _GREStatus.pendiente;
            } else if (index == 2) {
              _statusFilter =
                  _statusFilter == _GREStatus.enviado ? null : _GREStatus.enviado;
            } else {
              _statusFilter =
                  _statusFilter == _GREStatus.aceptado ? null : _GREStatus.aceptado;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.12)
                : _kDarkCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.4) : _kBorder.withValues(alpha: 0.4),
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      color: _kTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: _kTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
          .animate()
          .fade(delay: Duration(milliseconds: 100 + index * 80), duration: 500.ms)
          .slideY(
              begin: 0.15,
              delay: Duration(milliseconds: 100 + index * 80),
              duration: 500.ms),
    );
  }

  // ─── SEARCH & FILTER BAR ────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
      decoration: const BoxDecoration(
        color: _kDarkBg,
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.3)),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _kDarkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, RUC, mixer, conductor...',
                  hintStyle: TextStyle(
                      color: _kTextSecondary.withValues(alpha: 0.6),
                      fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _kTextSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: _kTextSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kDarkCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_filteredItems.length} resultados',
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 400.ms, duration: 400.ms);
  }

  // ─── LOADING STATE ───────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                  _kAccentPurple.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cargando guías de remisión...',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kAccentPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 52, color: _kAccentPurple.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin guías de remisión',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron resultados para "$_searchQuery"'
                : 'No hay despachos de Factura/Boleta en el rango seleccionado.',
            style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  // ─── LIST ────────────────────────────────────────────────
  Widget _buildGreList(List<_FilaGuiaGRE> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildGreCard(items[index], index);
      },
    );
  }

  // ─── CARD ────────────────────────────────────────────────
  Widget _buildGreCard(_FilaGuiaGRE fila, int index) {
    final status = fila.status;
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final statusIcon = _statusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kDarkCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Card Header ───────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border:
                  Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                // Serie / Correlativo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kDarkBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2_rounded,
                          size: 14, color: _kAccentPurple.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        fila.serieCorrelativo,
                        style: const TextStyle(
                          color: _kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Date
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: _kTextSecondary.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  fila.fechaEmision,
                  style: const TextStyle(
                      color: _kTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),

                const Spacer(),

                // Volume badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kAccentCyan.withValues(alpha: 0.15),
                        _kAccentBlue.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kAccentCyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop_rounded,
                          size: 13, color: _kAccentCyan),
                      const SizedBox(width: 5),
                      Text(
                        '${fila.volumen.toStringAsFixed(1)} m³',
                        style: const TextStyle(
                          color: _kAccentCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Card Body ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip number
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kAccentPurple.withValues(alpha: 0.15),
                        _kAccentBlue.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _kAccentPurple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${fila.ordenCarga}',
                        style: const TextStyle(
                          color: _kAccentPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'VIAJE',
                        style: TextStyle(
                          color: _kTextSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 18),

                // Client + Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client name
                      Text(
                        fila.clienteNombre,
                        style: const TextStyle(
                          color: _kTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // RUC
                      if (fila.clienteRuc.isNotEmpty)
                        Text(
                          'RUC: ${fila.clienteRuc}',
                          style: TextStyle(
                            color: _kTextSecondary.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Detail chips row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _detailChip(Icons.location_on_outlined,
                              fila.direccionDestino, _kAccentPurple),
                          _detailChip(Icons.local_shipping_rounded,
                              fila.codigoMixer.isEmpty ? 'Sin asignar' : fila.codigoMixer,
                              _kAccentBlue),
                          _detailChip(Icons.person_outline_rounded,
                              fila.operadorNombre.isEmpty ? 'Sin operador' : fila.operadorNombre,
                              _kAccentCyan),
                          if (fila.precinto.isNotEmpty)
                            _detailChip(Icons.lock_outline_rounded,
                                'Precinto: ${fila.precinto}', _kAccentAmber),
                          if (fila.horaSalida.isNotEmpty)
                            _detailChip(Icons.schedule_rounded,
                                'Salida: ${fila.horaSalida}', _kAccentGreen),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Action buttons
                _buildActionButtons(fila, status),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(
            delay: Duration(milliseconds: 60 * index.clamp(0, 15)),
            duration: 400.ms)
        .slideY(
            begin: 0.06,
            delay: Duration(milliseconds: 60 * index.clamp(0, 15)),
            duration: 400.ms,
            curve: Curves.easeOut);
  }

  Widget _detailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              style: TextStyle(
                color: _kTextSecondary.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ──────────────────────────────────────
  Widget _buildActionButtons(_FilaGuiaGRE fila, _GREStatus status) {
    if (status == _GREStatus.pendiente) {
      return Column(
        children: [
          // Emitir GRE — prominent gradient button
          _GradientActionButton(
            onTap: () => _emitirGRE(fila),
            icon: Icons.send_rounded,
            label: 'Enviar a SUNAT',
            colors: const [_kAccentPurple, _kAccentBlue],
          ),
          const SizedBox(height: 8),
          _ActionChip(
            onTap: () => _verPdfGuia(fila),
            icon: Icons.picture_as_pdf_rounded,
            label: 'Ver PDF',
            color: _kTextSecondary,
          ),
        ],
      );
    }

    // ENVIADO or ACEPTADO
    return Column(
      children: [
        _ActionChip(
          onTap: () => _verPdfGuia(fila),
          icon: Icons.picture_as_pdf_rounded,
          label: 'Ver PDF',
          color: _kAccentGreen,
        ),
        const SizedBox(height: 6),
        _ActionChip(
          onTap: () => _descargarXml(fila),
          icon: Icons.code_rounded,
          label: 'XML',
          color: _kAccentCyan,
        ),
        const SizedBox(height: 6),
        _ActionChip(
          onTap: () => _emitirGRE(fila),
          icon: Icons.replay_rounded,
          label: 'Reenviar',
          color: _kTextSecondary,
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Color _statusColor(_GREStatus s) {
    switch (s) {
      case _GREStatus.pendiente:
        return _kAccentAmber;
      case _GREStatus.enviado:
        return _kAccentCyan;
      case _GREStatus.aceptado:
        return _kAccentGreen;
    }
  }

  String _statusLabel(_GREStatus s) {
    switch (s) {
      case _GREStatus.pendiente:
        return 'PENDIENTE';
      case _GREStatus.enviado:
        return 'ENVIADO';
      case _GREStatus.aceptado:
        return 'ACEPTADO';
    }
  }

  IconData _statusIcon(_GREStatus s) {
    switch (s) {
      case _GREStatus.pendiente:
        return Icons.hourglass_bottom_rounded;
      case _GREStatus.enviado:
        return Icons.cloud_done_outlined;
      case _GREStatus.aceptado:
        return Icons.verified_rounded;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════

/// Glass-effect header button
class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final bool compact;

  const _GlassButton({
    required this.onTap,
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kTextSecondary, size: 18),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient action button (prominent)
class _GradientActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final List<Color> colors;

  const _GradientActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small action chip button
class _ActionChip extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;

  const _ActionChip({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
