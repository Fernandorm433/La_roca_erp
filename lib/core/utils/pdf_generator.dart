// lib/core/utils/pdf_generator.dart
// Guía de Despacho — NOVACONCRET
// Formato Corporativo Elegante (Azul Marino, Celeste y Gris)

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────
// CONSTANTES CORPORATIVAS
// ─────────────────────────────────────────────────────────────
const double _factorPesoKgM3 = 2355.0;

const _azulOscuro = PdfColor.fromInt(0xFF0C3866);     // Navy profundo
const _azulPrimario = PdfColor.fromInt(0xFF0284C7);   // Cyan corporativo
const _azulClaroFondo = PdfColor.fromInt(0xFFF0F9FF); // Fondo suave hielo
const _azulBorde = PdfColor.fromInt(0xFFBAE6FD);      // Borde celeste suave
const _grisTexto = PdfColor.fromInt(0xFF475569);      // Gris textos
const _grisMuted = PdfColor.fromInt(0xFF64748B);      // Gris secundario
const _negro = PdfColor.fromInt(0xFF0F172A);          // Texto oscuro
const _blanco = PdfColor.fromInt(0xFFFFFFFF);

const String _domicilioFiscal = 'AV. ATAHUALPA NRO. 204 URB. ALTO SELVA ALEGRE - AREQUIPA';
const String _plantaUchumayo = 'VARIANTE UCHUMAYO - CERRO COLORADO - AREQUIPA - AREQUIPA';
const String _telfEmpresa = '+51 982 503 604';
const String _emailEmpresa = 'novaconcretsac@gmail.com';
const String _rucEmpresa = '20616487141';

class PdfGenerator {
  static Future<Uint8List> generarGuiaDespacho(Map<String, dynamic> datos) async {
    final pdf = pw.Document(
      title: 'Guia_Despacho_${datos['nro_guia'] ?? ''}',
      author: 'ERP NOVACONCRET',
    );

    // Cargar logo
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/LOGO_NOVA.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      try {
        final bytes2 = await rootBundle.load('assets/images/ICONO_NOVA.png');
        logo = pw.MemoryImage(bytes2.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }
    }

    final double volM3 = (datos['vol_m3'] as num?)?.toDouble() ?? 0.0;
    final double peso = volM3 * _factorPesoKgM3;
    final String fecha = _fecha(datos['fecha']?.toString());
    final String volStr = volM3 % 1 == 0 ? volM3.toInt().toString() : volM3.toStringAsFixed(1);
    final String pesoStr = _numFormato(peso);
    final String nroGuia = datos['nro_guia']?.toString() ?? 'GD-000000';
    final String opNro = datos['op_nro']?.toString() ?? '';

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. ENCABEZADO Y RECUADRO DE GUÍA ──────────────
            _buildEncabezado(logo, nroGuia, boldFont, baseFont),
            pw.SizedBox(height: 10),

            // ── 2. BARRA DE FECHAS Y OP ───────────────────────
            _buildBarraFechas(fecha, opNro, boldFont, baseFont),
            pw.SizedBox(height: 8),

            // ── 3. DOMICILIOS (PARTIDA Y LLEGADA) ─────────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'DOMICILIO DE PARTIDA',
                    bold: boldFont,
                    child: pw.Center(
                      child: pw.Text(
                        _plantaUchumayo,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: boldFont, fontSize: 7.2, color: _azulOscuro),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'DOMICILIO DE LLEGADA (OBRA)',
                    bold: boldFont,
                    child: pw.Center(
                      child: pw.Text(
                        (datos['direccion_obra']?.toString() ?? 'S/D').toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: boldFont, fontSize: 7.2, color: _azulOscuro),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── 4. DESTINATARIO Y TRANSPORTE / MIXER ──────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'DATOS DEL DESTINATARIO',
                    bold: boldFont,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFilaDato('CLIENTE:', (datos['cliente']?.toString() ?? '-').toUpperCase(), boldFont, baseFont),
                        pw.SizedBox(height: 3),
                        _buildFilaDato('RUC / DNI:', datos['ruc_dni']?.toString() ?? '-', boldFont, baseFont),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'UNIDAD DE TRANSPORTE / CONDUCTOR',
                    bold: boldFont,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFilaDato('CONDUCTOR:', (datos['conductor']?.toString() ?? '-').toUpperCase(), boldFont, baseFont),
                        pw.SizedBox(height: 3),
                        _buildFilaDato(
                          'MIXER / PLACA:',
                          '${(datos['marca_vehiculo']?.toString() ?? '').toUpperCase()}'
                          '${(datos['marca_vehiculo']?.toString() ?? '').isNotEmpty ? ' / ' : ''}'
                          '${(datos['placa_vehiculo']?.toString() ?? '-').toUpperCase()}',
                          boldFont,
                          baseFont,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── 5. TABLA TÉCNICA DE DESPACHO ──────────────────
            pw.Expanded(
              child: _buildTablaDetalle(datos, volStr, pesoStr, boldFont, baseFont),
            ),
            pw.SizedBox(height: 8),

            // ── 6. COMPROBANTE Y CONTROL ──────────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'COMPROBANTE DE PAGO',
                    bold: boldFont,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFilaDato('TIPO DOC:', datos['comprobante_tipo']?.toString() ?? 'RECIBO / GUÍA', boldFont, baseFont),
                        _buildFilaDato('N° DOC:', opNro.isNotEmpty ? opNro : '-', boldFont, baseFont),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'CONTROL DE PLANTA',
                    bold: boldFont,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFilaDato('PLANTA:', 'UCHUMAYO 01', boldFont, baseFont),
                        _buildFilaDato('ESTADO:', 'DESPACHADO', boldFont, baseFont),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ── 7. SECCIÓN DE FIRMAS ──────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildFirmaBox('ENTREGUÉ CONFORME\n(CONDUCTOR / OPERADOR)', boldFont, baseFont),
                _buildFirmaBox('RECIBÍ CONFORME\n(CLIENTE / RESPONSABLE OBRA)', boldFont, baseFont),
              ],
            ),
            pw.SizedBox(height: 10),

            // ── 8. PIE DE PÁGINA CORPORATIVO ──────────────────
            _buildFooterBar(boldFont, baseFont),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // ENCABEZADO
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildEncabezado(
    pw.MemoryImage? logo,
    String nroGuia,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Lado izquierdo: Logo + Datos de Empresa
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Image(logo, height: 42, fit: pw.BoxFit.contain)
            else
              pw.Row(
                children: [
                  pw.Container(
                    width: 30,
                    height: 30,
                    decoration: pw.BoxDecoration(
                      color: _azulPrimario,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('N', style: pw.TextStyle(color: _blanco, font: bold, fontSize: 18)),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text('NOVACON', style: pw.TextStyle(font: bold, fontSize: 20, color: _azulOscuro)),
                ],
              ),
            pw.SizedBox(height: 3),
            pw.Text(
              'NOVACONCRET S.A.C.  |  RUC: $_rucEmpresa',
              style: pw.TextStyle(font: bold, fontSize: 7, color: _azulOscuro),
            ),
            pw.Text(
              'Planta: $_plantaUchumayo',
              style: pw.TextStyle(font: regular, fontSize: 5.8, color: _grisTexto),
            ),
            pw.Text(
              'Oficina: $_domicilioFiscal',
              style: pw.TextStyle(font: regular, fontSize: 5.8, color: _grisTexto),
            ),
            pw.Text(
              'Telf: $_telfEmpresa  |  $_emailEmpresa',
              style: pw.TextStyle(font: bold, fontSize: 5.8, color: _azulPrimario),
            ),
          ],
        ),

        // Lado derecho: Tarjeta de Guía de Despacho
        pw.Container(
          width: 175,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _azulOscuro, width: 1.2),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: _azulOscuro,
                  borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4.5)),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'R.U.C. N° $_rucEmpresa',
                  style: pw.TextStyle(font: bold, fontSize: 8.5, color: _blanco),
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                color: _blanco,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'GUÍA DE DESPACHO',
                  style: pw.TextStyle(font: bold, fontSize: 11, color: _azulOscuro, letterSpacing: 0.5),
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                decoration: const pw.BoxDecoration(
                  color: _azulClaroFondo,
                  borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(4.5)),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  nroGuia,
                  style: pw.TextStyle(font: bold, fontSize: 13, color: _azulPrimario),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BARRA DE FECHAS
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildBarraFechas(
    String fecha,
    String opNro,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: pw.BoxDecoration(
        color: _azulClaroFondo,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _azulBorde, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildItemBarra('Fecha de Emisión:', fecha, bold, regular),
          _buildItemBarra('Fecha de Traslado:', fecha, bold, regular),
          if (opNro.isNotEmpty)
            _buildItemBarra('Orden de Pedido:', opNro, bold, regular)
          else
            _buildItemBarra('Condición:', 'CONFORME EN PLANTA', bold, regular),
        ],
      ),
    );
  }

  static pw.Widget _buildItemBarra(String label, String valor, pw.Font bold, pw.Font regular) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7.5, color: _azulOscuro)),
        pw.SizedBox(width: 4),
        pw.Text(valor, style: pw.TextStyle(font: regular, fontSize: 7.5, color: _negro)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TARJETA CONTENEDORA CORPORATIVA
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildTarjeta({
    required String titulo,
    required pw.Widget child,
    required pw.Font bold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: const pw.BoxDecoration(
            color: _azulPrimario,
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
          ),
          child: pw.Text(
            titulo,
            style: pw.TextStyle(font: bold, fontSize: 7.5, color: _blanco, letterSpacing: 0.3),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _blanco,
            borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(4)),
            border: pw.Border.all(color: _azulBorde, width: 0.8),
          ),
          child: child,
        ),
      ],
    );
  }

  static pw.Widget _buildFilaDato(String label, String valor, pw.Font bold, pw.Font regular) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label ', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _azulOscuro)),
        pw.Expanded(
          child: pw.Text(
            valor,
            style: pw.TextStyle(font: regular, fontSize: 7.2, color: _negro),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLA DETALLE TÉCNICO
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildTablaDetalle(
    Map<String, dynamic> datos,
    String volStr,
    String pesoStr,
    pw.Font bold,
    pw.Font regular,
  ) {
    const colWidths = [
      pw.FlexColumnWidth(0.8), // ITEM
      pw.FlexColumnWidth(5.2), // DESCRIPCIÓN TÉCNICA
      pw.FlexColumnWidth(1.2), // CANTIDAD
      pw.FlexColumnWidth(1.0), // UNIDAD
      pw.FlexColumnWidth(1.6), // PESO TOTAL
    ];

    final headers = ['ITEM', 'DESCRIPCIÓN TÉCNICA', 'CANTIDAD', 'UNIDAD', 'PESO (KG)'];

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _azulBorde, width: 0.8),
      ),
      child: pw.Column(
        children: [
          // Cabecera de la tabla en Azul Marino
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _azulOscuro,
              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(3.5)),
            ),
            child: pw.Table(
              columnWidths: {for (int i = 0; i < colWidths.length; i++) i: colWidths[i]},
              children: [
                pw.TableRow(
                  children: headers.map((h) {
                    final isLeft = h.contains('DESCRIPCIÓN');
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(font: bold, fontSize: 7.5, color: _blanco),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Cuerpo de la tabla (fila de producto)
          pw.Expanded(
            child: pw.Container(
              color: _blanco,
              child: pw.Table(
                columnWidths: {for (int i = 0; i < colWidths.length; i++) i: colWidths[i]},
                children: [
                  pw.TableRow(
                    children: [
                      // ITEM
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('1', style: pw.TextStyle(font: bold, fontSize: 8, color: _azulOscuro)),
                      ),
                      // DESCRIPCIÓN
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: _buildDescripcionTecnica(datos, bold, regular),
                      ),
                      // CANTIDAD
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text(volStr, style: pw.TextStyle(font: bold, fontSize: 9, color: _negro)),
                      ),
                      // UNIDAD
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('M3', style: pw.TextStyle(font: regular, fontSize: 8, color: _grisTexto)),
                      ),
                      // PESO
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text(pesoStr, style: pw.TextStyle(font: bold, fontSize: 8.5, color: _negro)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Footer de Totales y Peso Bruto
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: _azulClaroFondo,
              borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(3.5)),
              border: pw.Border(top: pw.BorderSide(color: _azulBorde, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'OBSERVACIÓN: DESPACHO PROGRAMADO DE CONCRETO PREMEZCLADO',
                  style: pw.TextStyle(font: regular, fontSize: 6.5, color: _grisTexto),
                ),
                pw.Row(
                  children: [
                    pw.Text('PESO BRUTO TOTAL (KG): ', style: pw.TextStyle(font: bold, fontSize: 7.5, color: _azulOscuro)),
                    pw.Text('$pesoStr KG', style: pw.TextStyle(font: bold, fontSize: 8, color: _azulPrimario)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DETALLE TÉCNICO CONCRETO
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildDescripcionTecnica(
    Map<String, dynamic> d,
    pw.Font bold,
    pw.Font regular,
  ) {
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
    final precinto = d['nro_precinto']?.toString() ?? '';

    String cemento = (d['cemento']?.toString() ?? 'CEMENTO YURA HE').toUpperCase();
    if (!cemento.contains('CEMENTO YURA') && cemento.isNotEmpty && cemento != '-') {
      cemento = 'CEMENTO YURA $cemento';
    }

    String aditivo = (d['aditivo']?.toString() ?? '').toUpperCase();
    if (!aditivo.contains('ADITIVO') && aditivo.isNotEmpty && aditivo != '-') {
      aditivo = 'ADITIVO $aditivo';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CONCRETO PRE-MEZCLADO FC=$diseno KG/CM2',
          style: pw.TextStyle(font: bold, fontSize: 8.5, color: _azulOscuro),
        ),
        pw.SizedBox(height: 3),
        _buildBulletItem('CEMENTO: $cemento', regular),
        if (slump.isNotEmpty) _buildBulletItem('SLUMP: $slump', regular),
        if (huso.isNotEmpty) _buildBulletItem('HUSO: $huso', regular),
        if (aditivo.isNotEmpty && aditivo != '-') _buildBulletItem(aditivo, regular),
        if (bomba.isNotEmpty) _buildBulletItem('SERVICIO: BOMBA $bomba', regular),
        if (hora.isNotEmpty) _buildBulletItem('HORA DE SALIDA: $hora', regular),
        if (precinto.isNotEmpty) _buildBulletItem('N° PRECINTO: $precinto', regular),
      ],
    );
  }

  static pw.Widget _buildBulletItem(String texto, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2, left: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 3.2,
            height: 3.2,
            margin: const pw.EdgeInsets.only(right: 4),
            decoration: const pw.BoxDecoration(
              color: _azulPrimario,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              texto,
              style: pw.TextStyle(font: regular, fontSize: 6.8, color: _grisTexto),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RECUADRO DE FIRMAS
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildFirmaBox(String cargo, pw.Font bold, pw.Font regular) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        children: [
          pw.Container(
            height: 32, // Espacio para firma
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _azulOscuro, width: 1)),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            cargo,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: bold, fontSize: 7, color: _azulOscuro),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FOOTER CORPORATIVO
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildFooterBar(pw.Font bold, pw.Font regular) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: _azulOscuro,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PLANTA: $_plantaUchumayo',
                    style: pw.TextStyle(font: bold, fontSize: 6.2, color: _blanco),
                  ),
                  pw.Text(
                    'OFICINA: $_domicilioFiscal',
                    style: pw.TextStyle(font: regular, fontSize: 6.2, color: const PdfColor(0.85, 0.92, 1.0)),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Telf / Cel: $_telfEmpresa',
                    style: pw.TextStyle(font: bold, fontSize: 6.5, color: _blanco),
                  ),
                  pw.Text(
                    _emailEmpresa,
                    style: pw.TextStyle(font: bold, fontSize: 6.5, color: const PdfColor(0.75, 0.9, 1.0)),
                  ),
                  pw.Text(
                    'NOVACONCRET S.A.C. - RUC: $_rucEmpresa',
                    style: pw.TextStyle(font: bold, fontSize: 6.2, color: _blanco),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Documento emitido por el Sistema ERP NOVACONCRET. Válido para control de despacho en obra.',
            style: pw.TextStyle(font: regular, fontSize: 5.6, color: _grisMuted),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UTILIDADES
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
