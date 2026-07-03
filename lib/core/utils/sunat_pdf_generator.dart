// lib/core/utils/sunat_pdf_generator.dart
// Guía de Remisión Electrónica & Factura — La Roca Concretos
// Diseño IDÉNTICO al formato físico de referencia (pdf_generator.dart)

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────
// CONSTANTES
// ─────────────────────────────────────────────────────────────
const double _factorPesoKgM3 = 2355.0;

const String _domFiscal =
    'Domicilio Fiscal: Mz-A Lte-7A Urb. Quinta Gamero Arequipa - Arequipa';
const String _viaGRE = 'Vía Evitamiento km 4.5. - Cerro Colorado - Arequipa';
const String _horarioGRE =
    'Horario de Atención: Domingo a Viernes de 7 am. a 5 pm';
const String _telfGRE = 'Telf: 950 703257 - 931473002';
const String _emailGRE = 'E-mail: venta@laroca.pe';
const String _domPartida =
    'VIA EVITAMIENTO KM 4.2 CERRO COLORADO AREQUIPA';

class SunatPdfGenerator {
  // ═════════════════════════════════════════════════════════════
  // GUÍA DE REMISIÓN ELECTRÓNICA
  // ═════════════════════════════════════════════════════════════
  static Future<Uint8List> generarGRE(Map<String, dynamic> datos) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/LOGO2023.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final serieCorrelativo = datos['serie_correlativo'] ?? 'T001 - 00000000';
    final fechaEmision = datos['fecha_emision'] ?? '';
    final fechaTraslado = datos['fecha_traslado'] ?? '';
    final opNro = datos['op_nro'] ?? '';

    final double volM3 =
        double.tryParse(datos['volumen']?.toString() ?? '0') ?? 0.0;
    final double peso = volM3 * _factorPesoKgM3;
    final String volStr =
        volM3 % 1 == 0 ? volM3.toInt().toString() : volM3.toStringAsFixed(1);
    final String pesoStr = _numFormato(peso);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 55, 30, 25),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── 1. ENCABEZADO ─────────────────────────────────
            _encabezadoGRE(logo, serieCorrelativo),
            pw.SizedBox(height: 15),

            // ── 2. FECHAS Y OP ────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _labelValor('Fecha de Emisión :', fechaEmision),
                _labelValor('Fecha de traslado :', fechaTraslado),
                pw.Text(
                  opNro,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),

            // ── 3. DOMICILIOS ─────────────────────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _cajaTitulo(
                    'DOMICILIO DE PARTIDA',
                    pw.Text(
                      _domPartida,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _cajaTitulo(
                    'DOMICILIO LLEGADA',
                    pw.Text(
                      (datos['domicilio_llegada']?.toString() ?? 'S/D')
                          .toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),

            // ── 4. DESTINATARIO / TRANSPORTE ──────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _cajaTitulo(
                    'DESTINATARIO',
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _richtextFila(
                          'Cliente :',
                          datos['cliente_nombre']?.toString() ?? '',
                        ),
                        pw.SizedBox(height: 4),
                        _richtextFila(
                          'RUC / DNI :',
                          datos['cliente_documento']?.toString() ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _cajaTitulo(
                    'UNIDAD DE TRANSPORTE / CONDUCTOR',
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _richtextFila(
                          'Conductor :',
                          (datos['conductor']?.toString() ?? '').toUpperCase(),
                        ),
                        pw.SizedBox(height: 4),
                        _richtextFila(
                          'N° Licencia :',
                          datos['licencia']?.toString() ?? '',
                        ),
                        pw.SizedBox(height: 4),
                        _richtextFila(
                          'Marca y placa :',
                          (datos['placa']?.toString() ?? '').toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),

            // ── 5. TABLA DETALLE (ESTIRADA HASTA EL FONDO) ────
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    // Cabecera de tabla
                    pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          _thStretched('ITEM', 35),
                          _thStretched('CÓDIGO', 55),
                          _thStretched('DESCRIPCIÓN', 230),
                          _thStretched('CANT.', 45),
                          _thStretched('U.M', 35),
                          _thStretched('PESO', 70, isLast: true),
                        ],
                      ),
                    ),

                    // Cuerpo expandible
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          _tdStretchedC('1', 35),
                          _tdStretchedC(
                              datos['codigo_producto'] ?? 'PD00022', 55),
                          _tdStretchedDesc(datos, 230),
                          _tdStretchedC(volStr, 45),
                          _tdStretchedC('M3', 35),
                          _tdStretchedC(pesoStr, 70, isLast: true),
                        ],
                      ),
                    ),

                    // Footer Peso Bruto
                    pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          _tdStretchedEmpty(35),
                          _tdStretchedFooter('PESO BRUTO (KG) :', 285),
                          _tdStretchedEmpty(45),
                          _tdStretchedEmpty(35),
                          _tdStretchedFooterVal(pesoStr, 70, isLast: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // ── 6. COMPROBANTE + MOTIVO DEL TRASLADO ──────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _cajaTitulo(
                        'COMPROBANTE DE PAGO',
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _campoBorde('Tip. Doc :', valor: ''),
                            pw.SizedBox(height: 6),
                            _campoBorde('N° Doc. :',
                                valor: datos['factura_ref'] ?? ''),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      _cajaTitulo(
                        'TRANSPORTISTA',
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _campoBorde('Tip. Doc :'),
                            pw.SizedBox(height: 6),
                            _campoBorde('N° Doc. :'),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      _cajaTipoTransporte(),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _motivoTraslado(),
                ),
              ],
            ),

            pw.SizedBox(height: 60),

            // ── 7. FIRMAS ─────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _firma('ENTREGUÉ CONFORME'),
                _firma('RECIBÍ CONFORME'),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ═════════════════════════════════════════════════════════════
  // FACTURA ELECTRÓNICA
  // ═════════════════════════════════════════════════════════════
  static Future<Uint8List> generarFactura(Map<String, dynamic> datos) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/LOGO2023.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final serieCorrelativo = datos['serie_correlativo'] ?? 'F001 - 00000000';
    final fechaEmision = datos['fecha_emision'] ?? '';
    final isFactura = (datos['tipo_doc'] ?? '01') == '01';
    final titulo = isFactura ? 'FACTURA ELECTRÓNICA' : 'BOLETA ELECTRÓNICA';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 55, 30, 25),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              _encabezadoFactura(logo, titulo, serieCorrelativo),
              pw.SizedBox(height: 20),

              // DATOS CLIENTE
              pw.Container(
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _richtextFila('Cliente:',
                              datos['cliente_nombre'] ?? ''),
                          pw.SizedBox(height: 4),
                          _richtextFila('RUC/DNI:',
                              datos['cliente_documento'] ?? ''),
                          pw.SizedBox(height: 4),
                          _richtextFila('Dirección:',
                              datos['cliente_direccion'] ?? ''),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _richtextFila('Fecha Emisión:', fechaEmision),
                          pw.SizedBox(height: 4),
                          _richtextFila('Moneda:', 'SOLES'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // TABLA ITEMS FACTURA
              _buildTablaFactura(datos),

              pw.SizedBox(height: 10),

              // TOTALES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.black, width: 0.8)),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SUBTOTAL:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9)),
                            pw.Text(
                                'S/ ${(datos['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                                style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('IGV (18%):',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9)),
                            pw.Text(
                                'S/ ${(datos['igv'] ?? 0.0).toStringAsFixed(2)}',
                                style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10)),
                            pw.Text(
                                'S/ ${(datos['total'] ?? 0.0).toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ═════════════════════════════════════════════════════════════
  // ENCABEZADOS
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _encabezadoGRE(
      pw.MemoryImage? logo, String serieCorrelativo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.SizedBox(
                  width: 160,
                  height: 60,
                  child: pw.Image(
                    logo,
                    fit: pw.BoxFit.contain,
                    alignment: pw.Alignment.centerLeft,
                  ),
                ),
              pw.SizedBox(height: 8),
              ...[_domFiscal, _viaGRE, _horarioGRE, _telfGRE, _emailGRE].map(
                (l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    l,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 200,
          margin: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.3),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'R.U.C N° 20614288095',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'GUÍA DE REMISIÓN',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(
                      'ELECTRÓNICA',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                ),
                child: pw.Text(
                  serieCorrelativo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _encabezadoFactura(
      pw.MemoryImage? logo, String titulo, String serieCorrelativo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.SizedBox(
                  width: 160,
                  height: 60,
                  child: pw.Image(
                    logo,
                    fit: pw.BoxFit.contain,
                    alignment: pw.Alignment.centerLeft,
                  ),
                ),
              pw.SizedBox(height: 8),
              ...[_domFiscal, _viaGRE, _horarioGRE, _telfGRE, _emailGRE].map(
                (l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    l,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 200,
          margin: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.3),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'R.U.C N° 20614288095',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      titulo,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                ),
                child: pw.Text(
                  serieCorrelativo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // COLUMNA DESCRIPCIÓN (igual que pdf_generator.dart)
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _columnaDescripcionGRE(Map<String, dynamic> d) {
    String diseno = (d['diseno']?.toString() ?? '')
        .toUpperCase()
        .replaceAll("F'C=", '')
        .replaceAll("F'C =", '')
        .replaceAll("FC=", '')
        .trim();

    final slump = d['slump']?.toString() ?? '';
    final huso = d['huso']?.toString() ?? '';
    final bomba = d['bomba']?.toString() ?? '';
    final hora = d['hora_salida']?.toString() ?? '';
    final precinto = d['precinto']?.toString() ?? '';

    String cemento =
        (d['cemento']?.toString() ?? 'CEMENTO YURA PRO').toUpperCase();
    if (!cemento.contains('CEMENTO') && cemento.isNotEmpty && cemento != '-') {
      cemento = 'CEMENTO $cemento';
    }

    String aditivo = (d['aditivo']?.toString() ?? '').toUpperCase();
    if (!aditivo.contains('ADITIVO') && aditivo.isNotEmpty && aditivo != '-') {
      aditivo = 'ADITIVO $aditivo';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CONCRETO PRE-MEZCLADO FC=$diseno KG/CM2, BOMBEABLE',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        if (cemento.isNotEmpty && cemento != '-')
          pw.Text('* $cemento', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 4),
        if (slump.isNotEmpty && slump != '-')
          pw.Text('* SLUMP $slump', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 4),
        if (huso.isNotEmpty && huso != '-')
          pw.Text('* HUSO $huso', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 4),
        if (aditivo.isNotEmpty && aditivo != '-')
          pw.Text('* $aditivo', style: const pw.TextStyle(fontSize: 8.5)),

        // Empuja el contenido inferior contra el borde inferior
        pw.Spacer(),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (bomba.isNotEmpty && bomba != '-')
              pw.Text(
                'BOMBA $bomba',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            pw.SizedBox(width: 30),
            pw.Text(
              'Hora de Salida: $hora',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (precinto.isNotEmpty) ...[
              pw.SizedBox(width: 30),
              pw.Text(
                precinto,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 5),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // HELPERS TABLA ESTIRABLE (misma arquitectura que pdf_generator)
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _thStretched(String texto, int flex,
      {bool isLast = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: pw.BoxDecoration(
          border: isLast
              ? null
              : const pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                ),
        ),
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2),
        ),
      ),
    );
  }

  static pw.Widget _tdStretchedC(String texto, int flex,
      {bool isLast = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(4, 10, 4, 10),
        decoration: pw.BoxDecoration(
          border: isLast
              ? null
              : const pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                ),
        ),
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8.5),
        ),
      ),
    );
  }

  static pw.Widget _tdStretchedDesc(Map<String, dynamic> datos, int flex) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
        child: _columnaDescripcionGRE(datos),
      ),
    );
  }

  static pw.Widget _tdStretchedEmpty(int flex) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
      ),
    );
  }

  static pw.Widget _tdStretchedFooter(String texto, int flex) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
        ),
      ),
    );
  }

  static pw.Widget _tdStretchedFooterVal(String texto, int flex,
      {bool isLast = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: pw.BoxDecoration(
          border: isLast
              ? null
              : const pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                ),
        ),
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // HELPERS REUTILIZABLES
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _cajaTitulo(String titulo, pw.Widget contenido) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
              ),
            ),
            child: pw.Text(
              titulo,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.2,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: contenido,
          ),
        ],
      ),
    );
  }

  static pw.Widget _richtextFila(String label, String valor) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
          ),
          pw.TextSpan(text: valor, style: const pw.TextStyle(fontSize: 8.5)),
        ],
      ),
    );
  }

  static pw.Widget _labelValor(String label, String valor) {
    return pw.Row(
      children: [
        if (label.isNotEmpty)
          pw.Text(
            '$label  ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
        pw.Text(valor, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _campoBorde(String label, {String valor = ''}) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        ),
        pw.SizedBox(width: 6),
        pw.Text(valor, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _firma(String texto) {
    return pw.Container(
      width: 195,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 0.8),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      ),
    );
  }

  // ── TIPO DE TRANSPORTE ──────────────────────────────────────
  static pw.Widget _cajaTipoTransporte() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
              ),
            ),
            child: pw.Text(
              'TIPO DE TRANSPORTE',
              textAlign: pw.TextAlign.center,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Transporte\nPúblico',
                        style: const pw.TextStyle(fontSize: 7)),
                    pw.SizedBox(width: 4),
                    _checkbox(false),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Text('Transporte\nPrivado',
                        style: const pw.TextStyle(fontSize: 7)),
                    pw.SizedBox(width: 4),
                    _checkbox(true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── MOTIVO DEL TRASLADO ─────────────────────────────────────
  static pw.Widget _motivoTraslado() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
              ),
            ),
            child: pw.Text(
              'MOTIVO DEL TRASLADO',
              textAlign: pw.TextAlign.center,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _motivoItem('1. Venta', true),
                      _motivoItem('2. Venta sujeta a confirmación del\n    comprador', false),
                      _motivoItem('3. Compra', false),
                      _motivoItem('4. Consignación', false),
                      _motivoItem('5. Devolución', false),
                      _motivoItem('6. Traslado entre establecimientos', false),
                    ],
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _motivoItem('7. Traslado de Bienes para\n    Transformación', false),
                      _motivoItem('8. Recojo de Bienes\n    Transformados', false),
                      _motivoItem('9. Traslado Emisor Itinerante CP', false),
                      _motivoItem('10. Venta con Entrega a Terceros', false),
                      _motivoItem('11. Otros', false),
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

  static pw.Widget _motivoItem(String texto, bool checked) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(texto, style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.SizedBox(width: 4),
          _checkbox(checked),
        ],
      ),
    );
  }

  static pw.Widget _checkbox(bool checked) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: checked
          ? pw.Center(
              child: pw.Text('X',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
            )
          : pw.Container(),
    );
  }

  // ── TABLA FACTURA ───────────────────────────────────────────
  static pw.Widget _buildTablaFactura(Map<String, dynamic> datos) {
    final descripcion = datos['descripcion'] ?? 'CONCRETO PRE-MEZCLADO';
    final volumen = datos['volumen'] ?? '0.00';
    final unitario = datos['unitario'] ?? '0.00';
    final total = datos['total_item'] ?? '0.00';

    return pw.Container(
      height: 250,
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.8)),
      child: pw.Column(
        children: [
          pw.Container(
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom:
                        pw.BorderSide(color: PdfColors.black, width: 0.8))),
            child: pw.Row(
              children: [
                _thStretched('ITEM', 30),
                _thStretched('CÓDIGO', 50),
                _thStretched('DESCRIPCIÓN', 200),
                _thStretched('CANT.', 40),
                _thStretched('P. UNIT', 60),
                _thStretched('TOTAL', 60, isLast: true),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Row(
              children: [
                _tdStretchedC('1', 30),
                _tdStretchedC('P000002', 50),
                pw.Expanded(
                  flex: 200,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(
                            color: PdfColors.black, width: 0.8),
                      ),
                    ),
                    child: pw.Text(descripcion,
                        style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                ),
                _tdStretchedC(volumen, 40),
                _tdStretchedC(unitario, 60),
                _tdStretchedC(total, 60, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── UTILIDADES ──────────────────────────────────────────────
  static String _numFormato(double v) {
    final partes = v.toStringAsFixed(2).split('.');
    final entero = partes[0];
    final dec = partes[1];
    final sb = StringBuffer();
    int count = 0;
    for (int i = entero.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) sb.write(',');
      sb.write(entero[i]);
      count++;
    }
    return '${sb.toString().split('').reversed.join()}.$dec';
  }
}
