// lib/core/utils/cotizacion_pdf_generator.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Función utilitaria para parsear detalles JSON o List<dynamic>
List<String> parseDetalles(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).toList();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).toList();
        }
      } catch (_) {}
    }
    if (trimmed.contains('\n')) {
      return trimmed.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [trimmed];
  }
  return [];
}

// ─── Colores corporativos NOVACONCRET (Diseño Elegante Azul/Celeste) ──────────
const _azulOscuro = PdfColor.fromInt(0xFF0C3866);     // Azul marino oscuro (títulos y footer)
const _azulPrimario = PdfColor.fromInt(0xFF0284C7);   // Celeste / Cyan vivo (cabeceras de cajas y tablas)
const _azulClaroFondo = PdfColor.fromInt(0xFFF0F9FF); // Fondo suave de tarjetas y tablas
const _azulBorde = PdfColor.fromInt(0xFFBAE6FD);      // Borde celeste pastel
const _azulResaltado = PdfColor.fromInt(0xFFE0F2FE);  // Fondo resaltado para Total y Pagos
const _grisTexto = PdfColor.fromInt(0xFF334155);      // Texto secundario
const _grisMuted = PdfColor.fromInt(0xFF64748B);      // Texto pequeño / notas
const _negro = PdfColor.fromInt(0xFF0F172A);          // Texto principal negro azulado
const _blanco = PdfColors.white;

// ─── Modelos de datos ────────────────────────────────────────────────────────

class ItemCotizacion {
  final String tipo;
  final String descripcion;
  final List<String> detalles;
  final double cantidad;
  final String unidad;
  final double precioUnitario;
  final double? precioTotal;

  const ItemCotizacion({
    required this.tipo,
    required this.descripcion,
    required this.detalles,
    required this.cantidad,
    this.unidad = 'M³',
    required this.precioUnitario,
    this.precioTotal,
  });

  double get subtotal => precioTotal ?? (cantidad * precioUnitario);
}

class DatosCotizacion {
  final String numeroCotizacion;
  final DateTime fecha;
  final DateTime? fechaVencimiento;
  final DateTime? horaEntrega;
  final String clienteNombre;
  final String clienteDocumento;
  final String clienteDireccion;
  final String clienteTelefono;
  final String asesorNombre;
  final String asesorTelefono;
  final String? contactoObra;
  final String? contactoTelefono;
  final String? tipoComprobante;
  final String? formaPago;
  final String? fechaVaciado;
  final String? elementoVaciar;
  final String? formaVaciado;
  final List<ItemCotizacion> items;
  final double igvPorcentaje;
  final double? subTotalCustom;
  final double? igvMontoCustom;
  final double? totalCustom;

  const DatosCotizacion({
    required this.numeroCotizacion,
    required this.fecha,
    this.fechaVencimiento,
    this.horaEntrega,
    required this.clienteNombre,
    required this.clienteDocumento,
    required this.clienteDireccion,
    required this.clienteTelefono,
    required this.asesorNombre,
    required this.asesorTelefono,
    this.contactoObra,
    this.contactoTelefono,
    this.tipoComprobante = 'Factura',
    this.formaPago = 'DEPÓSITO',
    this.fechaVaciado,
    this.elementoVaciar,
    this.formaVaciado,
    required this.items,
    this.igvPorcentaje = 18.0,
    this.subTotalCustom,
    this.igvMontoCustom,
    this.totalCustom,
  });

  double get subTotal => subTotalCustom ?? items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get igvMonto => igvMontoCustom ?? (subTotal * (igvPorcentaje / 100));
  double get total => totalCustom ?? (subTotal + igvMonto);
}

// ─── Generador principal ─────────────────────────────────────────────────────

class CotizacionPdfGenerator {
  static Future<Uint8List> generar({
    required DatosCotizacion cotizacion,
  }) async {
    final pdf = pw.Document(
      title: cotizacion.numeroCotizacion,
      author: 'ERP NOVACONCRET',
    );

    pw.ImageProvider? logo;
    try {
      final data = await rootBundle.load('assets/images/LOGO_NOVA.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final data2 = await rootBundle.load('assets/images/ICONO_NOVA.png');
        logo = pw.MemoryImage(data2.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }
    }

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final theme = pw.ThemeData(
      defaultTextStyle: pw.TextStyle(font: baseFont, fontSize: 9, color: _negro),
    );

    // ── Página 1: Cotización Formal ──────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 18),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildTopHeaderPage1(cotizacion, logo, boldFont, baseFont),
              pw.SizedBox(height: 10),
              _buildBoxesClienteYObra(cotizacion, boldFont, baseFont),
              pw.SizedBox(height: 10),
              _buildDetalleCotizacion(cotizacion, boldFont, baseFont),
              pw.SizedBox(height: 8),
              _buildDatosAdicionalesObra(cotizacion, boldFont, baseFont),
              pw.Spacer(),
              _buildFooterBar(boldFont, baseFont),
            ],
          );
        },
      ),
    );

    // ── Página 2: Condiciones y Procedimiento ────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 18),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildTopHeaderPage2(logo, boldFont, baseFont),
              pw.SizedBox(height: 10),
              _buildCondicionesYProcedimientoBody(boldFont, baseFont),
              pw.Spacer(),
              _buildFooterBar(boldFont, baseFont),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PÁGINA 1: COMPONENTES
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── Encabezado Página 1 ───────────────────────────────────────────────────
  static pw.Widget _buildTopHeaderPage1(
    DatosCotizacion cot,
    pw.ImageProvider? logo,
    pw.Font bold,
    pw.Font regular,
  ) {
    final fechaEmision = DateFormat('dd/MM/yyyy').format(cot.fecha);
    final fechaVenc = DateFormat('dd/MM/yyyy').format(
      cot.fechaVencimiento ?? cot.fecha.add(const Duration(days: 30)),
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo y Datos Corporativos Novacon
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Image(logo, height: 40, fit: pw.BoxFit.contain)
            else
              pw.Row(
                children: [
                  pw.Container(
                    width: 30,
                    height: 30,
                    decoration: pw.BoxDecoration(
                      color: _azulPrimario,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('N', style: pw.TextStyle(color: _blanco, font: bold, fontSize: 18)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'NOVACON',
                    style: pw.TextStyle(font: bold, fontSize: 20, color: _azulOscuro, letterSpacing: 1.2),
                  ),
                ],
              ),
            pw.SizedBox(height: 3),
            pw.Text(
              'NOVACONCRET S.A.C.  |  RUC: 20616487141',
              style: pw.TextStyle(font: bold, fontSize: 6.8, color: _azulOscuro),
            ),
            pw.Text(
              'Planta: VARIANTE UCHUMAYO - CERRO COLORADO - AREQUIPA - AREQUIPA',
              style: pw.TextStyle(font: regular, fontSize: 5.8, color: _grisTexto),
            ),
            pw.Text(
              'Oficina: AV. ATAHUALPA NRO. 204 URB. ALTO SELVA ALEGRE - AREQUIPA',
              style: pw.TextStyle(font: regular, fontSize: 5.8, color: _grisTexto),
            ),
            pw.Text(
              'Telf / Cel: +51 982 503 604  |  novaconcretsac@gmail.com',
              style: pw.TextStyle(font: bold, fontSize: 5.8, color: _azulPrimario),
            ),
          ],
        ),

        // Bloque de Título y Número de Cotización
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'COTIZACIÓN',
              style: pw.TextStyle(font: bold, fontSize: 18, color: _azulOscuro, letterSpacing: 0.5),
            ),
            pw.SizedBox(height: 3),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'NRO. COTIZACION: ',
                    style: pw.TextStyle(font: bold, fontSize: 8.5, color: _negro),
                  ),
                  pw.TextSpan(
                    text: cot.numeroCotizacion,
                    style: pw.TextStyle(font: bold, fontSize: 8.5, color: _azulPrimario),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Fecha de Emisión: ',
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _grisTexto),
                  ),
                  pw.TextSpan(
                    text: fechaEmision,
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _negro),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Fecha de Vencimiento: ',
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _grisTexto),
                  ),
                  pw.TextSpan(
                    text: fechaVenc,
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _negro),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Cajas de Datos de Cliente y Datos de Obra ─────────────────────────────
  static pw.Widget _buildBoxesClienteYObra(
    DatosCotizacion cot,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── CAJA 1: DATOS DE CLIENTE ──
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: const pw.BoxDecoration(
                  color: _azulPrimario,
                  borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                ),
                child: pw.Text(
                  'DATOS DE CLIENTE:',
                  style: pw.TextStyle(font: bold, fontSize: 8.5, color: _blanco, letterSpacing: 0.3),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: _blanco,
                  borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5)),
                  border: pw.Border.all(color: _azulBorde, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildFilaInfo('Cliente:', cot.clienteNombre.toUpperCase(), bold, regular),
                    _buildFilaInfo('RUC/DNI:', cot.clienteDocumento.isNotEmpty ? cot.clienteDocumento : 'S/D', bold, regular),
                    _buildFilaInfo('N° Telf:', cot.clienteTelefono.isNotEmpty ? cot.clienteTelefono : '-', bold, regular),
                    _buildFilaInfo('Dirección:', cot.clienteDireccion.isNotEmpty ? cot.clienteDireccion : '-', bold, regular),
                    _buildFilaInfo('Comprobante:', cot.tipoComprobante ?? 'Factura', bold, regular),
                    _buildFormaPagoWidget(cot.formaPago ?? 'DEPÓSITO', bold, regular),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 12),

        // ── CAJA 2: DATOS DE OBRA ──
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: const pw.BoxDecoration(
                  color: _azulPrimario,
                  borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                ),
                child: pw.Text(
                  'DATOS DE OBRA:',
                  style: pw.TextStyle(font: bold, fontSize: 8.5, color: _blanco, letterSpacing: 0.3),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: _blanco,
                  borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5)),
                  border: pw.Border.all(color: _azulBorde, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildFilaInfo(
                      'Contacto en obra:',
                      (cot.contactoObra != null && cot.contactoObra!.isNotEmpty)
                          ? cot.contactoObra!.toUpperCase()
                          : '-',
                      bold,
                      regular,
                    ),
                    _buildFilaInfo(
                      'N° Telf contacto:',
                      (cot.contactoTelefono != null && cot.contactoTelefono!.isNotEmpty)
                          ? cot.contactoTelefono!
                          : (cot.clienteTelefono.isNotEmpty ? cot.clienteTelefono : '-'),
                      bold,
                      regular,
                    ),
                    _buildFilaInfo(
                      'Asesor Comercial:',
                      cot.asesorNombre.isNotEmpty ? cot.asesorNombre.toUpperCase() : 'ADMINISTRADOR',
                      bold,
                      regular,
                    ),
                    if (cot.asesorTelefono.isNotEmpty)
                      _buildFilaInfo('Telf Asesor:', cot.asesorTelefono, bold, regular)
                    else
                      pw.SizedBox(height: 12),
                    pw.SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFilaInfo(String label, String valor, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7.5, color: _negro)),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grisTexto),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
          ),
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
        // Coordenadas PDF (0,0 es esquina inferior izquierda)
        canvas.moveTo(size.x * 0.15, size.y * 0.45);
        canvas.lineTo(size.x * 0.42, size.y * 0.18);
        canvas.lineTo(size.x * 0.88, size.y * 0.82);
        canvas.strokePath();
      },
    );
  }

  static pw.Widget _buildFormaPagoWidget(String forma, pw.Font bold, pw.Font regular) {
    final isDeposito = forma.toUpperCase().contains('DEP') || forma.isEmpty;
    final isContado = forma.toUpperCase().contains('CONT');

    pw.Widget checkItem(bool marcado, String label) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 8.5,
            height: 8.5,
            decoration: pw.BoxDecoration(
              color: marcado ? _azulPrimario : _blanco,
              borderRadius: pw.BorderRadius.circular(2),
              border: pw.Border.all(color: _azulPrimario, width: 1),
            ),
            alignment: pw.Alignment.center,
            child: marcado
                ? _buildVectorCheckmark(color: _blanco, width: 5.5, height: 5.5, strokeWidth: 1.1)
                : null,
          ),
          pw.SizedBox(width: 3.5),
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 7, color: _grisTexto)),
        ],
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text('Forma de Pago:', style: pw.TextStyle(font: bold, fontSize: 7.5, color: _negro)),
          ),
          checkItem(isDeposito, 'DEPÓSITO'),
          pw.SizedBox(width: 8),
          checkItem(isContado, 'CONTADO'),
        ],
      ),
    );
  }

  // ─── Tabla Detalle de Cotización ───────────────────────────────────────────
  static pw.Widget _buildDetalleCotizacion(
    DatosCotizacion cot,
    pw.Font bold,
    pw.Font regular,
  ) {
    final fmt = NumberFormat('#,##0.00', 'en_US');

    const colWidths = [
      pw.FlexColumnWidth(0.7), // Item
      pw.FlexColumnWidth(4.8), // Descripción
      pw.FlexColumnWidth(1.1), // Cantidad
      pw.FlexColumnWidth(1.0), // Unidad
      pw.FlexColumnWidth(1.8), // Precio Unitario
      pw.FlexColumnWidth(1.8), // Precio Total
    ];

    final headers = [
      'Item',
      'Descripción',
      'Cantidad',
      'Unidad',
      'Precio Unitario\n(Incluye IGV)',
      'Precio Total\n(Incluye IGV)',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Barra Superior Azul Marina
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: const pw.BoxDecoration(
            color: _azulOscuro,
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
          ),
          child: pw.Text(
            'DETALLE DE COTIZACIÓN',
            style: pw.TextStyle(font: bold, fontSize: 8.5, color: _blanco, letterSpacing: 0.4),
          ),
        ),

        // Tabla con columnas
        pw.Table(
          columnWidths: {for (int i = 0; i < colWidths.length; i++) i: colWidths[i]},
          border: const pw.TableBorder(
            left: pw.BorderSide(color: _azulBorde, width: 1),
            right: pw.BorderSide(color: _azulBorde, width: 1),
            bottom: pw.BorderSide(color: _azulBorde, width: 1),
            horizontalInside: pw.BorderSide(color: _azulBorde, width: 0.6),
          ),
          children: [
            // Cabecera Celeste/Azul
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _azulPrimario),
              children: headers.map((h) {
                final isCenter = ['Item', 'Cantidad', 'Unidad'].contains(h);
                final isRight = h.contains('Precio');
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  alignment: isRight
                      ? pw.Alignment.centerRight
                      : (isCenter ? pw.Alignment.center : pw.Alignment.centerLeft),
                  child: pw.Text(
                    h,
                    textAlign: isRight
                        ? pw.TextAlign.right
                        : (isCenter ? pw.TextAlign.center : pw.TextAlign.left),
                    style: pw.TextStyle(font: bold, fontSize: 7.2, color: _blanco),
                  ),
                );
              }).toList(),
            ),

            // Filas de Items
            ...cot.items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final isPar = entry.key % 2 == 1;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isPar ? _azulClaroFondo : _blanco,
                ),
                children: [
                  // Item N°
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    alignment: pw.Alignment.center,
                    child: pw.Text('$idx', style: pw.TextStyle(font: bold, fontSize: 7.5, color: _negro)),
                  ),

                  // Descripción y Viñetas de Detalle
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.descripcion.toUpperCase(),
                          style: pw.TextStyle(font: bold, fontSize: 7.8, color: _negro),
                        ),
                        if (item.detalles.isNotEmpty) ...[
                          pw.SizedBox(height: 2.5),
                          ...item.detalles.map(
                            (d) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 1.5, left: 4),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Container(
                                    width: 3.5,
                                    height: 3.5,
                                    margin: const pw.EdgeInsets.only(top: 2.8, right: 4),
                                    decoration: const pw.BoxDecoration(
                                      color: _azulPrimario,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      d.toUpperCase(),
                                      style: pw.TextStyle(font: regular, fontSize: 6.8, color: _grisTexto),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Cantidad
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      item.cantidad % 1 == 0 ? item.cantidad.toInt().toString() : item.cantidad.toStringAsFixed(1),
                      style: pw.TextStyle(font: bold, fontSize: 7.5, color: _negro),
                    ),
                  ),

                  // Unidad
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      item.unidad.toUpperCase().replaceAll('³', '3'),
                      style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grisTexto),
                    ),
                  ),

                  // P. Unitario
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'S/ ${fmt.format(item.precioUnitario)}',
                      style: pw.TextStyle(font: regular, fontSize: 7.5, color: _negro),
                    ),
                  ),

                  // Subtotal
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'S/ ${fmt.format(item.subtotal)}',
                      style: pw.TextStyle(font: bold, fontSize: 7.5, color: _negro),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),

        // Bloque de Totales alineado a la derecha
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 190,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Column(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Sub Total:', style: pw.TextStyle(font: bold, fontSize: 8, color: _grisTexto)),
                      pw.Text('S/ ${fmt.format(cot.subTotal)}', style: pw.TextStyle(font: bold, fontSize: 8, color: _negro)),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'IGV (${cot.igvPorcentaje.toStringAsFixed(0)}%):',
                        style: pw.TextStyle(font: bold, fontSize: 8, color: _grisTexto),
                      ),
                      pw.Text('S/ ${fmt.format(cot.igvMonto)}', style: pw.TextStyle(font: bold, fontSize: 8, color: _negro)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),
                // Caja destacada de TOTAL
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: pw.BoxDecoration(
                    color: _azulResaltado,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: _azulBorde, width: 1),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total:', style: pw.TextStyle(font: bold, fontSize: 9.5, color: _azulOscuro)),
                      pw.Text('S/ ${fmt.format(cot.total)}', style: pw.TextStyle(font: bold, fontSize: 9.5, color: _azulOscuro)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Caja de Datos Adicionales de Obra ──────────────────────────────────────
  static pw.Widget _buildDatosAdicionalesObra(
    DatosCotizacion cot,
    pw.Font bold,
    pw.Font regular,
  ) {
    String fechaVac = cot.fechaVaciado ?? '';
    if (fechaVac.isEmpty && cot.horaEntrega != null) {
      fechaVac = DateFormat('dd/MM/yyyy hh:mm a').format(cot.horaEntrega!);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: const pw.BoxDecoration(
            color: _azulPrimario,
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
          ),
          child: pw.Text(
            'DATOS ADICIONALES DE OBRA',
            style: pw.TextStyle(font: bold, fontSize: 8.5, color: _blanco, letterSpacing: 0.3),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: pw.BoxDecoration(
            color: _blanco,
            borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5)),
            border: pw.Border.all(color: _azulBorde, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildCampoSubrayado('Fecha de Vaciado:', fechaVac, bold, regular),
              pw.SizedBox(height: 3.5),
              _buildCampoSubrayado('Elemento a Vaciar:', cot.elementoVaciar ?? '', bold, regular),
              pw.SizedBox(height: 3.5),
              _buildCampoSubrayado('Forma de Vaciado:', cot.formaVaciado ?? '', bold, regular),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCampoSubrayado(
    String label,
    String valor,
    pw.Font bold,
    pw.Font regular,
  ) {
    final tieneValor = valor.trim().isNotEmpty;

    return pw.Row(
      children: [
        pw.SizedBox(
          width: 105,
          child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7.5, color: _negro)),
        ),
        pw.Expanded(
          child: tieneValor
              ? pw.Text(valor.toUpperCase(), style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grisTexto))
              : pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _azulBorde, width: 0.8),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PÁGINA 2: CONDICIONES Y PROCEDIMIENTO
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildTopHeaderPage2(
    pw.ImageProvider? logo,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Image(logo, height: 44, fit: pw.BoxFit.contain)
            else
              pw.Text(
                'NOVACON',
                style: pw.TextStyle(font: bold, fontSize: 22, color: _azulOscuro, letterSpacing: 1.2),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'CONDICIONES Y PROCEDIMIENTO',
                  style: pw.TextStyle(font: bold, fontSize: 16, color: _azulOscuro, letterSpacing: 0.5),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Atención: +51 982 503 604  |  novaconcretsac@gmail.com',
                  style: pw.TextStyle(font: bold, fontSize: 6.8, color: _azulPrimario),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 2.5,
          decoration: const pw.BoxDecoration(
            color: _azulPrimario,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(1)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCondicionesYProcedimientoBody(pw.Font bold, pw.Font regular) {
    return pw.Column(
      children: [
        // ── FILA SUPERIOR: VENTAJAS Y BENEFICIOS vs CONDICIONES DEL SERVICIO ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Caja 1: Ventajas y Beneficios
            pw.Expanded(
              flex: 1,
              child: _buildTarjetaCondicion(
                titulo: 'VENTAJAS Y BENEFICIOS',
                bold: bold,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildBeneficioItem(
                      'Asesoría técnica integral y permanente durante el proyecto.',
                      bold,
                      regular,
                    ),
                    _buildBeneficioItem(
                      'Control estricto de calidad con probetas y ensayos ASTM.',
                      bold,
                      regular,
                    ),
                    _buildBeneficioItem(
                      'Puntualidad en entrega con moderna flota mixer monitoreada por GPS.',
                      bold,
                      regular,
                    ),
                    _buildBeneficioItem(
                      'Equipos de bombeo de alto rendimiento y operadores calificados.',
                      bold,
                      regular,
                    ),
                    _buildBeneficioItem(
                      'Dosificación automatizada para mezclas exactas y homogéneas.',
                      bold,
                      regular,
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 12),

            // Caja 2: Condiciones del Servicio
            pw.Expanded(
              flex: 1,
              child: _buildTarjetaCondicion(
                titulo: 'CONDICIONES DEL SERVICIO',
                bold: bold,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPuntoNumerado('1.', 'Suministro con resistencia garantizada a los 28 días.', regular),
                    _buildPuntoNumerado('2.', 'Servicio de Bombeo: acceso y despeje garantizado por el cliente.', regular),
                    _buildPuntoNumerado('3.', 'Programación de vaciado con anticipación mínima de 24 horas.', regular),
                    _buildPuntoNumerado('4.', 'Tolerancia en obra: 30 min por mixer (exceso: S/ 250.00/h).', regular),
                    _buildPuntoNumerado('5.', 'Volumen mínimo por mixer: 6 m³ (menor volumen aplica falso flete).', regular),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // ── FILA INTERMEDIA: CONDICIONES DE ATENCIÓN vs PROCEDIMIENTO DE ATENCIÓN ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Caja 3: Condiciones de Atención
            pw.Expanded(
              flex: 1,
              child: _buildTarjetaCondicion(
                titulo: 'CONDICIONES DE ATENCIÓN',
                bold: bold,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPuntoNumerado('1.', 'Accesos a obra firmes y seguros para unidades de hasta 32 tn.', regular),
                    _buildPuntoNumerado('2.', 'Prohibida la adición de agua en obra sin autorización de Calidad.', regular),
                    _buildPuntoNumerado('3.', 'Para servicio de bomba, proveer 1 bolsa de cemento p/ lubricar.', regular),
                    _buildPuntoNumerado('4.', 'Cancelaciones deben comunicarse con un mínimo de 12 horas antes.', regular),
                    _buildPuntoNumerado('5.', 'Toma de probetas por personal capacitado bajo norma NTP 339.033.', regular),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 12),

            // Caja 4: Procedimiento de Atención
            pw.Expanded(
              flex: 1,
              child: _buildTarjetaCondicion(
                titulo: 'PROCEDIMIENTO DE ATENCIÓN',
                bold: bold,
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        _buildStepBadge('1', 'Paso 1: Pago', 'Depósito o crédito acordado', bold, regular),
                        pw.SizedBox(width: 6),
                        _buildStepBadge('2', 'Paso 2: Confirmar Pago', 'Envío de voucher a ventas', bold, regular),
                      ],
                    ),
                    pw.SizedBox(height: 7),
                    pw.Row(
                      children: [
                        _buildStepBadge('3', 'Paso 3: Coordinar', 'Reserva de fecha y turno', bold, regular),
                        pw.SizedBox(width: 6),
                        _buildStepBadge('4', 'Paso 4: Atención', 'Despacho, slump y vaciado', bold, regular),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // ── FILA INFERIOR: FIRMA Y ACEPTACIÓN vs DATOS DE PAGO BCP ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Caja 5: Firma y Aceptación
            pw.Expanded(
              flex: 1,
              child: _buildTarjetaCondicion(
                titulo: 'FIRMA Y ACEPTACIÓN',
                bold: bold,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.Text('Firma del Cliente: ', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _negro)),
                        pw.Expanded(
                          child: pw.Container(
                            margin: const pw.EdgeInsets.only(top: 8),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: _grisMuted, width: 0.8)),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text('Fecha: ', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _negro)),
                        pw.Container(
                          width: 45,
                          margin: const pw.EdgeInsets.only(top: 8),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: _grisMuted, width: 0.8)),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'NOVACONCRET S.A.C. | RUC: 20616487141',
                            style: pw.TextStyle(font: bold, fontSize: 7.2, color: _azulOscuro),
                          ),
                          pw.Text(
                            'Av. Atahualpa Nro. 204 Urb. Alto Selva Alegre, Arequipa',
                            style: pw.TextStyle(font: regular, fontSize: 5.8, color: _grisMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 12),

            // Caja 6: Datos de Pago BCP
            pw.Expanded(
              flex: 1,
              child: _buildTarjetaCondicion(
                titulo: 'DATOS DE PAGO BCP',
                bold: bold,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    color: _azulResaltado,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Cuenta Corriente BCP:', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _negro)),
                          pw.Text('215-7214815-0-34', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _azulOscuro)),
                        ],
                      ),
                      pw.SizedBox(height: 2.5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('CCI BCP:', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _negro)),
                          pw.Text('002-2150072148150342-4', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _azulOscuro)),
                        ],
                      ),
                      pw.SizedBox(height: 2.5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Titular:', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _negro)),
                          pw.Text('NOVACONCRET S.A.C.', style: pw.TextStyle(font: bold, fontSize: 7.2, color: _azulOscuro)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTarjetaCondicion({
    required String titulo,
    required pw.Widget child,
    required pw.Font bold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(
            color: _azulPrimario,
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
          ),
          child: pw.Text(
            titulo,
            style: pw.TextStyle(font: bold, fontSize: 8, color: _blanco, letterSpacing: 0.3),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            color: _blanco,
            borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5)),
            border: pw.Border.all(color: _azulBorde, width: 1),
          ),
          child: child,
        ),
      ],
    );
  }

  static pw.Widget _buildBeneficioItem(String texto, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 9,
            height: 9,
            margin: const pw.EdgeInsets.only(top: 1.5, right: 4.5),
            decoration: const pw.BoxDecoration(
              color: _azulPrimario,
              shape: pw.BoxShape.circle,
            ),
            alignment: pw.Alignment.center,
            child: _buildVectorCheckmark(color: _blanco, width: 5.5, height: 5.5, strokeWidth: 1.1),
          ),
          pw.Expanded(
            child: pw.Text(texto, style: pw.TextStyle(font: regular, fontSize: 6.8, color: _grisTexto)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPuntoNumerado(String num, String texto, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 12,
            child: pw.Text(num, style: pw.TextStyle(font: regular, fontSize: 6.8, color: _azulPrimario)),
          ),
          pw.Expanded(
            child: pw.Text(texto, style: pw.TextStyle(font: regular, fontSize: 6.8, color: _grisTexto)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStepBadge(
    String num,
    String titulo,
    String subtitulo,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _azulClaroFondo,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _azulBorde, width: 0.8),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 14,
              height: 14,
              decoration: const pw.BoxDecoration(
                color: _azulOscuro,
                shape: pw.BoxShape.circle,
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(num, style: pw.TextStyle(font: bold, fontSize: 7, color: _blanco)),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(titulo, style: pw.TextStyle(font: bold, fontSize: 6.8, color: _negro)),
                  pw.Text(subtitulo, style: pw.TextStyle(font: regular, fontSize: 5.5, color: _grisMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOOTER CORPORATIVO (AMBAS PÁGINAS)
  // ═══════════════════════════════════════════════════════════════════════════

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
                    'PLANTA: VARIANTE UCHUMAYO - CERRO COLORADO - AREQUIPA - AREQUIPA',
                    style: pw.TextStyle(font: bold, fontSize: 6.2, color: _blanco),
                  ),
                  pw.Text(
                    'OFICINA: AV. ATAHUALPA NRO. 204 URB. ALTO SELVA ALEGRE - AREQUIPA',
                    style: pw.TextStyle(font: regular, fontSize: 6.2, color: const PdfColor(0.85, 0.92, 1.0)),
                  ),
                ],
              ),
              pw.SizedBox(height: 2.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Telf / Cel: +51 982 503 604',
                    style: pw.TextStyle(font: bold, fontSize: 6.8, color: _blanco),
                  ),
                  pw.Text(
                    'novaconcretsac@gmail.com',
                    style: pw.TextStyle(font: bold, fontSize: 6.8, color: const PdfColor(0.75, 0.9, 1.0)),
                  ),
                  pw.Text(
                    'NOVACONCRET S.A.C. - RUC: 20616487141',
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
            'Este documento no debe ser alterado ni modificado sin consentimiento previo de NOVACONCRET S.A.C.',
            style: pw.TextStyle(font: regular, fontSize: 5.6, color: _grisMuted),
          ),
        ),
      ],
    );
  }
}