// lib/core/utils/pdf_generator.dart
// Guía de Despacho — La Roca Concretos
// Diseño fiel al formato físico original - Estirado dinámico

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────
// CONSTANTES
// ─────────────────────────────────────────────────────────────
const double _factorPesoKgM3 = 2355.0;

const String _domicilioFiscal =
    'Domicilio Fiscal: Mz-A Lte-7A Urb. Quinta Gamero Arequipa - Arequipa';
const String _via = 'Vía Evitamiento km 4.2 - Cerro Colorado - Arequipa';
const String _horario =
    'Horario de Atención: Domingo a Viernes de 7 am. a 5 pm.';
const String _telf = 'Telf: 054669968 - 950703257 - 959265545 - 931473002';
const String _email = 'E-mail: venta@laroca.pe';
const String _web = 'Página Web: www.laroca.pe';
const String _domicilioPartida =
    'VIA EVITAMIENTO KM 4.2 CERRO COLORADO AREQUIPA';

// Colores corporativos
final PdfColor _verde = PdfColor.fromHex('00A650');

class PdfGenerator {
  static Future<Uint8List> generarGuiaDespacho(
    Map<String, dynamic> datos,
  ) async {
    final pdf = pw.Document();

    // Cargar logo
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/LOGO2023.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final double volM3 = (datos['vol_m3'] as num?)?.toDouble() ?? 0.0;
    final double peso = volM3 * _factorPesoKgM3;
    final String fecha = _fecha(datos['fecha']?.toString());
    final String volStr = volM3 % 1 == 0
        ? volM3.toInt().toString()
        : volM3.toStringAsFixed(1);
    final String pesoStr = _numFormato(peso);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // Margen superior ajustado a 55 para bajar el encabezado
        margin: const pw.EdgeInsets.fromLTRB(30, 55, 30, 25),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── 1. ENCABEZADO ─────────────────────────────────
            _encabezado(logo, datos['nro_guia']?.toString() ?? ''),
            pw.SizedBox(height: 15),

            // ── 2. FECHAS Y OP ────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _labelValor('Fecha de Emisión:', fecha),
                _labelValor('Fecha de Traslado:', fecha),
                pw.Text(
                  datos['op_nro']?.toString() ?? '',
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
                      _domicilioPartida,
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
                    'DOMICILIO DE LLEGADA',
                    pw.Text(
                      (datos['direccion_obra']?.toString() ?? 'S/D')
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
                          'CLIENTE :',
                          datos['cliente']?.toString() ?? '',
                        ),
                        pw.SizedBox(height: 4),
                        _richtextFila(
                          'RUC / DNI:',
                          datos['ruc_dni']?.toString() ?? '',
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
                          'CONDUCTOR:',
                          (datos['conductor']?.toString() ?? '').toUpperCase(),
                        ),
                        pw.SizedBox(height: 4),
                        _richtextFila(
                          'MARCA/PLACA:',
                          '${(datos['marca_vehiculo']?.toString() ?? '').toUpperCase()}'
                              '   /   '
                              '${(datos['placa_vehiculo']?.toString() ?? '').toUpperCase()}',
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
                          _thStretched('DESCRIPCIÓN', 230),
                          _thStretched('CANT.', 45),
                          _thStretched('UNIDAD', 45),
                          _thStretched('PESO', 70, isLast: true),
                        ],
                      ),
                    ),

                    // Cuerpo expandible (ocupa todo el espacio sobrante)
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          _tdStretchedC('1', 35),
                          _tdStretchedDesc(datos, 230),
                          _tdStretchedC(volStr, 45),
                          _tdStretchedC('M3', 45),
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
                          _tdStretchedFooter('PESO BRUTO (KG) :', 230),
                          _tdStretchedEmpty(45),
                          _tdStretchedEmpty(45),
                          _tdStretchedFooterVal(pesoStr, 70, isLast: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // ── 6. COMPROBANTE / TRANSPORTISTA ────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _cajaTitulo(
                    'COMPROBANTE DE PAGO',
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _campoBorde('TIP. DOC.:', valor: 'RECIBO'),
                        pw.SizedBox(height: 6),
                        _campoBorde('N° DOC.:'),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _cajaTitulo(
                    'TRANSPORTISTA',
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _campoBorde('TIP. DOC.:'),
                        pw.SizedBox(height: 6),
                        _campoBorde('N° DOC.:'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ── 7. FIRMAS ──────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────
  // ENCABEZADO
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _encabezado(pw.MemoryImage? logo, String nroGuia) {
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
              ...[_domicilioFiscal, _via, _horario, _telf, _email].map(
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
              pw.Text(
                _web,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),

        pw.Container(
          width: 170,
          margin: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.3),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                color: _verde, // Este verde se queda por identidad de marca
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  'GUIA DE DESPACHO',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 14),
                child: pw.Text(
                  nroGuia,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 18,
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

  // ─────────────────────────────────────────────────────────────
  // CELDA DINÁMICA DE DESCRIPCIÓN
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _columnaDescripcion(Map<String, dynamic> d) {
    String diseno = (d['diseno']?.toString() ?? '')
        .toUpperCase()
        .replaceAll("F'C=", '')
        .replaceAll("F'C =", '')
        .replaceAll("FC=", '')
        .trim();

    final slump = d['slump']?.toString() ?? '';
    final huso = d['huso']?.toString() ?? '';
    final aditivo = d['aditivo']?.toString() ?? '';
    final bomba = d['bomba']?.toString() ?? '';
    final hora = d['hora_salida']?.toString() ?? '';
    final precinto = d['nro_precinto']?.toString() ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CONCRETO PRE-MEZCLADO FC=$diseno',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          (d['cemento']?.toString() ?? 'CEMENTO YURA HE').toUpperCase(),
          style: const pw.TextStyle(fontSize: 8.5),
        ),
        pw.SizedBox(height: 4),
        if (slump.isNotEmpty)
          pw.Text('SLUMP $slump', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 4),
        if (huso.isNotEmpty)
          pw.Text('HUSO $huso', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 4),
        if (aditivo.isNotEmpty && aditivo != '-')
          pw.Text(
            aditivo.toUpperCase(),
            style: const pw.TextStyle(fontSize: 8.5),
          ),

        // Magia aquí: esto empuja el contenido inferior contra el borde inferior
        pw.Spacer(),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'BOMBA $bomba',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 30),
            pw.Text(
              'Hora de Salida:   $hora',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        if (precinto.isNotEmpty)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 35, bottom: 5),
              child: pw.Text(
                precinto.startsWith('P-') ? precinto : 'P-$precinto',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS PARA LA TABLA ESTIRABLE
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _thStretched(String texto, int flex, {bool isLast = false}) {
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

  static pw.Widget _tdStretchedC(
    String texto,
    int flex, {
    bool isLast = false,
  }) {
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
        child: _columnaDescripcion(datos),
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

  static pw.Widget _tdStretchedFooterVal(
    String texto,
    int flex, {
    bool isLast = false,
  }) {
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

  // ─────────────────────────────────────────────────────────────
  // HELPERS REUTILIZABLES (Sin fondos grises)
  // ─────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE DATOS
  // ─────────────────────────────────────────────────────────────
  static String _fecha(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return iso;
    }
  }

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
