// ═══════════════════════════════════════════════════════════════════════════
// lib/screens/comercial/liquidaciones_page.dart
// LIQUIDACIÓN DE MIXERS - Versión 2.0 (Completa y Funcional)
// ═══════════════════════════════════════════════════════════════════════════
// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'liquidacion_pdf_preview.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════════════
// MODELO: Configuración de costos (configurable desde la app)
// ══════════════════════════════════════════════════════════════════════════
class _Config {
  double precioM3;
  double descOperador;
  double descMantto;
  double cochera;
  double bonoCombustible;
  double detraccionPct;
  int minimoM3;
  String empresa;
  String ruc;
  String banco;
  String cuentaBanco;

  _Config({
    this.precioM3 = 50.0,
    this.descOperador = 120.0,
    this.descMantto = 0.0,
    this.cochera = 5.0,
    this.bonoCombustible = 0.0,
    this.detraccionPct = 10.0,
    this.minimoM3 = 6,
    this.empresa = '',
    this.ruc = '',
    this.banco = '',
    this.cuentaBanco = '',
  });

  _Config copyWith({
    double? precioM3,
    double? descOperador,
    double? descMantto,
    double? cochera,
    double? bonoCombustible,
    double? detraccionPct,
    int? minimoM3,
    String? empresa,
    String? ruc,
    String? banco,
    String? cuentaBanco,
  }) {
    return _Config(
      precioM3: precioM3 ?? this.precioM3,
      descOperador: descOperador ?? this.descOperador,
      descMantto: descMantto ?? this.descMantto,
      cochera: cochera ?? this.cochera,
      bonoCombustible: bonoCombustible ?? this.bonoCombustible,
      detraccionPct: detraccionPct ?? this.detraccionPct,
      minimoM3: minimoM3 ?? this.minimoM3,
      empresa: empresa ?? this.empresa,
      ruc: ruc ?? this.ruc,
      banco: banco ?? this.banco,
      cuentaBanco: cuentaBanco ?? this.cuentaBanco,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MODELO: Fila de liquidación calculada
// ══════════════════════════════════════════════════════════════════════════
class _Fila {
  final DateTime fechaObj;
  final String fechaLabel;
  final bool sinAtencion;
  final bool tieneOptimizacion;
  final double volumenOriginal;
  final double volumenOptimizado;
  final double volumenReal;
  final double subTotal;
  final double desOperador;
  final double desMantto;
  final double cochera;
  final double bonoComb;
  final double total;
  final String guia;
  final String clienteNombre;
  final String direccionLabel; // DISTRITO / CLIENTE para la columna final
  final int ordenCarguio;
  final bool esFilaPrincipalDelDia;

  const _Fila({
    required this.fechaObj,
    required this.fechaLabel,
    required this.sinAtencion,
    required this.tieneOptimizacion,
    required this.volumenOriginal,
    required this.volumenOptimizado,
    required this.volumenReal,
    required this.subTotal,
    required this.desOperador,
    required this.desMantto,
    required this.cochera,
    required this.bonoComb,
    required this.total,
    required this.guia,
    required this.clienteNombre,
    required this.direccionLabel,
    required this.ordenCarguio,
    required this.esFilaPrincipalDelDia,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// PÁGINA PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════
class LiquidacionesMixersTab extends StatefulWidget {
  const LiquidacionesMixersTab({super.key});

  @override
  State<LiquidacionesMixersTab> createState() => _LiquidacionesMixersTabState();
}

class _LiquidacionesMixersTabState extends State<LiquidacionesMixersTab> {
  final _supabase = Supabase.instance.client;

  // ── Filtros ──────────────────────────────────────
  DateTime _inicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fin = DateTime.now();
  String? _mixerSel;
  List<String> _mixers = [];

  // ── Configuración de costos ───────────────────────
  _Config _cfg = _Config();

  // ── Estado ───────────────────────────────────────
  bool _cargando = false;
  List<_Fila> _filas = [];

  // ── Totales globales ─────────────────────────────
  double _gSubTotal = 0;
  double _gDescuentos = 0;
  double _gNeto = 0;
  double _gM3 = 0;
  
  double _gDesOperador = 0;
  double _gDesMantto = 0;
  double _gCochera = 0;
  double _gBonoComb = 0;
  int _gDiasLiq = 0;

  // ── Controladores Empresa ────────────────────────
  final _empresaCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _cuentaCtrl = TextEditingController();

  // ── Constantes de UI ─────────────────────────────
  static const _colW = [150.0, 56.0, 82.0, 62.0, 118.0, 84.0, 82.0, 86.0, 86.0, 80.0, 80.0, 74.0, 92.0, 210.0];
  static const _headers = [
    'FECHA', 'TIPO', 'NÚMERO', 'MÍN\nM3', 'GUÍA',
    'CANTIDAD\n(M3)', 'PRECIO\nUNIT.', 'SUB\nTOTAL',
    'DES.\nOPERADOR', 'DES.\nMANTTO', 'COCHERA', 'COMB.\nNETO', 'TOTAL',
    'DIRECCIÓN / CLIENTE',
  ];
  static final _tableWidth = _colW.fold(0.0, (a, b) => a + b);

  // ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cargarMixers();
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _rucCtrl.dispose();
    _bancoCtrl.dispose();
    _cuentaCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s.toLowerCase() == 'nan') return 0;
    return double.tryParse(s) ?? 0;
  }

  // ── Carga lista de mixers disponibles ─────────────
Future<void> _cargarMixers() async {
    try {
      final List<dynamic> rows = await _supabase.rpc('get_unique_mixers');
      final set = <String>{};
      for (final r in rows) {
        String m = r['mixer']?.toString().trim() ?? '';
        m = m.replaceAll('  ', ' ');
        if (m.isEmpty || m.toLowerCase() == 'nan') continue;
        if (m.toUpperCase().startsWith('CMKX')) m = m.replaceFirst(RegExp(r'CMKX\s*'), 'CMX ');
        if (m.toUpperCase().contains('EXTERNO') || m.toUpperCase().contains('ROCA') || m.toUpperCase().contains('DONG')) {
           final op = r['operador']?.toString().trim() ?? '';
           if (op.isNotEmpty && op.toUpperCase() != m.toUpperCase()) m = '$m - $op';
        }
        set.add(m.toUpperCase());
      }
      setState(() {
        _mixers = set.toList()..sort();
        if (_mixers.isNotEmpty) _mixerSel = _mixers.first;
      });
    } catch (e) {
      debugPrint('Error cargando mixers: $e');
    }
  }

  // ── Proceso principal de liquidación ─────────────
  Future<void> _procesar() async {
    if (_mixerSel == null) return;
    setState(() { _cargando = true; _filas = []; });

    final fmtDate = DateFormat('yyyy-MM-dd');
    final sInicio = fmtDate.format(_inicio);
    final finMas1 = _fin.add(const Duration(days: 1));
    final sFin = fmtDate.format(finMas1);

    try {
// 1. Traer despachos del mixer en el rango (sin anulados)
      String searchMixer = _mixerSel!;
      String? searchOp;
      if (searchMixer.contains(' - ')) {
         final parts = searchMixer.split(' - ');
         searchMixer = parts[0];
         searchOp = parts[1];
      }
      
      var query = _supabase
          .from('despachos_produccion')
          .select('fecha, cliente, volumen, volumen_guias, optimizado, orden_carguio, bomba, estado, operador')
          .gte('fecha', sInicio)
          .lt('fecha', sFin)
          .ilike('mixer', '%$searchMixer%')
          .neq('estado', 'anulada');

      final despachos = await query;
      // Filter by operator locally if needed
      final despachosFiltrados = searchOp != null ? despachos.where((d) => (d['operador'] ?? '').toString().toUpperCase() == searchOp).toList() : despachos;

      // 2. Traer ventas del mismo rango (para obtener guía, dirección, distrito)
      final ventas = await _supabase
          .from('ventas_programacion')
          .select('fecha_entrega, nombre_razon_social, numero_atencion, direccion, distrito')
          .gte('fecha_entrega', sInicio)
          .lt('fecha_entrega', sFin);

      // 3. Traer datos de Cochera
      final cocheraData = await _supabase
          .from('registro_cochera')
          .select('fecha, vehiculos_maestro!inner(nombre_vehiculo)')
          .eq('vehiculos_maestro.nombre_vehiculo', searchMixer)
          .gte('fecha', sInicio)
          .lte('fecha', sFin);

      final Map<String, bool> cocheraMap = {};
      for (var c in cocheraData) {
        cocheraMap[c['fecha'].toString()] = true;
      }

      // 4. Traer datos de Combustible
      final combData = await _supabase
          .from('registro_combustible')
          .select('fecha, monto_total, vehiculos_maestro!inner(nombre_vehiculo)')
          .eq('vehiculos_maestro.nombre_vehiculo', searchMixer)
          .gte('fecha', sInicio)
          .lte('fecha', sFin);

      final Map<String, double> combMap = {};
      for (var c in combData) {
        final f = c['fecha'].toString();
        combMap[f] = (combMap[f] ?? 0.0) + (double.tryParse(c['monto_total']?.toString() ?? '0') ?? 0.0);
      }

      // Mapa de búsqueda ventas: "YYYY-MM-DD_CLIENTE_UPPER" → registro
      final Map<String, Map<String, dynamic>> ventaMap = {};
      for (final v in ventas) {
        final fv = v['fecha_entrega']?.toString().trim() ?? '';
        final cl = (v['nombre_razon_social']?.toString().trim() ?? '').toUpperCase();
        ventaMap['${fv}_$cl'] = Map<String, dynamic>.from(v);
      }

      final List<_Fila> resultado = [];
      double gSub = 0, gDesc = 0, gM3 = 0;
      double gDesOp = 0, gDesMant = 0, gCoch = 0, gBono = 0;
      int gDias = 0;

      DateTime dia = DateTime(_inicio.year, _inicio.month, _inicio.day);
      final diaFin = DateTime(_fin.year, _fin.month, _fin.day);

      while (!dia.isAfter(diaFin)) {
        final diaStr = fmtDate.format(dia);
        final fmtLabel = DateFormat('EEEE, d / MM / yy', 'es_ES').format(dia);

// Despachos del día, ordenados por orden_carguio
        final del_dia = despachosFiltrados
            .where((d) => (d['fecha'] ?? '').toString().startsWith(diaStr))
            .toList()
          ..sort((a, b) => (_num(a['orden_carguio'])).compareTo(_num(b['orden_carguio'])));

        final bool pernocto = cocheraMap[diaStr] == true;
        final double combUsado = combMap[diaStr] ?? 0.0;

        if (del_dia.isEmpty) {
          // ─ SIN ATENCIÓN: cobra cochera + mantto ─
          final coch = pernocto ? _cfg.cochera : 0.0;
          final mant = _cfg.descMantto;
          final desc = coch + mant;
          // Combustible sin atención (por si acaso echó combustible en día libre)
          final bonoComb = _cfg.bonoCombustible - combUsado;

          gDesc += desc;
          gCoch += coch;
          gDesMant += mant;
          gBono += bonoComb;
          gDias++;
          resultado.add(_Fila(
            fechaObj: dia,
            fechaLabel: fmtLabel,
            sinAtencion: true,
            tieneOptimizacion: false,
            volumenOriginal: 0,
            volumenOptimizado: 0,
            volumenReal: 0,
            subTotal: 0,
            desOperador: 0,
            desMantto: _cfg.descMantto,
            cochera: coch,
            bonoComb: bonoComb,
            total: -desc,
            guia: '',
            clienteNombre: 'SIN ATENCIÓN',
            direccionLabel: 'SIN ATENCIÓN',
            ordenCarguio: 0,
            esFilaPrincipalDelDia: true,
          ));
        } else {
          // ─ CON DESPACHOS ─
          bool esPrimero = true;
          for (final d in del_dia) {
            final clienteRaw = (d['cliente'] ?? '').toString().trim();
            final volGuias = _num(d['volumen_guias']);
            final volProd = _num(d['volumen']);
            final optVal = _num(d['optimizado']);
            final tieneOpt = optVal > 0;
            
            // PRINCIPAL VOLUME IS volGuias (billed). Small text is volProd.
            final volReal = volGuias > 0 ? volGuias : volProd;
            final volOriginal = volProd;

            final sub = volReal * _cfg.precioM3;

            // Descuentos: operador, cochera y combustible
            final desOp = esPrimero ? _cfg.descOperador : 0.0;
            final coch = (esPrimero && pernocto) ? _cfg.cochera : 0.0;
            final mant = esPrimero ? _cfg.descMantto : 0.0;
            // El bono se suma, el consumo se descuenta (por lo tanto combUsado se resta del bonoComb)
            final bonoComb = esPrimero ? (_cfg.bonoCombustible - combUsado) : 0.0;
            
            final total = sub - desOp - mant - coch + bonoComb;

            gSub += sub;
            gDesc += desOp + mant + coch;
            
            if (esPrimero) {
              gDias++;
              gDesOp += desOp;
              gDesMant += mant;
              gCoch += coch;
              gBono += bonoComb;
            }
            
            gM3 += volReal;

            // Buscar datos de cliente en ventas_programacion
            final key = '${diaStr}_${clienteRaw.toUpperCase()}';
            final venta = ventaMap[key];
            final guia = venta?['numero_atencion']?.toString().trim() ?? '';
            final distrito = venta?['distrito']?.toString().trim() ?? '';
            final direccion = venta?['direccion']?.toString().trim() ?? '';
            final dirLabel = [distrito, clienteRaw].where((s) => s.isNotEmpty).join(' / ');

            resultado.add(_Fila(
              fechaObj: dia,
              fechaLabel: fmtLabel,
              sinAtencion: false,
              tieneOptimizacion: tieneOpt,
              volumenOriginal: volOriginal,
              volumenOptimizado: optVal,
              volumenReal: volReal,
              subTotal: sub,
              desOperador: desOp,
              desMantto: mant,
              cochera: coch,
              bonoComb: bonoComb,
              total: total,
              guia: guia,
              clienteNombre: clienteRaw,
              direccionLabel: dirLabel.isNotEmpty ? dirLabel : clienteRaw,
              ordenCarguio: d['orden_carguio'] ?? 0,
              esFilaPrincipalDelDia: esPrimero,
            ));

            esPrimero = false;
          }
        }
        dia = dia.add(const Duration(days: 1));
      }

      final neto = gSub - gDesc + gBono;

      setState(() {
        _filas = resultado;
        _gSubTotal = gSub;
        _gDescuentos = gDesc;
        _gNeto = neto;
        _gM3 = gM3;
        _gDesOperador = gDesOp;
        _gDesMantto = gDesMant;
        _gCochera = gCoch;
        _gBonoComb = gBono;
        _gDiasLiq = gDias;
        _cargando = false;
      });
    } catch (e, st) {
      debugPrint('Error en liquidación: $e\n$st');
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Liquidación de Mixers',
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        actions: [
          // Botón configuración
          Tooltip(
            message: 'Configurar costos fijos',
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: AppColors.primaryDark, size: 20),
              ),
              onPressed: _abrirConfiguracion,
            ),
          ),
          // Botón PDF
          if (_filas.isNotEmpty)
            Tooltip(
              message: 'Exportar PDF',
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                ),
                onPressed: _abrirPdfPreview,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildPanelFiltros(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _filas.isEmpty
                    ? _buildEstadoVacio()
                    : _buildContenido(),
          ),
        ],
      ),
    );
  }

  // ── Panel de filtros ─────────────────────────────────────────
  Widget _buildPanelFiltros() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generar Liquidación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          // Controles en Wrap para evitar overflow
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Selector de mixer
              _DropdownMixer(
                value: _mixerSel,
                items: _mixers,
                onChanged: (v) => setState(() => _mixerSel = v),
              ),
              // Selector de rango de fechas
              _BtnFecha(
                label: '${DateFormat('dd/MM/yy').format(_inicio)}  →  ${DateFormat('dd/MM/yy').format(_fin)}',
                onTap: _seleccionarRango,
              ),
              // Botón procesar
              ElevatedButton.icon(
                onPressed: _procesar,
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('Procesar', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Chips con resumen de config actual
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chipInfo('P.U. S/.${_cfg.precioM3.toStringAsFixed(0)}/m³', Icons.monetization_on_outlined, Colors.green),
              _chipInfo('Op. S/.${_cfg.descOperador.toStringAsFixed(0)}', Icons.person_pin_outlined, Colors.blue),
              _chipInfo('Cochera S/.${_cfg.cochera.toStringAsFixed(0)}', Icons.garage_outlined, Colors.orange),
              if (_cfg.bonoCombustible > 0)
                _chipInfo('Bono Comb. S/.${_cfg.bonoCombustible.toStringAsFixed(0)}', Icons.local_gas_station, Colors.pink),
              if (_cfg.descMantto > 0)
                _chipInfo('Mantto S/.${_cfg.descMantto.toStringAsFixed(0)}', Icons.build_outlined, Colors.purple),
              _chipInfo('Detrac. ${_cfg.detraccionPct.toStringAsFixed(0)}%', Icons.percent, Colors.red),
              _chipInfo('Mín ${_cfg.minimoM3} m³', Icons.local_shipping_outlined, Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipInfo(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.9), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────
  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Seleccione un mixer y el rango de fechas',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Luego presione "Procesar" para generar la liquidación',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Contenido con tabla + footer ──────────────────────────────
  Widget _buildContenido() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 800 || constraints.maxHeight < 700;
        
        Widget barraInfo = Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCD34D).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Text(
                  'LIQUIDACIÓN  $_mixerSel  |  '
                  '${DateFormat('dd/MM/yy').format(_inicio)} – ${DateFormat('dd/MM/yy').format(_fin)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF92400E)),
                ),
              ),
              const Spacer(),
              Text('${_filas.length} registros  |  ${_gM3.toStringAsFixed(2)} m³ total',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        );

        if (isMobile) {
          return SingleChildScrollView(
            child: Column(
              children: [
                barraInfo,
                SizedBox(height: 400, child: _buildTabla()),
                _buildFooter(),
              ],
            ),
          );
        }

        return Column(
          children: [
            barraInfo,
            Expanded(child: _buildTabla()),
            _buildFooter(),
          ],
        );
      }
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TABLA PRINCIPAL (scroll horizontal + vertical)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabla() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: _tableWidth,
        child: Column(
          children: [
            // Header fijo
            _buildHeaderTabla(),
            // Filas con scroll vertical
            Expanded(
              child: ListView.builder(
                itemCount: _filas.length,
                itemBuilder: (_, i) => _buildFilaTabla(_filas[i], i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTabla() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: List.generate(_headers.length, (i) {
          return SizedBox(
            width: _colW[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              child: Text(
                _headers[i],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFilaTabla(_Fila f, int idx) {
    // Colores de fila según el formato Excel
    final Color bg;
    if (f.sinAtencion) {
      bg = const Color(0xFFF1F5F9); // gris claro = sin atención
    } else if (idx % 2 == 0) {
      bg = Colors.white;
    } else {
      bg = const Color(0xFFF8FAFC); // gris muy claro = alternadas
    }

    final Color totalColor = f.total < 0 ? Colors.red.shade700 : const Color(0xFF15803D);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 0 FECHA
          _td(f.fechaLabel, 0, italic: true, size: 9.5, bold: f.sinAtencion),
          // 1 TIPO
          _td('MIXER', 1, centered: true),
          // 2 NÚMERO
          _td(_mixerSel ?? '', 2, bold: true, centered: true),
          // 3 MÍNIMO M3
          _td(f.sinAtencion ? '0' : '${_cfg.minimoM3}', 3, centered: true),
          // 4 GUÍA
          _td(f.guia, 4, size: 9.5),
          // 5 CANTIDAD M3
          SizedBox(
            width: _colW[5],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f.volumenReal > 0 ? f.volumenReal.toStringAsFixed(2) : '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  if (f.tieneOptimizacion)
                    Text(
                      '(orig. ${f.volumenOriginal.toStringAsFixed(2)})',
                      style: TextStyle(fontSize: 8, color: Colors.orange.shade600, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ),
          // 6 PRECIO UNIT
          _tdMonto('S/.${_cfg.precioM3.toStringAsFixed(2)}', 6),
          // 7 SUB TOTAL
          _tdMonto(
            f.subTotal > 0 ? 'S/.${f.subTotal.toStringAsFixed(2)}' : 'S/.0,00',
            7,
            color: f.subTotal > 0 ? const Color(0xFF15803D) : Colors.black54,
            bold: f.subTotal > 0,
          ),
          // 8 DES OPERADOR
          _tdMonto(
            f.desOperador > 0 ? 'S/.${f.desOperador.toStringAsFixed(2)}' : '',
            8,
            color: Colors.red.shade600,
          ),
          // 9 DES MANTTO
          _tdMonto(
            f.desMantto > 0 ? 'S/.${f.desMantto.toStringAsFixed(2)}' : '',
            9,
            color: Colors.red.shade600,
          ),
          // 10 COCHERA
          f.cochera != 0
              ? _tdMonto('S/.${f.cochera.toStringAsFixed(2)}', 10, color: Colors.red.shade600)
              : _td('', 10),
          // 11 COMB NETO
          f.bonoComb != 0
              ? _tdMonto('S/.${f.bonoComb.toStringAsFixed(2)}', 11, color: f.bonoComb < 0 ? Colors.red.shade700 : Colors.blue.shade700, bold: true)
              : _td('', 11),
          // 12 TOTAL
          SizedBox(
            width: _colW[12],
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  'S/.${f.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: totalColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // 12 INDICADOR + DIRECCIÓN / CLIENTE
          Expanded(
            child: SizedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f.sinAtencion ? 'SIN ATENCIÓN' : f.direccionLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: f.sinAtencion
                          ? Colors.blue.shade700
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),),
        ],
      ),
    );
  }

  // Celda de texto genérica
  Widget _td(String text, int col, {bool bold = false, bool italic = false, double size = 10.5, bool centered = false}) {
    return SizedBox(
      width: _colW[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: const Color(0xFF334155),
          ),
          textAlign: centered ? TextAlign.center : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Celda de monto
  Widget _tdMonto(String text, int col, {Color? color, bool bold = false}) {
    return SizedBox(
      width: _colW[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            color: color ?? const Color(0xFF334155),
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FOOTER DE TOTALES
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFooter() {
    final detraccion = _gNeto * (_cfg.detraccionPct / 100);
    final deposito = _gNeto - detraccion;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          // Datos empresa + total m3
          Container(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DATOS DE FACTURACIÓN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: TextField(
                    controller: _empresaCtrl,
                    onChanged: (v) => _cfg.empresa = v,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(hintText: 'Ingresar Empresa...', hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 20,
                  child: TextField(
                    controller: _rucCtrl,
                    onChanged: (v) => _cfg.ruc = v,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    decoration: const InputDecoration(hintText: 'Ingresar RUC...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 20,
                  child: TextField(
                    controller: _bancoCtrl,
                    onChanged: (v) => _cfg.banco = v,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    decoration: const InputDecoration(hintText: 'Ingresar Banco...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 20,
                  child: TextField(
                    controller: _cuentaCtrl,
                    onChanged: (v) => _cfg.cuentaBanco = v,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    decoration: const InputDecoration(hintText: 'Ingresar N° Cuenta...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total M³: ${_gM3.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // Tabla de totales
          Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResumenRow('SUB TOTAL', _gSubTotal, isHeader: true),
                if (_gDesOperador > 0) _buildResumenRow('Descuento Operador ($_gDiasLiq x S/.${_cfg.descOperador.toStringAsFixed(0)})', -_gDesOperador, isDesglose: true),
                if (_gDesMantto > 0) _buildResumenRow('Descuento Mantto ($_gDiasLiq x S/.${_cfg.descMantto.toStringAsFixed(0)})', -_gDesMantto, isDesglose: true),
                if (_gCochera > 0) _buildResumenRow('Cochera ($_gDiasLiq x S/.${_cfg.cochera.toStringAsFixed(0)})', -_gCochera, isDesglose: true),
                if (_gDescuentos > 0) ...[
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildResumenRow('TOTAL DESCUENTOS', -_gDescuentos, isSubHeader: true, textColor: Colors.red.shade700),
                ],
                if (_gBonoComb > 0) _buildResumenRow('Bono Combustible ($_gDiasLiq x S/.${_cfg.bonoCombustible.toStringAsFixed(0)})', _gBonoComb, isDesglose: true, isBonus: true),
                
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildResumenRow('NETO A PAGAR', _gNeto, isSubHeader: true),
                _buildResumenRow('Detracción (${_cfg.detraccionPct.toStringAsFixed(0)}%)', -detraccion, isDesglose: true),
                
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL DEPÓSITO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('S/. ${deposito.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildResumenRow(String label, double monto, {
    bool isHeader = false,
    bool isSubHeader = false,
    bool isDesglose = false,
    bool isBonus = false,
    Color? textColor,
  }) {
    final bool isNegative = monto < 0;
    final double absMonto = monto.abs();
    final String sign = isNegative ? '- ' : (isBonus ? '+ ' : '');
    
    Color valColor = const Color(0xFF1E293B);
    if (textColor != null) valColor = textColor;
    else if (isNegative && isDesglose) valColor = Colors.red.shade600;
    else if (isBonus) valColor = Colors.green.shade600;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16, 
        vertical: isHeader || isSubHeader ? 12 : 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHeader ? 13 : (isSubHeader ? 12 : 11),
                fontWeight: isHeader || isSubHeader ? FontWeight.bold : FontWeight.w500,
                color: isHeader || isSubHeader ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign S/. ${absMonto.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isHeader ? 14 : (isSubHeader ? 13 : 12),
              fontWeight: isHeader || isSubHeader ? FontWeight.bold : FontWeight.w600,
              color: valColor,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _inicio, end: _fin),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _inicio = picked.start; _fin = picked.end; });
  }

  void _abrirConfiguracion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetConfig(
        config: _cfg,
        onSave: (c) => setState(() => _cfg = c),
      ),
    );
  }

  Future<void> _abrirPdfPreview() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiquidacionPdfPreview(generarPdf: _generarPdfBytes),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EXPORTAR PDF — con fuentes Unicode (sin error Helvetica)
  // ═══════════════════════════════════════════════════════════════
  Future<Uint8List> _generarPdfBytes() async {
    // Fuentes Noto Sans → soporte completo Unicode / caracteres españoles
    final fontReg = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/LOGO2023.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final pdf = pw.Document();
    final detraccion = _gNeto * (_cfg.detraccionPct / 100);
    final deposito = _gNeto - detraccion;

    final theme = pw.ThemeData.withFont(base: fontReg, bold: fontBold, italic: fontItalic);

    // Colores PDF
    final amarillo = PdfColor.fromHex('#FEF08A');
    final ambarHeader = PdfColor.fromHex('#F59E0B');
    final verde = PdfColor.fromHex('#A7F3D0');
    final grisClaro = PdfColor.fromHex('#F9FAFB');
    final amarilloTitulo = PdfColor.fromHex('#FCD34D');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(14),
        theme: theme,
        header: (ctx) => pw.Container(
          color: amarilloTitulo,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoImage != null)
                pw.Image(logoImage, height: 30)
              else
                pw.SizedBox(width: 80),
              pw.Expanded(
                child: pw.Text(
                  'LIQUIDACIÓN DE MIXER - $_mixerSel',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
              pw.SizedBox(width: 80),
            ],
          ),
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Período: ${DateFormat('dd/MM/yyyy').format(_inicio)} al ${DateFormat('dd/MM/yyyy').format(_fin)}',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.Text(
              'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
        build: (ctx) => [
          pw.SizedBox(height: 8),

          // Tabla de despachos
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(0.9),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(0.7),
              4: const pw.FlexColumnWidth(1.4),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.1),
              7: const pw.FlexColumnWidth(1.1),
              8: const pw.FlexColumnWidth(1.1),
              9: const pw.FlexColumnWidth(0.9),
              10: const pw.FlexColumnWidth(0.9),
              11: const pw.FlexColumnWidth(0.9),
              12: const pw.FlexColumnWidth(1.1),
              13: const pw.FlexColumnWidth(2.4),
            },
            headers: [
              'FECHA', 'TIPO', 'NUMERO', 'MIN\nM3', 'GUIA',
              'CANTIDAD\n(M3)', 'PRECIO\nUNIT.', 'SUB\nTOTAL',
              'DES.\nOPERADOR', 'DES.\nMANTTO', 'COCHERA', 'COMB.\nNETO', 'TOTAL',
              'DIRECCION / CLIENTE',
            ],
            data: _filas.map((f) {
              final cantLabel = f.volumenReal > 0
                  ? f.volumenReal.toStringAsFixed(2)
                  : '';
              return [
                f.fechaLabel,
                'MIXER',
                _mixerSel ?? '',
                f.sinAtencion ? '0' : '${_cfg.minimoM3}',
                f.guia,
                cantLabel,
                'S/.${_cfg.precioM3.toStringAsFixed(2)}',
                'S/.${f.subTotal.toStringAsFixed(2)}',
                f.desOperador > 0 ? 'S/.${f.desOperador.toStringAsFixed(2)}' : '',
                f.desMantto > 0 ? 'S/.${f.desMantto.toStringAsFixed(2)}' : '',
                f.cochera > 0 ? 'S/.${f.cochera.toStringAsFixed(2)}' : '',
                f.bonoComb > 0 ? 'S/.${f.bonoComb.toStringAsFixed(2)}' : '',
                'S/.${f.total.toStringAsFixed(2)}',
                f.sinAtencion ? 'SIN ATENCION' : f.direccionLabel,
              ];
            }).toList(),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: pw.BoxDecoration(color: grisClaro),
          ),

          pw.SizedBox(height: 14),

          // Footer con datos empresa + tabla totales
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_cfg.empresa, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 2),
                  pw.Text('RUC. ${_cfg.ruc}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('CUENTA ${_cfg.banco}. ${_cfg.cuentaBanco}', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: PdfColor.fromHex('#0EA5E9'),
                    child: pw.Text(
                      'Total M3 Facturado: ${_gM3.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(width: 20),
              pw.Container(
                width: 280,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfResumenRow('SUB TOTAL', _gSubTotal, fontReg, fontBold, isHeader: true),
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5, height: 0),
                    if (_gDesOperador > 0) _buildPdfResumenRow('Descuento Operador ($_gDiasLiq x S/.${_cfg.descOperador.toStringAsFixed(0)})', -_gDesOperador, fontReg, fontBold, isDesglose: true),
                    if (_gDesMantto > 0) _buildPdfResumenRow('Descuento Mantto ($_gDiasLiq x S/.${_cfg.descMantto.toStringAsFixed(0)})', -_gDesMantto, fontReg, fontBold, isDesglose: true),
                    if (_gCochera > 0) _buildPdfResumenRow('Cochera ($_gDiasLiq x S/.${_cfg.cochera.toStringAsFixed(0)})', -_gCochera, fontReg, fontBold, isDesglose: true),
                    if (_gDescuentos > 0) ...[
                      pw.Divider(color: PdfColor.fromHex('#F1F5F9'), thickness: 0.5, height: 0),
                      _buildPdfResumenRow('TOTAL DESCUENTOS', -_gDescuentos, fontReg, fontBold, isSubHeader: true, textColor: PdfColors.red800),
                    ],
                    if (_gBonoComb > 0) _buildPdfResumenRow('Bono Combustible ($_gDiasLiq x S/.${_cfg.bonoCombustible.toStringAsFixed(0)})', _gBonoComb, fontReg, fontBold, isDesglose: true, isBonus: true),
                    
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5, height: 0),
                    _buildPdfResumenRow('NETO A PAGAR', _gNeto, fontReg, fontBold, isSubHeader: true),
                    _buildPdfResumenRow('Detracción (${_cfg.detraccionPct.toStringAsFixed(0)}%)', -detraccion, fontReg, fontBold, isDesglose: true),
                    
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#10B981'),
                        borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(5.5)),
                      ),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL DEPÓSITO', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 10)),
                          pw.Text('S/. ${deposito.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildPdfResumenRow(String label, double monto, pw.Font fontReg, pw.Font fontBold, {
    bool isHeader = false,
    bool isSubHeader = false,
    bool isDesglose = false,
    bool isBonus = false,
    PdfColor? textColor,
  }) {
    final bool isNegative = monto < 0;
    final double absMonto = monto.abs();
    final String sign = isNegative ? '- ' : (isBonus ? '+ ' : '');
    
    PdfColor valColor = PdfColors.black;
    if (textColor != null) valColor = textColor;
    else if (isNegative && isDesglose) valColor = PdfColors.red800;
    else if (isBonus) valColor = PdfColors.green800;

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 10, 
        vertical: isHeader || isSubHeader ? 7 : 4,
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: isHeader || isSubHeader ? fontBold : fontReg,
                fontSize: isHeader ? 9.5 : (isSubHeader ? 8.5 : 8),
                color: isHeader || isSubHeader ? PdfColors.black : PdfColor.fromHex('#475569'),
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            '$sign S/. ${absMonto.toStringAsFixed(2)}',
            style: pw.TextStyle(
              font: isHeader || isSubHeader ? fontBold : (isBonus || isNegative ? fontBold : fontReg),
              fontSize: isHeader ? 10 : (isSubHeader ? 9 : 8.5),
              color: valColor,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════
class _DropdownMixer extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownMixer({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text('Mixer', style: TextStyle(fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: items
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ))
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WIDGET: Botón de selección de fechas
// ══════════════════════════════════════════════════════════════════════════
class _BtnFecha extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BtnFecha({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, size: 16, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PANEL: Configuración de costos (Bottom Sheet)
// ══════════════════════════════════════════════════════════════════════════
class _SheetConfig extends StatefulWidget {
  final _Config config;
  final void Function(_Config) onSave;

  const _SheetConfig({required this.config, required this.onSave});

  @override
  State<_SheetConfig> createState() => _SheetConfigState();
}

class _SheetConfigState extends State<_SheetConfig> {
  late final Map<String, TextEditingController> _ctrl;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _ctrl = {
      'precioM3': TextEditingController(text: c.precioM3.toString()),
      'descOp': TextEditingController(text: c.descOperador.toString()),
      'descMantto': TextEditingController(text: c.descMantto.toString()),
      'cochera': TextEditingController(text: c.cochera.toString()),
      'detraccion': TextEditingController(text: c.detraccionPct.toString()),
      'bonoComb': TextEditingController(text: c.bonoCombustible.toString()),
      'minimoM3': TextEditingController(text: c.minimoM3.toString()),
      'empresa': TextEditingController(text: c.empresa),
      'ruc': TextEditingController(text: c.ruc),
      'banco': TextEditingController(text: c.banco),
      'cuenta': TextEditingController(text: c.cuentaBanco),
    };
  }

  @override
  void dispose() {
    _ctrl.values.forEach((c) => c.dispose());
    super.dispose();
  }

  double _d(String key) => double.tryParse(_ctrl[key]!.text) ?? 0;
  int _i(String key) => int.tryParse(_ctrl[key]!.text) ?? 0;
  String _s(String key) => _ctrl[key]!.text.trim();

  void _guardar() {
    widget.onSave(widget.config.copyWith(
      precioM3: _d('precioM3'),
      descOperador: _d('descOp'),
      descMantto: _d('descMantto'),
      cochera: _d('cochera'),
      detraccionPct: _d('detraccion'),
      bonoCombustible: _d('bonoComb'),
      minimoM3: _i('minimoM3'),
      empresa: _s('empresa'),
      ruc: _s('ruc'),
      banco: _s('banco'),
      cuentaBanco: _s('cuenta'),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune, color: AppColors.primaryDark, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Configuración de Costos',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1E293B))),
                  ),
                  TextButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  // ── Costos fijos ──
                  _seccion('💰 Costos Fijos', 'Aplican en cada cálculo de liquidación'),
                  _campo('Precio por M³ (S/.)', 'precioM3',
                      hint: 'Precio base por metro cúbico despachado', suffix: 'S/.'),
                  _campo('Descuento Operador Mixer (S/.)', 'descOp',
                      hint: 'Se aplica 1 vez por día cuando hay viajes', suffix: 'S/.'),
                  _campo('Descuento Mantenimiento (S/.)', 'descMantto',
                      hint: 'Se aplica todos los días (incluso sin atención)', suffix: 'S/.'),
                  _campo('Cochera / Parqueo diario (S/.)', 'cochera',
                      hint: 'Se aplica todos los días', suffix: 'S/.'),
                  _campo('Bono de Combustible (S/.)', 'bonoComb',
                      hint: 'Bono opcional, se suma al total del día', suffix: 'S/.'),
                  _campo('Mínimo M³ por viaje', 'minimoM3',
                      hint: 'Solo referencial en la tabla', suffix: 'M³', isInt: true),

                  const SizedBox(height: 6),
                  _seccion('📊 Finanzas', 'Cálculos al pie de la liquidación'),
                  _campo('Porcentaje de Detracción (%)', 'detraccion',
                      hint: 'Ej: 10 para 10%', suffix: '%'),

                  const SizedBox(height: 6),
                  _seccion('🏢 Datos de Empresa', 'Aparecen en el PDF exportado'),
                  _campo('Razón Social', 'empresa', isText: true),
                  _campo('RUC', 'ruc', isText: true),
                  _campo('Banco', 'banco', isText: true),
                  _campo('Número de Cuenta', 'cuenta', isText: true),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Guardar Configuración', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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

  Widget _seccion(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _campo(
    String label,
    String key, {
    String? hint,
    String? suffix,
    bool isInt = false,
    bool isText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _ctrl[key],
        keyboardType: isText
            ? TextInputType.text
            : isInt
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          suffixText: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }
}
  pw.TableRow _pdfFilaDesglose(String label, double monto, pw.Font fontReg, {bool isBonus = false}) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(label, style: pw.TextStyle(font: fontReg, fontSize: 7, color: PdfColor.fromHex('#475569'))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(
            'S/. ${monto.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              font: fontReg,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: isBonus ? PdfColor.fromHex('#15803D') : PdfColor.fromHex('#DC2626'),
            ),
          ),
        ),
      ],
    );
  }
