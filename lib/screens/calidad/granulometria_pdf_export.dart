// Archivo: lib/screens/calidad/granulometria_pdf_export.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// ─── Paleta Actualizada (Verdes y Amarillos) ───────────────────────────────
class _P {
  // Verde Bosque Profundo para bordes principales y texto oscuro
  static const deepGreen = PdfColor.fromInt(0xFF0C4D33);
  // Verde Menta Medio para fondos de secciones
  static const mintGreen = PdfColor.fromInt(0xFF388E3C);
  // Amarillo Dorado Brillante para acentos y resaltados de alta prioridad
  static const goldenYellow = PdfColor.fromInt(0xFFFDD835);

  // Colores de fondo suaves
  static const deepGreenBg = PdfColor.fromInt(
    0xFF0C4D33,
  ); // Para resaltar texto claro
  static const lightCream = PdfColor.fromInt(
    0xFFFFFDE7,
  ); // Para fondos de secciones
  static const softMint = PdfColor.fromInt(
    0xFFE8F5E9,
  ); // Para fondos de insignias/footer

  // Otros
  static const rowOdd = PdfColor.fromInt(0xFFF8FAFC);
  static const divider = PdfColor.fromInt(0xFFDDE3ED);
  static const textMid = PdfColor.fromInt(0xFF4A5568);
  static const textLt = PdfColor.fromInt(0xFF94A3B8);

  // Colores específicos para estados (CUMPLE/NO CUMPLE)
  static const greenStatus = PdfColor.fromInt(0xFF10B981);
  static const greenStatusBg = PdfColor.fromInt(0xFFD1FAE5);
  static const yellowStatus = PdfColor.fromInt(
    0xFFFDD835,
  ); // Amarillo dorado para NO CUMPLE (con texto rojo)
  static const roseStatusBg = PdfColor.fromInt(0xFFFEE2E2);
}

class GranulometriaPdfExport {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _loadFonts() async {
    _regular ??= await PdfGoogleFonts.notoSansRegular();
    _bold ??= await PdfGoogleFonts.notoSansBold();
  }

  static Future<Uint8List> generar({
    required Map<String, String> datos,
    required List<String> nombres,
    required List<double> pesos,
    required List<double> pctRet,
    required List<double> pctAcum,
    required List<double> pctPasa,
    required List<String> valid,
    required List<double> limInf,
    required List<double> limSup,
    required double pesoTotal,
    required double mf,
    required double humedad,
    required double pctN200,
    required double error,
    required bool errorOk,
    required Uint8List logoImageBytes, // <--- NUEVO PARÁMETRO PARA EL LOGO
    Uint8List? chartImageBytes,
  }) async {
    await _loadFonts();

    final reg = _regular!;
    final bold = _bold!;
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final theme = pw.ThemeData.withFont(base: reg, bold: bold);

    final doc = pw.Document(theme: theme, title: 'Analisis Granulometrico');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: theme,
        build: (ctx) => [
          _header(
            datos,
            now,
            bold,
            reg,
            logoImageBytes,
          ), // Pasar los bytes aquí
          pw.SizedBox(height: 5),
          _projectSection(datos, bold, reg),
          pw.SizedBox(height: 4),
          _clientSection(datos, bold, reg),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FixedColumnWidth(130),
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 7),
                    child: _mainTable(
                      nombres: nombres,
                      pesos: pesos,
                      pctRet: pctRet,
                      pctAcum: pctAcum,
                      pctPasa: pctPasa,
                      valid: valid,
                      limInf: limInf,
                      limSup: limSup,
                      pesoTotal: pesoTotal,
                      bold: bold,
                      reg: reg,
                    ),
                  ),
                  _propsPanel(
                    mf: mf,
                    humedad: humedad,
                    pctN200: pctN200,
                    error: error,
                    errorOk: errorOk,
                    bold: bold,
                    reg: reg,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          if (chartImageBytes != null) ...[
            _chartSection(chartImageBytes, bold),
            pw.SizedBox(height: 8),
          ],
          _footer(bold, reg),
        ],
      ),
    );

    return doc.save();
  }

  // ─── ENCABEZADO ACTUALIZADO CON LOGO Y COLORES ──────────────────────────
  static pw.Widget _header(
    Map<String, String> d,
    String now,
    pw.Font bold,
    pw.Font reg,
    Uint8List logoBytes, // <--- NUEVO PARÁMETRO
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(72),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(90),
      },
      // Usar verde bosque profundo para el borde principal
      border: pw.TableBorder.all(color: _P.deepGreen, width: 1.2),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            // Logo Image (remplazando 'LR')
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.white, // Fondo blanco para el logo
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  height: 36,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
            // Titulo
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 8,
              ),
              // Fondo amarillo dorado para el título
              color: _P.goldenYellow,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'ANALISIS GRANULOMETRICO DE LOS AGREGADOS',
                    style: pw.TextStyle(
                      font: bold,
                      color: _P.deepGreen, // Texto en verde bosque
                      fontSize: 10,
                      letterSpacing: 0.4,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: _P.deepGreen, // Caja de texto en verde bosque
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      'ASTM C136 / NTP 400.012',
                      style: pw.TextStyle(
                        font: bold,
                        color: _P.goldenYellow, // Texto en amarillo dorado
                        fontSize: 7.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Codigo/Fecha
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kv('Codigo:', 'NOVA-MC-F04-001', bold, reg),
                  pw.SizedBox(height: 3),
                  _kv('Revision:', '01', bold, reg),
                  pw.SizedBox(height: 3),
                  _kv('Fecha:', now, bold, reg),
                  if ((d['registro'] ?? '').isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    _kv('Registro N.:', d['registro'] ?? '', bold, reg),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── PROYECTO ACTUALIZADO CON COLORES ──────────────────────────────────
  static pw.Widget _projectSection(
    Map<String, String> d,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _P.deepGreen, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _P.deepGreen, // Fondo verde bosque
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: pw.Text(
              'PROYECTO : ${d['proyecto'] ?? ''}',
              style: pw.TextStyle(
                font: bold,
                color: _P.goldenYellow, // Texto amarillo dorado
                fontSize: 8,
              ),
            ),
          ),
          pw.Container(
            color: _P.lightCream, // Fondo crema suave
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: pw.Row(
              children: [
                pw.Text(
                  'UBICACION DEL PROYECTO : ',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 7.5,
                    color: _P.deepGreen,
                  ),
                ),
                pw.Text(
                  d['ubicacion'] ?? '',
                  style: pw.TextStyle(
                    font: reg,
                    fontSize: 7.5,
                    color: _P.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CLIENTE / MUESTRA ACTUALIZADO CON COLORES ──────────────────────────
  static pw.Widget _clientSection(
    Map<String, String> d,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(80),
      },
      border: pw.TableBorder.all(color: _P.deepGreen, width: 1),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            // Bloque cliente
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              color: _P.lightCream,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _lv('CLIENTE :', d['cliente'] ?? '', bold, reg),
                  pw.SizedBox(height: 3),
                  _lv('ATENCION :', d['atencion'] ?? '', bold, reg),
                  pw.SizedBox(height: 3),
                  _lv('MATERIAL :', d['material'] ?? '', bold, reg),
                  pw.SizedBox(height: 3),
                  _lv('CANTERA :', d['cantera'] ?? '', bold, reg),
                ],
              ),
            ),
            // Bloque muestra
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.white,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _lv('MUESTRA N. :', d['muestraNro'] ?? '1', bold, reg),
                  pw.SizedBox(height: 3),
                  _lv('MUESTREADO POR :', d['muestreadoPor'] ?? '', bold, reg),
                  pw.SizedBox(height: 3),
                  _lv('ENSAYADO POR :', d['ensayadoPor'] ?? '', bold, reg),
                  pw.SizedBox(height: 3),
                  _lv(
                    'FECHA DE MUESTREO :',
                    d['fechaMuestreo'] ?? '',
                    bold,
                    reg,
                  ),
                  pw.SizedBox(height: 3),
                  _lv(
                    'FECHA DE ANALISIS :',
                    d['fechaAnalisis'] ?? '',
                    bold,
                    reg,
                  ),
                ],
              ),
            ),
            // V°B°
            pw.Container(
              color: _P.softMint, // Fondo menta suave
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'V°B°',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8,
                      color: _P.deepGreen,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'RESPONSABLE DE\nCONTROL DE CALIDAD',
                    style: pw.TextStyle(
                      font: reg,
                      fontSize: 6,
                      color: _P.textMid,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    height: 18,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _P.divider),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(3),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        d['responsable'] ?? '',
                        style: pw.TextStyle(
                          font: reg,
                          fontSize: 7,
                          color: _P.textMid,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── TABLA GRANULOMÉTRICA ACTUALIZADA CON COLORES ────────────────────────
  static pw.Widget _mainTable({
    required List<String> nombres,
    required List<double> pesos,
    required List<double> pctRet,
    required List<double> pctAcum,
    required List<double> pctPasa,
    required List<String> valid,
    required List<double> limInf,
    required List<double> limSup,
    required double pesoTotal,
    required pw.Font bold,
    required pw.Font reg,
  }) {
    pw.Widget c(
      String t, {
      bool b = false,
      PdfColor? col,
      PdfColor? bg,
      pw.TextAlign a = pw.TextAlign.center,
      double fs = 7,
    }) => pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(
        t,
        textAlign: a,
        style: pw.TextStyle(
          font: b ? bold : reg,
          fontSize: fs,
          color: col ?? _P.deepGreen,
        ),
      ),
    );

    final cols = {
      0: const pw.FlexColumnWidth(2.2),
      1: const pw.FlexColumnWidth(1.8),
      2: const pw.FlexColumnWidth(1.3),
      3: const pw.FlexColumnWidth(1.3),
      4: const pw.FlexColumnWidth(1.3),
      5: const pw.FlexColumnWidth(1.3),
      6: const pw.FlexColumnWidth(1.6),
    };

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: _P.deepGreen,
      ), // Fondo verde bosque
      children: [
        c('MALLA ASTM', b: true, col: _P.goldenYellow), // Texto amarillo dorado
        c('PESO RET.\n(g)', b: true, col: _P.goldenYellow),
        c('% RET.', b: true, col: _P.goldenYellow),
        c('% ACUM.', b: true, col: _P.goldenYellow),
        c('% PASA', b: true, col: _P.goldenYellow),
        c('ESPEC.', b: true, col: _P.goldenYellow),
        c('ESTADO', b: true, col: _P.goldenYellow),
      ],
    );

    final dataRows = List.generate(16, (i) {
      final esFondo = i == 15;
      final rowBg = i.isEven ? PdfColors.white : _P.lightCream;
      final hasSpec = limInf[i] != -1 && limSup[i] != -1;
      final spec = hasSpec ? '${limInf[i].toInt()}-${limSup[i].toInt()}' : '-';
      final cumple = (!esFondo && i < valid.length) ? valid[i] : '';
      final esOk = cumple == 'CUMPLE';

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: rowBg),
        children: [
          c(nombres[i], b: esFondo, a: pw.TextAlign.left),
          c(pesos[i] > 0 ? pesos[i].toStringAsFixed(2) : '-'),
          c(pctRet[i].toStringAsFixed(2)),
          c(!esFondo ? pctAcum[i].toStringAsFixed(2) : ''),
          // % PASA resaltado en AMARILLO DORADO SOBRE VERDE BOSQUE
          pw.Container(
            color: !esFondo ? _P.deepGreen : rowBg,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(
              !esFondo ? pctPasa[i].toStringAsFixed(2) : '',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold,
                fontSize: 7,
                color: _P.goldenYellow,
              ),
            ),
          ),
          c(!esFondo ? spec : ''),
          // Badge CUMPLE (Verde) / NO CUMPLE (Amarillo Dorado)
          pw.Container(
            color: rowBg,
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: cumple.isEmpty
                ? pw.SizedBox()
                : pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      // CUMPLE: Verde Status | NO CUMPLE: Amarillo Status
                      color: esOk ? _P.greenStatusBg : _P.yellowStatus,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(2),
                      ),
                      border: pw.Border.all(
                        color: esOk
                            ? _P.greenStatus
                            : PdfColors.white, // Borde blanco sobre amarillo
                        width: esOk
                            ? 0.5
                            : 1, // Borde más grueso sobre amarillo
                      ),
                    ),
                    child: pw.Text(
                      esOk ? 'CUMPLE' : 'NO CUMPLE',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 5.5,
                        // CUMPLE: Texto Verde | NO CUMPLE: Texto Blanco
                        color: esOk ? _P.greenStatus : PdfColors.white,
                      ),
                    ),
                  ),
          ),
        ],
      );
    });

    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: _P.deepGreenBg,
      ), // Fondo verde bosque profundo
      children: [
        c(
          'TOTAL',
          b: true,
          a: pw.TextAlign.left,
          col: _P.goldenYellow,
        ), // Texto amarillo dorado
        c('${pesoTotal.toStringAsFixed(2)} g', b: true, col: _P.goldenYellow),
        c(''),
        c(''),
        c(''),
        c(''),
        c(''),
      ],
    );

    return pw.Table(
      columnWidths: cols,
      border: pw.TableBorder.all(color: _P.divider, width: 0.5),
      children: [headerRow, ...dataRows, totalRow],
    );
  }

  // ─── PANEL PROPIEDADES FÍSICAS ACTUALIZADO CON COLORES ────────────────────
  static pw.Widget _propsPanel({
    required double mf,
    required double humedad,
    required double pctN200,
    required double error,
    required bool errorOk,
    required pw.Font bold,
    required pw.Font reg,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _P.deepGreen, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: _P.lightCream, // Fondo crema suave
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _P.deepGreen, // Fondo verde bosque
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              'PROPIEDADES FISICAS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold,
                color: _P.goldenYellow, // Texto amarillo dorado
                fontSize: 6.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _pr('MODULO DE FINURA', mf.toStringAsFixed(2), bold, reg),
          _pr('DIAM. MAX. NOM.', '', bold, reg),
          _pr('ABSORCION', '', bold, reg),
          _pr('PESO VOL. COMP.', '', bold, reg, unit: 'kg/m3'),
          _pr('PESO VOL. SUELTO', '', bold, reg, unit: 'kg/m3'),
          _pr('% HUMEDAD', '${humedad.toStringAsFixed(2)} %', bold, reg),
          _pr('% MALLA < #200', '${pctN200.toStringAsFixed(2)} %', bold, reg),
          // Badge ARENA (Amarillo Dorado)
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            decoration: pw.BoxDecoration(
              color: _P.goldenYellow, // Fondo amarillo dorado
              border: pw.Border.all(color: PdfColors.white, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'ARENA',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold,
                fontSize: 7,
                color: PdfColors.white,
              ), // Texto blanco
            ),
          ),
          _pr(
            'ERROR (+-0.3%)',
            '${error.toStringAsFixed(2)} %',
            bold,
            reg,
            valColor: errorOk
                ? _P.greenStatus
                : PdfColors.white, // Texto verde status o blanco
          ),
          // Badge ACEPTABLE (Verde Status) / REHACER (Rojo Status)
          pw.Container(
            margin: const pw.EdgeInsets.fromLTRB(5, 2, 5, 5),
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
              color: errorOk
                  ? _P.greenStatusBg
                  : _P.yellowStatus, // Fondo verde o amarillo status
              border: pw.Border.all(
                color: errorOk ? _P.greenStatus : PdfColors.white,
                width: 0.7,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              errorOk ? 'ACEPTABLE' : 'REHACER TAMIZADO',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold,
                fontSize: 7,
                color: errorOk
                    ? _P.greenStatus
                    : PdfColors.white, // Texto verde o blanco
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── GRÁFICO ACTUALIZADO CON COLORES ─────────────────────────────────────
  static pw.Widget _chartSection(Uint8List bytes, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: _P.deepGreen, // Fondo verde bosque
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: pw.Text(
            'GRAFICO DE GRANULOMETRIA DEL AGREGADO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              color: _P.goldenYellow, // Texto amarillo dorado
              fontSize: 9,
              letterSpacing: 0.4,
            ),
          ),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _P.divider),
            color: PdfColors
                .white, // <--- ¡EL COLOR AHORA ESTÁ ADENTRO DE LA DECORACIÓN!
          ),
          padding: const pw.EdgeInsets.all(5),
          child: pw.Image(
            pw.MemoryImage(bytes),
            height: 180,
            fit: pw.BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // ─── FOOTER FIRMAS ACTUALIZADO CON COLORES ────────────────────────────────
  static pw.Widget _footer(pw.Font bold, pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: ['TÉCNICO', 'JEFE', 'SUPERVISOR'].map((role) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 4),
            color: PdfColors.white,
            child: pw.Column(
              children: [
                // Cajón pequeño superior
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: pw.BoxDecoration(
                    // Borde verde bosque
                    border: pw.Border.all(color: _P.deepGreen, width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                    color: _P.mintGreen, // Fondo verde menta
                  ),
                  child: pw.Text(
                    role,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8,
                      color: _P.goldenYellow,
                    ), // Texto amarillo dorado
                  ),
                ),
                pw.SizedBox(height: 4),
                // Cajón grande inferior para la firma
                pw.Container(
                  width: double.infinity,
                  height: 40,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    // Borde verde bosque
                    border: pw.Border.all(color: _P.deepGreen, width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                    color: _P.softMint, // Fondo menta suave
                  ),
                  child: pw.Text(
                    'NOMBRE Y FIRMA:',
                    style: pw.TextStyle(
                      font: reg,
                      fontSize: 6.5,
                      color: _P.textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Helpers de texto ─────────────────────────────────────────────────────
  static pw.Widget _kv(String k, String v, pw.Font bold, pw.Font reg) => pw.Row(
    children: [
      pw.Text(
        k,
        style: pw.TextStyle(font: bold, fontSize: 6.5, color: _P.textMid),
      ),
      pw.SizedBox(width: 2),
      pw.Flexible(
        child: pw.Text(
          v,
          style: pw.TextStyle(font: reg, fontSize: 6.5, color: _P.textLt),
          overflow: pw.TextOverflow.clip,
        ),
      ),
    ],
  );

  static pw.Widget _lv(String l, String v, pw.Font bold, pw.Font reg) => pw.Row(
    children: [
      pw.Text(
        l,
        // Usar verde bosque profundo
        style: pw.TextStyle(font: bold, fontSize: 7.5, color: _P.deepGreen),
      ),
      pw.SizedBox(width: 4),
      pw.Flexible(
        child: pw.Text(
          v,
          style: pw.TextStyle(font: reg, fontSize: 7.5, color: _P.textMid),
          overflow: pw.TextOverflow.clip,
        ),
      ),
    ],
  );

  static pw.Widget _pr(
    String label,
    String value,
    pw.Font bold,
    pw.Font reg, {
    String? unit,
    PdfColor? valColor,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _P.divider, width: 0.5)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(font: reg, fontSize: 5.8, color: _P.textMid),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: bold,
            fontSize: 7,
            // Texto verde bosque profundo o el color especificado
            color: valColor ?? _P.deepGreen,
          ),
        ),
        if (unit != null) ...[
          pw.SizedBox(width: 2),
          pw.Text(
            unit,
            style: pw.TextStyle(font: reg, fontSize: 5.5, color: _P.textLt),
          ),
        ],
      ],
    ),
  );
}
