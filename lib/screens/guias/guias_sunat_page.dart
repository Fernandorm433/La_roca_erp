import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_database/services/sunat_service.dart';
import 'package:app_database/core/utils/sunat_pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────

enum _GREStatus { pendiente, aceptado, error }

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
    if (estado == 'ERROR') return _GREStatus.error;
    return _GREStatus.pendiente;
  }

  String get serieCorrelativo {
    if (guiaSunatData != null && guiaSunatData!['correlativo'] != null) {
      final cor = guiaSunatData!['correlativo'].toString().padLeft(8, '0');
      return 'T001 - $cor';
    }
    return 'T001 - POR ASIGNAR';
  }

  String? get mensajeSunat => guiaSunatData?['mensaje_sunat'];
  String? get pdfUrl => guiaSunatData?['pdf_url'];
  String? get xmlUrl => guiaSunatData?['xml_url'];
  String? get cdrUrl => guiaSunatData?['cdr_url'];

  String get clienteNombre => (ventaData['nombre_razon_social'] ?? 'Sin cliente').toString();
  String get clienteRuc => (ventaData['dni_ruc'] ?? '').toString();
  String get direccionDestino => (ventaData['direccion'] ?? 'Dirección no registrada').toString();
  String get fechaEmision {
    if (guiaSunatData != null && guiaSunatData!['created_at'] != null) {
      return guiaSunatData!['created_at'].toString().split('T').first;
    }
    return DateTime.now().toString().split(' ').first;
  }
}

// ─────────────────────────────────────────────────────────────
// PALETA DE COLORES CORPORATIVOS (AZUL, CELESTE, GRIS)
// ─────────────────────────────────────────────────────────────

const _kBrandNavy = Color(0xFF003366);
const _kBrandBlue = Color(0xFF004899);
const _kBrandCyan = Color(0xFF0284C7);
const _kLightCyan = Color(0xFFE0F2FE);
const _kPageBg = Color(0xFFF8FAFC);
const _kCardBg = Colors.white;
const _kBorderColor = Color(0xFFE2E8F0);
const _kTextDark = Color(0xFF0F172A);
const _kTextMuted = Color(0xFF64748B);
const _kAccentGreen = Color(0xFF10B981);
const _kAccentAmber = Color(0xFFF59E0B);
const _kAccentRed = Color(0xFFEF4444);

// ─────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL: GUÍAS DE REMISIÓN SUNAT
// ─────────────────────────────────────────────────────────────

class GuiasSunatPage extends StatefulWidget {
  const GuiasSunatPage({super.key});

  @override
  State<GuiasSunatPage> createState() => _GuiasSunatPageState();
}

class _GuiasSunatPageState extends State<GuiasSunatPage> {
  final _supabase = Supabase.instance.client;
  final SunatService _sunatService = SunatService();

  bool _isLoading = false;
  List<_FilaGuiaGRE> _allItems = [];

  // Filtro de rango de fechas
  DateTimeRange? _dateRange;

  // Búsqueda
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Filtro por estado
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

  // ─── Lista filtrada computada ─────────────────────────────
  List<_FilaGuiaGRE> get _filteredItems {
    var items = List<_FilaGuiaGRE>.from(_allItems);

    if (_statusFilter != null) {
      items = items.where((i) => i.status == _statusFilter).toList();
    }

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
  int get _aceptadasCount =>
      _allItems.where((i) => i.status == _GREStatus.aceptado).length;
  int get _errorCount =>
      _allItems.where((i) => i.status == _GREStatus.error).length;

  // ─── CARGA DE DATOS DESDE SUPABASE ───────────────────────
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ventas FACTURA / BOLETA
      final ventasRes = await _supabase
          .from('ventas_programacion')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      List<Map<String, dynamic>> ventasFiltradas = [];
      for (var v in ventasRes) {
        String tipo = (v['tipo_documento']?.toString() ?? '').toUpperCase();
        if (tipo == 'FACTURA' || tipo == 'BOLETA' || tipo.contains('GUIA')) {
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

      // 2. Carguíos de los mixers para estas ventas
      List<dynamic> carguiosRes = [];
      try {
        carguiosRes = await _supabase
            .from('carguios_mixers')
            .select()
            .inFilter('id_venta', idsVentas)
            .order('orden_carga', ascending: true);
      } catch (e) {
        debugPrint('Error cargando carguios_mixers: $e');
      }

      // 3. Guías de remisión registradas en base de datos
      List<dynamic> guiasRes = [];
      try {
        guiasRes = await _supabase.from('guias_remision').select();
      } catch (e) {
        debugPrint('Error cargando guias_remision: $e');
      }

      // Mapear guías por carguio_id o cotizacion_id
      final Map<String, dynamic> guiasPorCarguio = {};
      for (var g in guiasRes) {
        if (g['carguio_id'] != null) {
          guiasPorCarguio[g['carguio_id'].toString()] = g;
        }
        if (g['cotizacion_id'] != null) {
          guiasPorCarguio[g['cotizacion_id'].toString()] = g;
        }
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
          volumen: double.tryParse((c['volumen_carguio'] ?? c['volumen'] ?? 0).toString()) ?? 0.0,
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
      debugPrint('Error cargando datos de guías SUNAT: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ETAPA 1: REGISTRAR GUÍA LOCALMENTE Y DESCARGAR PDF PARA CHOFER
  // ─────────────────────────────────────────────────────────────
  Future<void> _descargarPdfChofer(_FilaGuiaGRE fila) async {
    Map<String, dynamic>? guiaData = fila.guiaSunatData;

    // Si aún no tiene registro en guias_remision, obtener correlativo y registrar localmente
    if (guiaData == null) {
      _showSnackbar('Obteniendo correlativo oficial...', _kBrandCyan, Icons.sync_rounded);

      final correlativo = await _sunatService.obtenerSiguienteCorrelativo(
        tipoDoc: '09',
        serie: 'T001',
      );

      final nuevaGuia = await _sunatService.registrarGuiaLocal(
        cotizacionId: fila.ventaData['id']?.toString() ?? fila.idCarguio,
        carguioId: fila.idCarguio,
        serie: 'T001',
        correlativo: correlativo,
        clienteDocumento: (fila.ventaData['dni_ruc'] ?? '20000000001').toString(),
        clienteNombre: (fila.ventaData['nombre_razon_social'] ?? 'CLIENTE GENERAL').toString(),
      );

      if (nuevaGuia != null) {
        guiaData = nuevaGuia;
        fila.guiaSunatData = nuevaGuia;
      }
    }

    final correlativoStr = (guiaData != null && guiaData['correlativo'] != null)
        ? guiaData['correlativo'].toString().padLeft(8, '0')
        : '00000000';

    final venta = fila.ventaData;

    final dataPDF = {
      'serie_correlativo': 'T001 - $correlativoStr',
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
      'bomba': venta['bombas'] ?? '',
      'cemento': venta['tipo_cemento'] ?? '',
      'hora_salida': fila.horaSalida,
      'precinto': fila.precinto,
      'volumen': fila.volumen.toStringAsFixed(2),
    };

    try {
      final pdfBytes = await SunatPdfGenerator.generarGRE(dataPDF);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'GRE_${dataPDF['serie_correlativo']}.pdf',
      );
      _cargarDatos();
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error al generar PDF: $e', _kAccentRed, Icons.error_outline);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ETAPA 2: ENVIAR A SUNAT (AL CIERRE DEL DÍA O POR BOTÓN INDIVIDUAL)
  // ─────────────────────────────────────────────────────────────
  Future<void> _enviarASunat(_FilaGuiaGRE fila) async {
    Map<String, dynamic>? guiaData = fila.guiaSunatData;

    // Asegurar que exista registro local previo con su número de correlativo
    if (guiaData == null) {
      final correlativo = await _sunatService.obtenerSiguienteCorrelativo(
        tipoDoc: '09',
        serie: 'T001',
      );

      guiaData = await _sunatService.registrarGuiaLocal(
        cotizacionId: fila.ventaData['id']?.toString() ?? fila.idCarguio,
        carguioId: fila.idCarguio,
        serie: 'T001',
        correlativo: correlativo,
        clienteDocumento: (fila.ventaData['dni_ruc'] ?? '20000000001').toString(),
        clienteNombre: (fila.ventaData['nombre_razon_social'] ?? 'CLIENTE GENERAL').toString(),
      );

      if (guiaData != null) {
        fila.guiaSunatData = guiaData;
      }
    }

    if (guiaData == null) {
      _showSnackbar('No se pudo inicializar la guía para el envío', _kAccentRed, Icons.error_outline);
      return;
    }

    final guiaId = guiaData['id'].toString();
    final serieCorrelativo = 'T001-${guiaData['correlativo'].toString().padLeft(8, '0')}';

    // Diálogo de confirmación antes de la transmisión oficial
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kBrandNavy, _kBrandCyan]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Enviar Guía a SUNAT',
                style: TextStyle(
                  color: _kTextDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Desea transmitir oficialmente la Guía Electrónica $serieCorrelativo a SUNAT en PRODUCCIÓN?\n\n'
          'Viaje #${fila.ordenCarga}  •  Mixer: ${fila.codigoMixer}\n'
          'Cliente: ${fila.clienteNombre}',
          style: const TextStyle(color: _kTextMuted, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kTextMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('🚀 Sí, Enviar a SUNAT', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Diálogo de carga no cancelable mientras APISUNAT responde
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: _kBrandCyan),
              SizedBox(height: 18),
              Text(
                'Transmitiendo GRE a SUNAT...',
                style: TextStyle(fontWeight: FontWeight.w800, color: _kTextDark, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'Validando datos en APISUNAT en vivo',
                style: TextStyle(color: _kTextMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    final res = await _sunatService.enviarGuiaASunat(guiaId);

    if (mounted) Navigator.pop(context); // Cierra diálogo de carga

    if (res['exito'] == true) {
      if (mounted) {
        _showSnackbar(
          '✅ GRE $serieCorrelativo ACEPTADA por SUNAT exitosamente',
          _kAccentGreen,
          Icons.verified_rounded,
        );
      }
      _cargarDatos();
    } else {
      // SUNAT RECHAZÓ O HUBO ERROR: Mostrar ventana detallada con la especificación exacta
      final errorDetalle = res['mensaje'] ?? 'Error desconocido al validar con SUNAT';
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kAccentRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: _kAccentRed, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Rechazado por SUNAT',
                    style: TextStyle(
                      color: _kAccentRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La Guía $serieCorrelativo no pudo ser procesada:',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: _kTextDark, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kAccentRed.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kAccentRed.withOpacity(0.2)),
                  ),
                  child: Text(
                    errorDetalle,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Corrija los datos correspondientes en Despachos (DNI chofer, placa o ubigeo) y presione Reintentar Envío.',
                  style: TextStyle(color: _kTextMuted, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido', style: TextStyle(color: _kTextMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _enviarASunat(fila);
                },
                child: const Text('🔄 Reintentar Envío'),
              ),
            ],
          ),
        );
      }
      _cargarDatos();
    }
  }

  void _abrirUrlOficial(String? url, String tipo) async {
    if (url == null || url.isEmpty) {
      _showSnackbar('Enlace no disponible', _kAccentAmber, Icons.warning_rounded);
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar('No se pudo abrir el archivo $tipo', _kAccentRed, Icons.error_outline);
    }
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
            child: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
    ));
  }

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
      color: _kPageBg,
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

  // ─── CABECERA CORPORATIVA CON LOGO Y TONALIDADES NOVA ─────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorderColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kBrandNavy, _kBrandBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kBrandBlue.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guías de Remisión Electrónica (GRE)',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kLightCyan,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SUNAT T001',
                        style: TextStyle(
                          color: _kBrandCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_totalCount guías de mixer registradas  •  Emisión local y envío programado',
                      style: const TextStyle(
                        color: _kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botón de filtro de fechas
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kTextDark,
              side: const BorderSide(color: _kBorderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18, color: _kBrandBlue),
            label: Text(
              _dateRange != null
                  ? '${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}'
                  : 'Filtrar fechas',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),

          if (_dateRange != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
              onPressed: () {
                setState(() => _dateRange = null);
                _cargarDatos();
              },
            ),
          ],

          const SizedBox(width: 10),

          IconButton.filledTonal(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _kLightCyan,
              foregroundColor: _kBrandCyan,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BARRA DE MÉTRICAS Y ESTADOS ──────────────────────────
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorderColor, width: 0.8)),
      ),
      child: Row(
        children: [
          _buildStatCard(
            'Total Despachos',
            _totalCount.toString(),
            Icons.receipt_long_rounded,
            _kBrandBlue,
            0,
          ),
          const SizedBox(width: 14),
          _buildStatCard(
            'Pendientes Envío',
            _pendientesCount.toString(),
            Icons.hourglass_bottom_rounded,
            _kAccentAmber,
            1,
          ),
          const SizedBox(width: 14),
          _buildStatCard(
            'Aceptadas SUNAT',
            _aceptadasCount.toString(),
            Icons.verified_rounded,
            _kAccentGreen,
            2,
          ),
          const SizedBox(width: 14),
          _buildStatCard(
            'Con Error / Observadas',
            _errorCount.toString(),
            Icons.error_outline_rounded,
            _kAccentRed,
            3,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color, int index) {
    final isActive = (_statusFilter == null && index == 0) ||
        (_statusFilter == _GREStatus.pendiente && index == 1) ||
        (_statusFilter == _GREStatus.aceptado && index == 2) ||
        (_statusFilter == _GREStatus.error && index == 3);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (index == 0) {
              _statusFilter = null;
            } else if (index == 1) {
              _statusFilter = _statusFilter == _GREStatus.pendiente ? null : _GREStatus.pendiente;
            } else if (index == 2) {
              _statusFilter = _statusFilter == _GREStatus.aceptado ? null : _GREStatus.aceptado;
            } else {
              _statusFilter = _statusFilter == _GREStatus.error ? null : _GREStatus.error;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.08) : _kPageBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : _kBorderColor,
              width: isActive ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      color: isActive ? color : _kTextDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: _kTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  // ─── BARRA DE BÚSQUEDA ────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: const BoxDecoration(
        color: _kPageBg,
        border: Border(bottom: BorderSide(color: _kBorderColor, width: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: _kTextDark, fontSize: 13, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, RUC, mixer, chofer, correlativo...',
                  hintStyle: const TextStyle(color: _kTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kTextMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: _kTextMuted, size: 18),
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
          Text(
            '${_filteredItems.length} guías encontradas',
            style: const TextStyle(color: _kTextMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _kBrandCyan),
          SizedBox(height: 16),
          Text('Cargando registros de guías...', style: TextStyle(color: _kTextMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No hay guías de remisión para mostrar',
            style: TextStyle(color: _kTextDark, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Ninguna guía coincide con "$_searchQuery"'
                : 'No se encontraron despachos con comprobante en la fecha seleccionada.',
            style: const TextStyle(color: _kTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGreList(List<_FilaGuiaGRE> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildGreCard(items[index]);
      },
    );
  }

  // ─── TARJETA DE GUÍA CON FLUJO DE 2 ETAPAS ────────────────
  Widget _buildGreCard(_FilaGuiaGRE fila) {
    final status = fila.status;
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case _GREStatus.pendiente:
        statusColor = _kAccentAmber;
        statusLabel = 'PENDIENTE DE ENVÍO';
        statusIcon = Icons.hourglass_bottom_rounded;
        break;
      case _GREStatus.aceptado:
        statusColor = _kAccentGreen;
        statusLabel = 'ACEPTADO SUNAT';
        statusIcon = Icons.verified_rounded;
        break;
      case _GREStatus.error:
        statusColor = _kAccentRed;
        statusLabel = 'ERROR SUNAT';
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == _GREStatus.error ? _kAccentRed.withOpacity(0.3) : _kBorderColor,
          width: status == _GREStatus.error ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header de la tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorderColor.withOpacity(0.6))),
            ),
            child: Row(
              children: [
                // Correlativo T001
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kBrandNavy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        fila.serieCorrelativo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  fila.fechaEmision,
                  style: const TextStyle(color: _kTextMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),

                const Spacer(),

                // Volumen
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kLightCyan,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${fila.volumen.toStringAsFixed(1)} m³ Concreto',
                    style: const TextStyle(color: _kBrandCyan, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),

                // Badge de Estado SUNAT
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cuerpo de datos del carguío
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identificador de viaje
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _kLightCyan,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBrandCyan.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${fila.ordenCarga}',
                        style: const TextStyle(
                          color: _kBrandBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'VIAJE',
                        style: TextStyle(
                          color: _kBrandCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),

                // Información del cliente y del traslado
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fila.clienteNombre,
                        style: const TextStyle(
                          color: _kTextDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (fila.clienteRuc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'RUC/DNI: ${fila.clienteRuc}',
                          style: const TextStyle(
                            color: _kTextMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Chips de detalles de obra y mixer
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chipDetalle(Icons.location_on_outlined, fila.direccionDestino, _kBrandCyan),
                          _chipDetalle(Icons.local_shipping_rounded, 'Mixer: ${fila.codigoMixer.isEmpty ? "Sin asignar" : fila.codigoMixer}', _kBrandNavy),
                          _chipDetalle(Icons.person_outline_rounded, 'Chofer: ${fila.operadorNombre.isEmpty ? "Sin chofer" : fila.operadorNombre}', _kBrandBlue),
                          if (fila.precinto.isNotEmpty)
                            _chipDetalle(Icons.lock_outline_rounded, 'Precinto: ${fila.precinto}', _kAccentAmber),
                          if (fila.horaSalida.isNotEmpty)
                            _chipDetalle(Icons.schedule_rounded, 'Salida: ${fila.horaSalida}', _kAccentGreen),
                        ],
                      ),

                      // Si el estado es ERROR, mostrar aviso visual con el error devuelto por SUNAT
                      if (status == _GREStatus.error && fila.mensajeSunat != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kAccentRed.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kAccentRed.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: _kAccentRed, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'SUNAT: ${fila.mensajeSunat}',
                                  style: const TextStyle(
                                    color: _kAccentRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // ─── BOTONES DE ACCIÓN SEGÚN EL FLUJO OBLIGATORIO ───
                _buildBotoneraAcciones(fila, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipDetalle(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoneraAcciones(_FilaGuiaGRE fila, _GREStatus status) {
    if (status == _GREStatus.pendiente) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ETAPA 1: Descargar PDF local inmediatamente para el chofer / cliente
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kBrandBlue,
              side: const BorderSide(color: _kBrandBlue, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _descargarPdfChofer(fila),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Descargar PDF Chofer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(height: 8),

          // ETAPA 2: Botón para transmitir a SUNAT al finalizar el día
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrandNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _enviarASunat(fila),
            icon: const Icon(Icons.send_rounded, size: 15),
            label: const Text('🚀 Enviar a SUNAT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      );
    }

    if (status == _GREStatus.error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kTextDark,
              side: const BorderSide(color: _kBorderColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _descargarPdfChofer(fila),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Ver PDF Borrador', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _enviarASunat(fila),
            icon: const Icon(Icons.replay_rounded, size: 16),
            label: const Text('🔄 Reintentar Envío', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      );
    }

    // ACEPTADO
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccentGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (fila.pdfUrl != null && fila.pdfUrl!.isNotEmpty) {
              _abrirUrlOficial(fila.pdfUrl, 'PDF SUNAT');
            } else {
              _descargarPdfChofer(fila);
            }
          },
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: const Text('📄 Ver PDF SUNAT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        if (fila.xmlUrl != null && fila.xmlUrl!.isNotEmpty) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _abrirUrlOficial(fila.xmlUrl, 'XML'),
            icon: const Icon(Icons.code_rounded, size: 14, color: _kBrandCyan),
            label: const Text('Descargar XML', style: TextStyle(color: _kBrandCyan, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
