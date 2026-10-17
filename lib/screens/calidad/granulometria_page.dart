// Archivo: lib/screens/calidad/granulometria_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'granulometria_export_dialog.dart';
import 'granulometria_pdf_export.dart';

// ─── Paleta de colores del módulo (NovaConcret) ────────────────────────
class _C {
  static const bg = Color(0xFFF8FAFC);
  static const navyDark = Color(0xFF002244);
  static const navy = Color(0xFF003366);
  static const navyLight = Color(0xFF004899);
  static const teal = Color(0xFF0284C7); // Celeste vibrante corporativo
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFEF4444);
  static const green = Color(0xFF0284C7);
  static const cardBg = Colors.white;
  static const rowEven = Colors.white;
  static const rowOdd = Color(0xFFF8FAFC);
  static const headerBg = Color(0xFFF1F5F9);
  static const divider = Color(0xFFE2E8F0);
  static const textDark = Color(0xFF0F172A);
  static const textMid = Color(0xFF64748B);
  static const textLight = Color(0xFF94A3B8);
  static const inputBg = Color(0xFFF8FAFC);
  static const inputBorder = Color(0xFFCBD5E1);
}

// ─── Constantes de mallas ───────────────────────────────────────────────
const _kNombres = [
  '3"',
  '2½"',
  '2"',
  '1½"',
  '1"',
  '¾"',
  '½"',
  '⅜"',
  'Nº 4',
  'Nº 8',
  'Nº 16',
  'Nº 30',
  'Nº 50',
  'Nº 100',
  'Nº 200',
  '< Nº 200',
];
const _kLimInf = <double>[
  -1,
  -1,
  -1,
  -1,
  -1,
  -1,
  -1,
  100,
  95,
  80,
  50,
  25,
  5,
  0,
  -1,
  -1,
];
const _kLimSup = <double>[
  -1,
  -1,
  -1,
  -1,
  -1,
  -1,
  -1,
  100,
  100,
  100,
  85,
  60,
  30,
  10,
  -1,
  -1,
];
const _kFmIndices = [3, 5, 7, 8, 9, 10, 11, 12, 13];

class GranulometriaPage extends StatefulWidget {
  const GranulometriaPage({super.key});
  @override
  State<GranulometriaPage> createState() => _GranulometriaPageState();
}

class _GranulometriaPageState extends State<GranulometriaPage>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────
  final _ctrlPesos = List.generate(16, (_) => TextEditingController());
  final _ctrlPesoMuestraH = TextEditingController();
  final _ctrlPesoSecoH = TextEditingController();
  final _ctrlPesoSecoL = TextEditingController();

  // ── Resultados ───────────────────────────────────────────────────────
  List<double> _pctRet = List.filled(16, 0.0);
  List<double> _pctAcum = List.filled(15, 0.0);
  List<double> _pctPasa = List.filled(15, 100.0);
  List<String> _valid = List.filled(15, '');

  double _pesoTotal = 0.0;
  double _mf = 0.0;
  double _humedad = 0.0;
  double _pctN200 = 0.0;
  double _error = 0.0;
  bool _errorOk = true;
  bool _calculado = false;
  int _vistaModo = 0; // 0: Dividida, 1: Gráfico Maximizado, 2: Solo Tabla

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Key para captura del gráfico ─────────────────────────────────────
  final _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    for (final c in _ctrlPesos) {
      c.dispose();
    }
    _ctrlPesoMuestraH.dispose();
    _ctrlPesoSecoH.dispose();
    _ctrlPesoSecoL.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Lógica de cálculo ─────────────────────────────────────────────────
  void _calcular() {
    final w = _ctrlPesos
        .map((c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0)
        .toList();
    final total = w.fold(0.0, (a, b) => a + b);

    final pmH =
        double.tryParse(_ctrlPesoMuestraH.text.replaceAll(',', '.')) ?? 0.0;
    final psecH =
        double.tryParse(_ctrlPesoSecoH.text.replaceAll(',', '.')) ?? 0.0;
    final psecL =
        double.tryParse(_ctrlPesoSecoL.text.replaceAll(',', '.')) ?? 0.0;
    final pmL = psecH;

    double humedad = 0.0;
    if (psecH > 0) humedad = ((pmH - psecH) / psecH) * 100.0;
    double pctN200 = 0.0;
    if (pmL > 0) pctN200 = ((pmL - psecL) / pmL) * 100.0;
    double err = 0.0;
    bool errOk = true;
    if (psecL > 0) {
      err = ((total - psecL) / psecL) * 10.0;
      errOk = err.abs() <= 0.3;
    }

    if (total <= 0) {
      setState(() {
        _calculado = false;
        _pesoTotal = 0;
        _pctRet = List.filled(16, 0.0);
        _pctAcum = List.filled(15, 0.0);
        _pctPasa = List.filled(15, 100.0);
        _valid = List.filled(15, '');
        _mf = 0.0;
        _humedad = humedad;
        _pctN200 = pctN200;
        _error = err;
        _errorOk = errOk;
      });
      return;
    }

    final ret = List.filled(16, 0.0);
    final acum = List.filled(15, 0.0);
    final pasa = List.filled(15, 100.0);
    double cumul = 0.0;

    for (int i = 0; i < 16; i++) {
      ret[i] = total > 0 ? (w[i] * 100.0 / total) : 0.0;
      if (i < 15) {
        cumul += ret[i];
        acum[i] = cumul;
        pasa[i] = (100.0 - cumul).clamp(0.0, 100.0);
      }
    }

    double mf = 0.0;
    for (final i in _kFmIndices) {
      mf += acum[i];
    }
    mf /= 100.0;

    final val = List.filled(15, '');
    for (int i = 0; i < 15; i++) {
      final hasSpec = _kLimInf[i] != -1 && _kLimSup[i] != -1;
      if (!hasSpec) continue;
      val[i] = (pasa[i] >= _kLimInf[i] - 0.05 && pasa[i] <= _kLimSup[i] + 0.05)
          ? 'CUMPLE'
          : 'NO CUMPLE';
    }

    setState(() {
      _pctRet = ret;
      _pctAcum = acum;
      _pctPasa = pasa;
      _valid = val;
      _pesoTotal = total;
      _mf = mf;
      _humedad = humedad;
      _pctN200 = pctN200;
      _error = err;
      _errorOk = errOk;
      _calculado = true;
    });

    _fadeCtrl.forward(from: 0.0);
  }

  void _limpiar() {
    for (final c in _ctrlPesos) {
      c.clear();
    }
    _ctrlPesoMuestraH.clear();
    _ctrlPesoSecoH.clear();
    _ctrlPesoSecoL.clear();
    setState(() {
      _calculado = false;
      _pesoTotal = 0;
      _pctRet = List.filled(16, 0.0);
      _pctAcum = List.filled(15, 0.0);
      _pctPasa = List.filled(15, 100.0);
      _valid = List.filled(15, '');
      _mf = 0.0;
      _humedad = 0.0;
      _pctN200 = 0.0;
      _error = 0.0;
      _errorOk = true;
    });
    _fadeCtrl.reset();
  }

  Future<void> _exportar() async {
    if (!_calculado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ingrese los pesos de las mallas primero.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // 1. Pedir datos de encabezado al usuario
    final datos = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GranulometriaExportDialog(),
    );
    if (datos == null) return;

    // 2. Capturar imagen del gráfico
    Uint8List? chartBytes;
    try {
      final boundary =
          _chartKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final img = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        chartBytes = byteData?.buffer.asUint8List();
      }
    } catch (_) {}

    // 3. Cargar el Logo de los assets (NUEVO PASO)
    Uint8List logoBytes;
    try {
      // Usamos rootBundle que ya tienes importado arriba
      final ByteData logoData = await rootBundle.load(
        'assets/images/LOGO_NOVA.png',
      );
      logoBytes = logoData.buffer.asUint8List();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error al cargar el logo. Revisa pubspec.yaml y la ruta.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. Generar PDF
    if (!mounted) return;
    final ctx = context;
    if (!context.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Generando PDF...'),
        backgroundColor: _C.navy,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final pdfBytes = await GranulometriaPdfExport.generar(
      datos: datos,
      nombres: _kNombres,
      pesos: _ctrlPesos
          .map((c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0)
          .toList(),
      pctRet: _pctRet,
      pctAcum: _pctAcum,
      pctPasa: _pctPasa,
      valid: _valid,
      limInf: _kLimInf,
      limSup: _kLimSup,
      pesoTotal: _pesoTotal,
      mf: _mf,
      humedad: _humedad,
      pctN200: _pctN200,
      error: _error,
      errorOk: _errorOk,
      logoImageBytes: logoBytes, // <--- AQUÍ SE PASA EL LOGO AL PDF
      chartImageBytes: chartBytes,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Granulometria_${datos['muestraNro'] ?? '1'}.pdf',
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = w < 850;

        Widget content;
        if (isMobile) {
          if (_vistaModo == 1) {
            // Solo Gráfico Maximizado para celular
            content = _buildRightPanelMobile(w, maximizado: true);
          } else if (_vistaModo == 2) {
            // Solo Tabla
            content = _buildLeftPanel(isMobile: true);
          } else {
            // Vista ambas
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftPanel(isMobile: true),
                const SizedBox(height: 16),
                _buildRightPanelMobile(w),
              ],
            );
          }
        } else {
          if (_vistaModo == 1) {
            // Gráfico maximizado al 100% de ancho en escritorio
            content = _buildRightPanelDesktop(maximizado: true);
          } else if (_vistaModo == 2) {
            // Solo tabla centrada
            content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: _buildLeftPanel(isMobile: false),
              ),
            );
          } else {
            // Vista dividida estándar
            content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 720,
                  child: _buildLeftPanel(isMobile: false),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildRightPanelDesktop(maximizado: false)),
              ],
            );
          }
        }

        return Scaffold(
          backgroundColor: _C.bg,
          appBar: _buildAppBar(context, w),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: content,
          ),
        );
      },
    );
  }

  // ─── AppBar con pestañas de ajuste de vista ───────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, double screenW) {
    final isNarrow = screenW < 520;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: _C.navyDark,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: _C.teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.grain_rounded, color: _C.teal, size: 20),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isNarrow ? 'Granulometría' : 'Análisis Granulométrico',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: 0.3,
            ),
          ),
          const Text(
            'ASTM C136 / NTP 400.012',
            style: TextStyle(
              color: _C.teal,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
      actions: [
        if (isNarrow)
          IconButton(
            onPressed: _limpiar,
            tooltip: 'Limpiar',
            icon: const Icon(Icons.refresh_rounded, size: 18, color: _C.textLight),
          )
        else
          TextButton.icon(
            onPressed: _limpiar,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 16,
              color: _C.textLight,
            ),
            label: const Text(
              'Limpiar',
              style: TextStyle(color: _C.textLight, fontSize: 12),
            ),
          ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: FilledButton.icon(
            onPressed: _exportar,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(isNarrow ? 'PDF' : 'Exportar', style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: _C.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(42),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _C.navyDark,
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildViewPill(0, 'Vista Dividida', Icons.view_sidebar_rounded),
                const SizedBox(width: 8),
                _buildViewPill(1, 'Gráfico Maximizado', Icons.fullscreen_rounded),
                const SizedBox(width: 8),
                _buildViewPill(2, 'Solo Tabla', Icons.table_chart_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewPill(int index, String label, IconData icon) {
    final isSel = _vistaModo == index;
    return InkWell(
      onTap: () => setState(() => _vistaModo = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? _C.teal : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? _C.teal : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSel ? Colors.white : _C.textLight),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                color: isSel ? Colors.white : _C.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Panel Izquierdo (Tabla) ──────────────────────────────────────────
  Widget _buildLeftPanel({bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTableTitle(),
            if (isMobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: _C.teal.withOpacity(0.08),
                child: const Row(
                  children: [
                    Icon(Icons.swipe_outlined, size: 15, color: _C.navyLight),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Desliza horizontalmente la tabla para ver pesos, límites y cálculo',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: _C.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 740,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTableHeader(),
                    _buildTableRows(isMobile: isMobile),
                    _buildTableTotal(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navyDark, _C.navy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_rows_rounded, color: _C.teal, size: 16),
          const SizedBox(width: 8),
          const Text(
            'GRANULOMETRIA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (_calculado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _C.teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.teal.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _C.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'CALCULADO',
                    style: TextStyle(
                      color: _C.teal,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 9.5,
      letterSpacing: 0.5,
      color: _C.textMid,
    );
    return Container(
      height: 36,
      color: _C.headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _headerCell('MALLA', 4, TextAlign.left),
          _headerCell('PESO RET. (g)', 4, TextAlign.center),
          _headerCell('% RET.', 3, TextAlign.center),
          _headerCell('% ACUM.', 3, TextAlign.center),
          _headerCell('% PASA', 3, TextAlign.center),
          _headerCell('ESPEC.', 3, TextAlign.center),
          _headerCell('ESTADO', 3, TextAlign.center),
        ],
      ),
    );
  }

  Widget _headerCell(String text, int flex, TextAlign align) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 0.5,
          color: _C.textMid,
        ),
      ),
    );
  }

  Widget _buildTableRows({bool isMobile = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(16, (i) {
        final esFondo = i == 15;
        final pctRet = _pctRet[i].toStringAsFixed(2);
        final pctAcum = (!esFondo) ? _pctAcum[i].toStringAsFixed(2) : '';
        final pctPasa = (!esFondo) ? _pctPasa[i].toStringAsFixed(2) : '';
        final hasSpec = _kLimInf[i] != -1 && _kLimSup[i] != -1;
        final especif = hasSpec
            ? '${_kLimInf[i].toInt()}–${_kLimSup[i].toInt()}'
            : '—';
        final tieneVal = _calculado && !esFondo && _valid[i].isNotEmpty;

        // Highlight rows with specs
        final isSpecRow = hasSpec;

        return Container(
          height: isMobile ? 38 : 33,
          decoration: BoxDecoration(
            color: i.isEven ? _C.rowEven : _C.rowOdd,
            border: Border(
              bottom: BorderSide(
                color: i == 15 ? Colors.transparent : _C.divider,
                width: 0.8,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Malla name
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    if (isSpecRow)
                      Container(
                        width: 3,
                        height: 14,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _C.navyLight.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Text(
                      _kNombres[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: esFondo ? FontWeight.w800 : FontWeight.w600,
                        color: esFondo ? _C.navyDark : _C.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 4, child: _buildNumInput(_ctrlPesos[i], isMobile: isMobile)),
              _dataCell(pctRet, 3),
              _dataCell(pctAcum, 3),
              // % Pasa – resaltado si calculado
              Expanded(
                flex: 3,
                child: _calculado && !esFondo
                    ? Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.navy.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pctPasa,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _C.navy,
                          ),
                        ),
                      )
                    : Text(
                        pctPasa,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.textLight,
                        ),
                      ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  !esFondo ? especif : '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: _C.textLight,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: tieneVal ? _buildBadge(_valid[i]) : const SizedBox(),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _dataCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: _calculado && text.isNotEmpty ? _C.textDark : _C.textLight,
        ),
      ),
    );
  }

  Widget _buildTableTotal() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navyDark.withOpacity(0.05), _C.navy.withOpacity(0.08)],
        ),
        border: const Border(top: BorderSide(color: _C.divider, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Expanded(
            flex: 4,
            child: Text(
              'TOTAL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: _C.navyDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _pesoTotal > 0 ? '${_pesoTotal.toStringAsFixed(2)} g' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: _pesoTotal > 0 ? _C.navy : _C.textLight,
              ),
            ),
          ),
          const Expanded(flex: 15, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildNumInput(TextEditingController ctrl, {bool isMobile = false}) {
    return Container(
      height: isMobile ? 28 : 24,
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 3 : 5),
      decoration: BoxDecoration(
        color: _C.inputBg,
        border: Border.all(color: _C.inputBorder, width: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: isMobile ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: _C.navyDark,
        ),
        onChanged: (_) => _calcular(),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ─── Panel Derecho ESCRITORIO (adaptativo según ancho disponible) ────────
  Widget _buildRightPanelDesktop({bool maximizado = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelW = constraints.maxWidth;
        final compact = panelW < 560;
        return Container(
          decoration: BoxDecoration(
            color: _C.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.divider),
            boxShadow: [
              BoxShadow(
                color: _C.navy.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChartHeader(isMobile: compact),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    12,
                    compact ? 12 : 16,
                    0,
                  ),
                  child: _buildFisicasPanel(isMobile: compact),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: maximizado ? 600 : 480,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildChartContainer(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Panel Derecho MÓVIL (SizedBox fijo para el chart) ───────────────
  Widget _buildRightPanelMobile(double screenW, {bool maximizado = false}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartHeader(isMobile: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _buildFisicasPanel(isMobile: true),
            ),
            const SizedBox(height: 12),
            // Alto adecuado para pantalla móvil
            SizedBox(
              height: maximizado ? 420 : 330,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: _buildChartContainer(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartHeader({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 10 : 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navyDark, _C.navy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, color: _C.amber, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'GRÁFICO DE GRANULOMETRÍA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _botonMaximizarMinimizar(),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Escala semi-logarítmica · ASTM C136',
                        style: TextStyle(
                          color: _C.textLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _legendItem(_C.navyLight, 'Muestra'),
                    const SizedBox(width: 10),
                    _legendItem(_C.green, 'Límite'),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.show_chart_rounded, color: _C.amber, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GRÁFICO DE GRANULOMETRÍA DEL AGREGADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Escala semi-logarítmica · ASTM C136',
                        style: TextStyle(
                          color: _C.textLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _legendItem(_C.navyLight, 'Muestra'),
                const SizedBox(width: 12),
                _legendItem(_C.green, 'Límite'),
                const SizedBox(width: 12),
                _botonMaximizarMinimizar(),
              ],
            ),
    );
  }

  Widget _botonMaximizarMinimizar() {
    final maximizado = _vistaModo == 1;
    return InkWell(
      onTap: () => setState(() => _vistaModo = maximizado ? 0 : 1),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              maximizado ? Icons.fullscreen_exit_rounded : Icons.open_in_full_rounded,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              maximizado ? 'Restaurar' : 'Maximizar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChartContainer() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.divider),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: RepaintBoundary(key: _chartKey, child: _buildChart()),
    );
  }

  // ─── Cuadros de Propiedades Físicas ──────────────────────────────────
  Widget _buildFisicasPanel({bool isMobile = false}) {
    if (isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'HUMEDAD',
                  icon: Icons.water_drop_outlined,
                  color: _C.teal,
                  children: [
                    _buildInputRow('Muestra', _ctrlPesoMuestraH),
                    _buildInputRow('Seco', _ctrlPesoSecoH),
                    _buildResultRow(
                      '% Hum.',
                      '${_humedad.toStringAsFixed(2)}%',
                      color: _humedad > 0 ? _C.teal : _C.textLight,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'FINOS < #200',
                  icon: Icons.filter_alt_outlined,
                  color: _C.navyLight,
                  children: [
                    _buildReadOnlyRow(
                      'P. Ini.',
                      _ctrlPesoSecoH.text.isEmpty ? '—' : _ctrlPesoSecoH.text,
                    ),
                    _buildInputRow('Lavado', _ctrlPesoSecoL),
                    _buildResultRow(
                      '% < #200',
                      '${_pctN200.toStringAsFixed(2)}%',
                      color: _pctN200 > 0 ? _C.navyLight : _C.textLight,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatCard(
            title: 'RESUMEN DEL ENSAYO',
            icon: Icons.summarize_outlined,
            color: _C.amber,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildResultRow(
                      'M.F.',
                      _mf.toStringAsFixed(2),
                      color: _calculado ? _C.navyDark : _C.textLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResultRow(
                      'Error %',
                      '${_error.toStringAsFixed(2)}%',
                      color: _calculado
                          ? (_errorOk ? _C.green : _C.rose)
                          : _C.textLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResultRow(
                      'Total (g)',
                      _pesoTotal.toStringAsFixed(0),
                      color: _calculado ? _C.navy : _C.textLight,
                    ),
                  ),
                ],
              ),
              if (_calculado) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _errorOk
                        ? _C.green.withOpacity(0.1)
                        : _C.rose.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _errorOk
                          ? _C.green.withOpacity(0.4)
                          : _C.rose.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _errorOk
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        size: 13,
                        color: _errorOk ? _C.green : _C.rose,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _errorOk ? 'ACEPTABLE (ASTM C136)' : 'REHACER TAMIZADO',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: _errorOk ? _C.green : _C.rose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'HUMEDAD',
            icon: Icons.water_drop_outlined,
            color: _C.teal,
            children: [
              _buildInputRow('Muestra', _ctrlPesoMuestraH),
              _buildInputRow('Seco', _ctrlPesoSecoH),
              _buildResultRow(
                '% Hum.',
                '${_humedad.toStringAsFixed(2)}%',
                color: _humedad > 0 ? _C.teal : _C.textLight,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            title: 'FINOS < #200',
            icon: Icons.filter_alt_outlined,
            color: _C.navyLight,
            children: [
              _buildReadOnlyRow(
                'P. Ini.',
                _ctrlPesoSecoH.text.isEmpty ? '—' : _ctrlPesoSecoH.text,
              ),
              _buildInputRow('Lavado', _ctrlPesoSecoL),
              _buildResultRow(
                '% < #200',
                '${_pctN200.toStringAsFixed(2)}%',
                color: _pctN200 > 0 ? _C.navyLight : _C.textLight,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            title: 'RESUMEN',
            icon: Icons.summarize_outlined,
            color: _C.amber,
            children: [
              _buildResultRow(
                'M.F.',
                _mf.toStringAsFixed(2),
                color: _calculado ? _C.navyDark : _C.textLight,
              ),
              _buildResultRow(
                'Error %',
                '${_error.toStringAsFixed(2)}%',
                color: _calculado
                    ? (_errorOk ? _C.green : _C.rose)
                    : _C.textLight,
              ),
              if (_calculado)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: _errorOk
                          ? _C.green.withOpacity(0.1)
                          : _C.rose.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _errorOk
                            ? _C.green.withOpacity(0.4)
                            : _C.rose.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _errorOk
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          size: 11,
                          color: _errorOk ? _C.green : _C.rose,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _errorOk ? 'ACEPTABLE' : 'REHACER TAMIZADO',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: _errorOk ? _C.green : _C.rose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _buildResultRow(
                'Total (g)',
                _pesoTotal.toStringAsFixed(0),
                color: _calculado ? _C.navy : _C.textLight,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 9.5,
                color: _C.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: _C.inputBg,
                border: Border.all(color: _C.inputBorder, width: 0.9),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _C.navyDark,
                ),
                onChanged: (_) => _calcular(),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0.00',
                  hintStyle: TextStyle(color: _C.textLight, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 9.5,
                color: _C.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: _C.headerBg,
                border: Border.all(color: _C.divider),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _C.textMid,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 9.5,
                color: _C.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: (color ?? _C.textLight).withOpacity(0.07),
                border: Border.all(
                  color: (color ?? _C.divider).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: color ?? _C.textLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Gráfico ──────────────────────────────────────────────────────────
  Widget _buildChart() {
    final agSpots = <FlSpot>[];
    final liSpots = <FlSpot>[];
    final lsSpots = <FlSpot>[];

    // X=0 → malla 0 (3", gruesa) → % pasa alto (izquierda)
    // X=14 → malla 14 (Nº200, fina) → % pasa bajo (derecha)
    // Resultado: curva DESCENDENTE de izquierda a derecha (orientación estándar ASTM)
    for (int i = 0; i < 15; i++) {
      final xVal = i.toDouble();
      final dataIdx = i; // directo: gruesos a la izquierda, finos a la derecha
      if (_calculado) agSpots.add(FlSpot(xVal, _pctPasa[dataIdx]));
      if (_kLimInf[dataIdx] != -1) liSpots.add(FlSpot(xVal, _kLimInf[dataIdx]));
      if (_kLimSup[dataIdx] != -1) lsSpots.add(FlSpot(xVal, _kLimSup[dataIdx]));
    }

    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: 0,
        maxX: 14,
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: _C.divider, strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              const FlLine(color: Color(0xFFEEF2F8), strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: _C.divider),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 1,
              getTitlesWidget: (v, meta) {
                // Mapeo directo: X=0→3" (grueso), X=14→Nº200 (fino)
                final nameIdx = v.toInt();
                const principals = {0, 2, 4, 5, 7, 8, 9, 11, 13, 14};
                if (nameIdx < 0 ||
                    nameIdx >= 15 ||
                    !principals.contains(nameIdx)) {
                  return SideTitleWidget(meta: meta, child: const Text(''));
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Transform.rotate(
                    angle: -0.65,
                    child: Text(
                      _kNombres[nameIdx],
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: _C.textMid,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: const TextStyle(
                  fontSize: 9,
                  color: _C.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          // Zona entre límites (shaded area)
          if (liSpots.isNotEmpty && lsSpots.isNotEmpty)
            LineChartBarData(
              spots: lsSpots,
              color: Colors.transparent,
              barWidth: 0,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: _C.green.withOpacity(0.05),
                cutOffY: 0,
                applyCutOffY: false,
              ),
            ),
          if (liSpots.isNotEmpty)
            LineChartBarData(
              spots: liSpots,
              color: _C.green.withOpacity(0.7),
              barWidth: 1.5,
              dashArray: [5, 4],
              dotData: const FlDotData(show: false),
            ),
          if (lsSpots.isNotEmpty)
            LineChartBarData(
              spots: lsSpots,
              color: _C.green.withOpacity(0.7),
              barWidth: 1.5,
              dashArray: [5, 4],
              dotData: const FlDotData(show: false),
            ),
          // Curva de la muestra
          if (_calculado && agSpots.isNotEmpty)
            LineChartBarData(
              spots: agSpots,
              color: _C.navyLight,
              barWidth: 2.5,
              isCurved: true,
              curveSmoothness: 0.3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 4,
                  color: _C.navyLight,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _C.navyLight.withOpacity(0.12),
                    _C.navyLight.withOpacity(0.0),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Badge CUMPLE / NO CUMPLE ────────────────────────────────────────
  Widget _buildBadge(String texto) {
    final esOk = texto == 'CUMPLE';
    final color = esOk ? _C.green : _C.rose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        esOk ? '✓ OK' : '✗ NO',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
