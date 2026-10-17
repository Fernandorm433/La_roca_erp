// lib/core/utils/sunat_pdf_generator.dart
// Guía de Remisión Electrónica & Factura / Boleta — NOVACONCRET
// Formato Corporativo Elegante (Azul Marino, Celeste y Gris)

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

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

class SunatPdfGenerator {
  // ═════════════════════════════════════════════════════════════
  // 1. GUÍA DE REMISIÓN ELECTRÓNICA (GRE SUNAT)
  // ═════════════════════════════════════════════════════════════
  static Future<Uint8List> generarGRE(Map<String, dynamic> datos) async {
    final pdf = pw.Document(
      title: 'GRE_${datos['serie_correlativo'] ?? ''}',
      author: 'ERP NOVACONCRET',
    );

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

    final serieCorrelativo = datos['serie_correlativo']?.toString() ?? 'T001 - 00000000';
    final fechaEmision = datos['fecha_emision']?.toString() ?? '';
    final fechaTraslado = datos['fecha_traslado']?.toString() ?? '';
    final opNro = datos['op_nro']?.toString() ?? '';

    final double volM3 = double.tryParse(datos['volumen']?.toString() ?? '0') ?? 0.0;
    final double peso = volM3 * _factorPesoKgM3;
    final String volStr = volM3 % 1 == 0 ? volM3.toInt().toString() : volM3.toStringAsFixed(1);
    final String pesoStr = _numFormato(peso);

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. ENCABEZADO Y RECUADRO SUNAT ────────────────
            _buildEncabezadoDoc(
              logo: logo,
              tituloDoc: 'GUÍA DE REMISIÓN ELECTRÓNICA',
              subtituloDoc: 'REMITENTE',
              serieCorrelativo: serieCorrelativo,
              bold: boldFont,
              regular: baseFont,
            ),
            pw.SizedBox(height: 8),

            // ── 2. BARRA DE FECHAS Y OP ───────────────────────
            _buildBarraFechas(fechaEmision, fechaTraslado, opNro, boldFont, baseFont),
            pw.SizedBox(height: 7),

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
                        (datos['domicilio_llegada']?.toString() ?? 'S/D').toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: boldFont, fontSize: 7.2, color: _azulOscuro),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),

            // ── 4. DESTINATARIO Y TRANSPORTE ──────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'DATOS DEL DESTINATARIO',
                    bold: boldFont,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFilaDato('RAZÓN SOCIAL:', (datos['cliente_nombre'] ?? '-').toString().toUpperCase(), boldFont, baseFont),
                        pw.SizedBox(height: 2.5),
                        _buildFilaDato('RUC / DNI:', datos['cliente_documento']?.toString() ?? '-', boldFont, baseFont),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildTarjeta(
                    titulo: 'UNIDAD DE TRANSPORTE Y CONDUCTOR',
                    bold: boldFont,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFilaDato('CONDUCTOR:', (datos['conductor'] ?? '-').toString().toUpperCase(), boldFont, baseFont),
                        pw.SizedBox(height: 2.5),
                        _buildFilaDato('LICENCIA / PLACA:', '${datos['licencia'] ?? '-'}  /  ${(datos['placa'] ?? '-').toString().toUpperCase()}', boldFont, baseFont),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),

            // ── 5. TABLA DETALLE (ESTIRADA) ───────────────────
            pw.Expanded(
              child: _buildTablaDetalleGRE(datos, volStr, pesoStr, boldFont, baseFont),
            ),
            pw.SizedBox(height: 7),

            // ── 6. COMPROBANTE + MOTIVOS DEL TRASLADO ─────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    children: [
                      _buildTarjeta(
                        titulo: 'COMPROBANTE DE PAGO ASOCIADO',
                        bold: boldFont,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFilaDato('TIPO:', 'FACTURA ELECTRÓNICA', boldFont, baseFont),
                            _buildFilaDato('N° DOC:', datos['factura_ref']?.toString().isNotEmpty == true ? datos['factura_ref'] : '-', boldFont, baseFont),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      _buildTarjeta(
                        titulo: 'MODALIDAD DE TRANSPORTE',
                        bold: boldFont,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            _buildCheckOption('Transporte Privado', true, boldFont, baseFont),
                            _buildCheckOption('Transporte Público', false, boldFont, baseFont),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  flex: 6,
                  child: _buildTarjeta(
                    titulo: 'MOTIVO DEL TRASLADO',
                    bold: boldFont,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildMotivoItem('1. Venta', true, boldFont, baseFont),
                              _buildMotivoItem('2. Compra', false, boldFont, baseFont),
                              _buildMotivoItem('3. Consignación', false, boldFont, baseFont),
                              _buildMotivoItem('4. Devolución', false, boldFont, baseFont),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildMotivoItem('5. Traslado entre plantas', false, boldFont, baseFont),
                              _buildMotivoItem('6. Transformación', false, boldFont, baseFont),
                              _buildMotivoItem('7. Entrega a terceros', false, boldFont, baseFont),
                              _buildMotivoItem('8. Otros', false, boldFont, baseFont),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // ── 7. SECCIÓN DE FIRMAS ──────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildFirmaBox('ENTREGUÉ CONFORME\n(CONDUCTOR / OPERADOR)', boldFont, baseFont),
                _buildFirmaBox('RECIBÍ CONFORME\n(CLIENTE / RESPONSABLE OBRA)', boldFont, baseFont),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── 8. PIE DE PÁGINA CORPORATIVO ──────────────────
            _buildFooterBar(boldFont, baseFont, 'Representación impresa de la Guía de Remisión Electrónica remitente generada desde el ERP NOVACONCRET.'),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ═════════════════════════════════════════════════════════════
  // 2. FACTURA / BOLETA ELECTRÓNICA SUNAT
  // ═════════════════════════════════════════════════════════════
  static Future<Uint8List> generarFactura(Map<String, dynamic> datos) async {
    final pdf = pw.Document(
      title: 'Factura_${datos['serie_correlativo'] ?? ''}',
      author: 'ERP NOVACONCRET',
    );

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

    final serieCorrelativo = datos['serie_correlativo']?.toString() ?? 'F001 - 00000000';
    final fechaEmision = datos['fecha_emision']?.toString() ?? '';
    final isFactura = (datos['tipo_doc'] ?? '01') == '01';
    final tituloDoc = isFactura ? 'FACTURA ELECTRÓNICA' : 'BOLETA ELECTRÓNICA';

    final subtotal = (datos['subtotal'] as num?)?.toDouble() ?? 0.0;
    final igv = (datos['igv'] as num?)?.toDouble() ?? (subtotal * 0.18);
    final total = (datos['total'] as num?)?.toDouble() ?? (subtotal + igv);

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. ENCABEZADO SUNAT ───────────────────────────
            _buildEncabezadoDoc(
              logo: logo,
              tituloDoc: tituloDoc,
              subtituloDoc: 'VENTA DE CONCRETO PREMEZCLADO',
              serieCorrelativo: serieCorrelativo,
              bold: boldFont,
              regular: baseFont,
            ),
            pw.SizedBox(height: 10),

            // ── 2. DATOS DEL CLIENTE (TARJETA) ────────────────
            _buildTarjeta(
              titulo: 'DATOS DEL RECEPTOR / CLIENTE',
              bold: boldFont,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFilaDato('SEÑOR(ES):', (datos['cliente_nombre'] ?? 'CLIENTE GENERAL').toString().toUpperCase(), boldFont, baseFont),
                        pw.SizedBox(height: 3),
                        _buildFilaDato('RUC / DNI:', datos['cliente_documento']?.toString() ?? '-', boldFont, baseFont),
                        pw.SizedBox(height: 3),
                        _buildFilaDato('DIRECCIÓN:', (datos['cliente_direccion'] ?? 'AREQUIPA').toString().toUpperCase(), boldFont, baseFont),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFilaDato('FECHA EMISIÓN:', fechaEmision, boldFont, baseFont),
                        pw.SizedBox(height: 3),
                        _buildFilaDato('MONEDA:', 'SOLES (PEN)', boldFont, baseFont),
                        pw.SizedBox(height: 3),
                        _buildFilaDato('CONDICIÓN PAGO:', 'CONTADO / CRÉDITO', boldFont, baseFont),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── 3. TABLA DE DETALLE FACTURA ───────────────────
            pw.Expanded(
              child: _buildTablaDetalleFactura(datos, boldFont, baseFont),
            ),
            pw.SizedBox(height: 10),

            // ── 4. RESUMEN DE TOTALES ─────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Caja Bancaria de Pago
                pw.Container(
                  width: 270,
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: _azulClaroFondo,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: _azulBorde, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DEPÓSITOS Y TRANSFERENCIAS (BCP):', style: pw.TextStyle(font: boldFont, fontSize: 7, color: _azulOscuro)),
                      pw.SizedBox(height: 2),
                      pw.Text('Cta. Cte: 215-7214815-0-34  |  CCI: 002-2150072148150342-4', style: pw.TextStyle(font: baseFont, fontSize: 6.5, color: _negro)),
                      pw.Text('Titular: NOVACONCRET S.A.C.', style: pw.TextStyle(font: boldFont, fontSize: 6.5, color: _azulOscuro)),
                    ],
                  ),
                ),

                // Caja de Totales Factura
                pw.Container(
                  width: 200,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(5),
                    border: pw.Border.all(color: _azulBorde, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      _buildFilaTotal('OP. GRAVADA:', 'S/ ${_numFormato(subtotal)}', boldFont, baseFont),
                      _buildFilaTotal('I.G.V. (18%):', 'S/ ${_numFormato(igv)}', boldFont, baseFont),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: const pw.BoxDecoration(
                          color: _azulOscuro,
                          borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('IMPORTE TOTAL:', style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: _blanco)),
                            pw.Text('S/ ${_numFormato(total)}', style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: _blanco)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── 5. PIE DE PÁGINA ──────────────────────────────
            _buildFooterBar(boldFont, baseFont, 'Representación impresa de la Factura Electrónica generada desde el Sistema ERP NOVACONCRET autorizado por SUNAT.'),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ═════════════════════════════════════════════════════════════
  // COMPONENTES COMPARTIDOS
  // ═════════════════════════════════════════════════════════════

  static pw.Widget _buildEncabezadoDoc({
    required pw.MemoryImage? logo,
    required String tituloDoc,
    required String subtituloDoc,
    required String serieCorrelativo,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Lado izquierdo: Logo + Datos Fiscales
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

        // Lado derecho: Tarjeta Oficial SUNAT
        pw.Container(
          width: 185,
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
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                color: _blanco,
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      tituloDoc,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: bold, fontSize: 9.5, color: _azulOscuro, letterSpacing: 0.3),
                    ),
                    if (subtituloDoc.isNotEmpty)
                      pw.Text(
                        subtituloDoc,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: bold, fontSize: 6.5, color: _azulPrimario),
                      ),
                  ],
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: _azulClaroFondo,
                  borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(4.5)),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  serieCorrelativo,
                  style: pw.TextStyle(font: bold, fontSize: 12, color: _azulPrimario),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBarraFechas(
    String emision,
    String traslado,
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
          _buildItemBarra('Fecha de Emisión:', emision, bold, regular),
          _buildItemBarra('Fecha de Traslado:', traslado, bold, regular),
          _buildItemBarra('Orden de Pedido:', opNro.isNotEmpty ? opNro : 'PROGRAMADO', bold, regular),
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
  // TABLA DETALLE GRE
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildTablaDetalleGRE(
    Map<String, dynamic> datos,
    String volStr,
    String pesoStr,
    pw.Font bold,
    pw.Font regular,
  ) {
    const colWidths = [
      pw.FlexColumnWidth(0.8), // ITEM
      pw.FlexColumnWidth(1.2), // CÓDIGO
      pw.FlexColumnWidth(4.5), // DESCRIPCIÓN TÉCNICA
      pw.FlexColumnWidth(1.0), // CANTIDAD
      pw.FlexColumnWidth(0.9), // UNIDAD
      pw.FlexColumnWidth(1.4), // PESO TOTAL
    ];

    final headers = ['ITEM', 'CÓDIGO', 'DESCRIPCIÓN DEL PRODUCTO', 'CANTIDAD', 'UNIDAD', 'PESO (KG)'];

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _azulBorde, width: 0.8),
      ),
      child: pw.Column(
        children: [
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
          pw.Expanded(
            child: pw.Container(
              color: _blanco,
              child: pw.Table(
                columnWidths: {for (int i = 0; i < colWidths.length; i++) i: colWidths[i]},
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('1', style: pw.TextStyle(font: bold, fontSize: 8, color: _azulOscuro)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text(datos['codigo_producto']?.toString() ?? 'PD00022', style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grisTexto)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: _buildDescripcionTecnicaGRE(datos, bold, regular),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text(volStr, style: pw.TextStyle(font: bold, fontSize: 9, color: _negro)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('M3', style: pw.TextStyle(font: regular, fontSize: 8, color: _grisTexto)),
                      ),
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
                pw.Text('CONCRETO PREMEZCLADO DESPACHADO EN MIXER', style: pw.TextStyle(font: regular, fontSize: 6.5, color: _grisTexto)),
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

  static pw.Widget _buildDescripcionTecnicaGRE(Map<String, dynamic> d, pw.Font bold, pw.Font regular) {
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
    final cemento = (d['cemento']?.toString() ?? 'CEMENTO YURA PRO').toUpperCase();

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
        if (bomba.isNotEmpty && bomba != '-') _buildBulletItem('SERVICIO: BOMBA $bomba', regular),
        if (hora.isNotEmpty) _buildBulletItem('HORA DE SALIDA: $hora', regular),
        if (precinto.isNotEmpty) _buildBulletItem('PRECINTO: $precinto', regular),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLA DETALLE FACTURA
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildTablaDetalleFactura(Map<String, dynamic> datos, pw.Font bold, pw.Font regular) {
    const colWidths = [
      pw.FlexColumnWidth(0.8), // ITEM
      pw.FlexColumnWidth(1.2), // CÓDIGO
      pw.FlexColumnWidth(4.5), // DESCRIPCIÓN
      pw.FlexColumnWidth(1.2), // CANTIDAD
      pw.FlexColumnWidth(1.0), // UNIDAD
      pw.FlexColumnWidth(1.5), // P. UNIT
      pw.FlexColumnWidth(1.5), // TOTAL
    ];

    final headers = ['ITEM', 'CÓDIGO', 'DESCRIPCIÓN', 'CANTIDAD', 'UNIDAD', 'P. UNIT (S/)', 'TOTAL (S/)'];
    final descripcion = (datos['descripcion']?.toString() ?? 'CONCRETO PREMEZCLADO').replaceAll('\\n', '\n');
    final volumen = datos['volumen']?.toString() ?? '0.00';
    final unitario = datos['unitario']?.toString() ?? '0.00';
    final totalItem = datos['total_item']?.toString() ?? '0.00';

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _azulBorde, width: 0.8),
      ),
      child: pw.Column(
        children: [
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
          pw.Expanded(
            child: pw.Container(
              color: _blanco,
              child: pw.Table(
                columnWidths: {for (int i = 0; i < colWidths.length; i++) i: colWidths[i]},
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('1', style: pw.TextStyle(font: bold, fontSize: 8, color: _azulOscuro)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('PD00022', style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grisTexto)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: pw.Text(
                          descripcion.toUpperCase(),
                          style: pw.TextStyle(font: bold, fontSize: 8, color: _negro),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text(volumen, style: pw.TextStyle(font: bold, fontSize: 8.5, color: _negro)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topCenter,
                        child: pw.Text('M3', style: pw.TextStyle(font: regular, fontSize: 8, color: _grisTexto)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        alignment: pw.Alignment.topRight,
                        child: pw.Text(unitario, style: pw.TextStyle(font: regular, fontSize: 8.5, color: _negro)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        alignment: pw.Alignment.topRight,
                        child: pw.Text(totalItem, style: pw.TextStyle(font: bold, fontSize: 8.5, color: _azulOscuro)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS AUXILIARES
  // ─────────────────────────────────────────────────────────────
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

  static pw.Widget _buildCheckOption(String label, bool checked, pw.Font bold, pw.Font regular) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 8.5,
          height: 8.5,
          decoration: pw.BoxDecoration(
            color: checked ? _azulPrimario : _blanco,
            borderRadius: pw.BorderRadius.circular(2),
            border: pw.Border.all(color: _azulPrimario, width: 1),
          ),
          alignment: pw.Alignment.center,
          child: checked
              ? _buildVectorCheckmark(color: _blanco, width: 5.5, height: 5.5, strokeWidth: 1.1)
              : null,
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 6.8, color: _negro)),
      ],
    );
  }

  static pw.Widget _buildMotivoItem(String texto, bool checked, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        children: [
          pw.Container(
            width: 7.5,
            height: 7.5,
            decoration: pw.BoxDecoration(
              color: checked ? _azulPrimario : _blanco,
              borderRadius: pw.BorderRadius.circular(1.5),
              border: pw.Border.all(color: _azulPrimario, width: 0.8),
            ),
            alignment: pw.Alignment.center,
            child: checked
                ? _buildVectorCheckmark(color: _blanco, width: 4.5, height: 4.5, strokeWidth: 1.0)
                : null,
          ),
          pw.SizedBox(width: 3.5),
          pw.Text(texto, style: pw.TextStyle(font: regular, fontSize: 6.3, color: checked ? _azulOscuro : _grisTexto)),
        ],
      ),
    );
  }

  static pw.Widget _buildVectorCheckmark({
    PdfColor color = _blanco,
    double width = 8,
    double height = 8,
    double strokeWidth = 1.3,
  }) {
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (canvas, size) {
        canvas.setColor(color);
        canvas.setLineWidth(strokeWidth);
        canvas.moveTo(size.x * 0.15, size.y * 0.45);
        canvas.lineTo(size.x * 0.42, size.y * 0.18);
        canvas.lineTo(size.x * 0.88, size.y * 0.82);
        canvas.strokePath();
      },
    );
  }

  static pw.Widget _buildFilaTotal(String label, String valor, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7.5, color: _grisTexto)),
          pw.Text(valor, style: pw.TextStyle(font: bold, fontSize: 8, color: _negro)),
        ],
      ),
    );
  }

  static pw.Widget _buildFirmaBox(String cargo, pw.Font bold, pw.Font regular) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        children: [
          pw.Container(height: 28),
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

  static pw.Widget _buildFooterBar(pw.Font bold, pw.Font regular, String notaLegal) {
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
                  pw.Text('PLANTA: $_plantaUchumayo', style: pw.TextStyle(font: bold, fontSize: 6.2, color: _blanco)),
                  pw.Text('OFICINA: $_domicilioFiscal', style: pw.TextStyle(font: regular, fontSize: 6.2, color: const PdfColor(0.85, 0.92, 1.0))),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Telf / Cel: $_telfEmpresa', style: pw.TextStyle(font: bold, fontSize: 6.5, color: _blanco)),
                  pw.Text(_emailEmpresa, style: pw.TextStyle(font: bold, fontSize: 6.5, color: const PdfColor(0.75, 0.9, 1.0))),
                  pw.Text('NOVACONCRET S.A.C. - RUC: $_rucEmpresa', style: pw.TextStyle(font: bold, fontSize: 6.2, color: _blanco)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            notaLegal,
            style: pw.TextStyle(font: regular, fontSize: 5.6, color: _grisMuted),
          ),
        ),
      ],
    );
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
