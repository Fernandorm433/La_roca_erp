// lib/core/utils/cotizacion_pdf_generator.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── Colores corporativos (Extraídos del diseño original) ────────────────────
const _verdeOscuro = PdfColor.fromInt(0xFF007000);// Verde de la cabecera y tablas
const _verdeTexto = PdfColor.fromInt(0xFF388E3C);  // Verde de "CONCRETOS ORION"
const _grisFondo = PdfColor.fromInt(0xFFF9F9F9);
const _grisLinea = PdfColor.fromInt(0xFFE0E0E0);
const _blanco = PdfColors.white;
const _negro = PdfColors.black;

// ─── Modelos de datos ────────────────────────────────────────────────────────

class ItemCotizacion {
  final String tipo;           
  final String descripcion;    
  final List<String> detalles; 
  final double cantidad;
  final String unidad;         
  final double precioUnitario;

  const ItemCotizacion({
    required this.tipo,
    required this.descripcion,
    required this.detalles,
    required this.cantidad,
    this.unidad = 'M³',
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;
}

class DatosCotizacion {
  final String numeroCotizacion; 
  final DateTime fecha;
  final DateTime? horaEntrega;   
  final String clienteNombre;
  final String clienteDocumento; 
  final String clienteDireccion;
  final String clienteTelefono;
  final String asesorNombre;
  final String asesorTelefono;
  final List<ItemCotizacion> items;
  final double igvPorcentaje;

  const DatosCotizacion({
    required this.numeroCotizacion,
    required this.fecha,
    this.horaEntrega,
    required this.clienteNombre,
    required this.clienteDocumento,
    required this.clienteDireccion,
    required this.clienteTelefono,
    required this.asesorNombre,
    required this.asesorTelefono,
    required this.items,
    this.igvPorcentaje = 18.0,
  });

  double get subTotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get igvMonto => subTotal * (igvPorcentaje / 100);
  double get total => subTotal + igvMonto;
}

// ─── Generador principal ─────────────────────────────────────────────────────

class CotizacionPdfGenerator {
  static Future<Uint8List> generar({
    required DatosCotizacion cotizacion,
  }) async {
    final pdf = pw.Document(
      title: cotizacion.numeroCotizacion,
      author: 'La Roca ERP',
    );

    pw.ImageProvider? logo;
    try {
      final data = await rootBundle.load('assets/images/LOGO2023.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    // Usamos Helvetica nativa para evitar bloqueos en Mac
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final theme = pw.ThemeData(
      defaultTextStyle: pw.TextStyle(font: baseFont, fontSize: 10, color: _negro),
    );

    // ── Página 1: Cotización ─────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (context) => [
          _buildTopSection(cotizacion, logo, boldFont, baseFont),
          pw.SizedBox(height: 16),
          _buildTablaItems(cotizacion, boldFont, baseFont),
          pw.SizedBox(height: 16),
          _buildTotales(cotizacion, boldFont, baseFont),
        ],
        footer: (context) => _buildFooter(cotizacion, boldFont, baseFont, context.pageNumber, context.pagesCount),
      ),
    );

    // ── Página 2: Condiciones de servicio (Estilo Cajas Original) ────────────
    // Cambiado de pw.Page a pw.MultiPage para soportar el parámetro footer
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (context) => [
          _buildCondicionesCajas(boldFont, baseFont),
        ],
        footer: (context) => _buildFooter(cotizacion, boldFont, baseFont, 2, 2),
      ),
    );

    return pdf.save();
  }

  // ─── Sección Superior (Logo, Cuadro Verde, Cliente, Empresa) ───────────────
  static pw.Widget _buildTopSection(DatosCotizacion cot, pw.ImageProvider? logo, pw.Font bold, pw.Font regular) {
    final fechaStr = DateFormat('dd/MM/yyyy').format(cot.fecha);
    final horaStr = cot.horaEntrega != null ? DateFormat('hh:mm a').format(cot.horaEntrega!) : '-';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ─── FILA 1: Logo y Cuadro Verde ─────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            if (logo != null)
              pw.Image(logo, width: 250, height: 110, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(width: 220, height: 100),
            
            // Cuadro Verde
            pw.Container(
              width: 170, 
              decoration: pw.BoxDecoration(
                color: _verdeOscuro,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 14), 
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(cot.numeroCotizacion, style: pw.TextStyle(font: bold, fontSize: 11, color: _blanco)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: pw.Divider(color: _blanco, thickness: 0.5),
                  ),
                  pw.Text(fechaStr, style: pw.TextStyle(font: bold, fontSize: 11, color: _blanco)),
                ],
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 25), // Espaciado entre la Fila 1 y Fila 2
        
        // ─── FILA 2: Datos Empresa y Datos Cliente ───────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // COLUMNA IZQUIERDA: Empresa
            pw.Expanded(
              flex: 10,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CONCRETOS ORION S.A.C.', style: pw.TextStyle(font: bold, fontSize: 13, color: _verdeTexto)),
                  pw.SizedBox(height: 4),
                  pw.Text('RUC: 20614288095', style: pw.TextStyle(font: bold, fontSize: 12, color: _verdeTexto)),
                  pw.SizedBox(height: 6),
                  pw.Text('- 914581410', style: pw.TextStyle(font: regular, fontSize: 12)),
                  pw.Text('- 931473002', style: pw.TextStyle(font: regular, fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('- laroca.pe', style: pw.TextStyle(font: regular, fontSize: 12)),
                  pw.Text('- ventas@laroca.pe', style: pw.TextStyle(font: regular, fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('- Planta: Vía Evitamiento Km. 4.2 Cerro Colorado', style: pw.TextStyle(font: regular, fontSize: 12)),
                ],
              ),
            ),
            
            pw.SizedBox(width: 20),

            // COLUMNA DERECHA: Cliente
            pw.Expanded(
              flex: 12,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 35), 
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, 
                  children: [
                    _buildFilaDato('Cliente:', cot.clienteNombre.replaceAll('³', '3'), bold, regular),
                    _buildFilaDato('Documento:', cot.clienteDocumento, bold, regular),
                    _buildFilaDato('Dirección:', cot.clienteDireccion.replaceAll('³', '3'), bold, regular),
                    _buildFilaDato('Teléfono:', cot.clienteTelefono, bold, regular),
                    pw.SizedBox(height: 6),
                    _buildFilaDato('Fecha:', fechaStr, bold, regular),
                    _buildFilaDato('Hora:', horaStr, bold, regular),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 70, child: pw.Text('Asesor:', style: pw.TextStyle(font: bold))),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(cot.asesorNombre, style: pw.TextStyle(font: bold)),
                              pw.Text(cot.asesorTelefono, style: pw.TextStyle(font: bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFilaDato(String label, String value, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 70, child: pw.Text(label, style: pw.TextStyle(font: bold))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: regular))),
        ],
      ),
    );
  }

  // ─── Tabla Principal ───────────────────────────────────────────────────────
  static pw.Widget _buildTablaItems(DatosCotizacion cot, pw.Font bold, pw.Font regular) {
    const colWidths = [
      pw.FlexColumnWidth(1.5), 
      pw.FlexColumnWidth(4.5), 
      pw.FlexColumnWidth(1.2), 
      pw.FlexColumnWidth(1.0), 
      pw.FlexColumnWidth(1.5), 
      pw.FlexColumnWidth(1.5), 
    ];

    final headers = ['Tipo', 'Descripción', 'Cantidad', 'Unidad', 'P. unit', 'Subtotal'];
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return pw.Table(
      columnWidths: {for (int i = 0; i < colWidths.length; i++) i: colWidths[i]},
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _grisLinea, width: 0.5),
        bottom: pw.BorderSide(color: _grisLinea, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _verdeOscuro),
          children: headers.map((h) {
            final isCenter = ['Tipo', 'Cantidad', 'Unidad'].contains(h);
            final isRight = ['P. unit', 'Subtotal'].contains(h);
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(
                h,
                textAlign: isRight ? pw.TextAlign.right : (isCenter ? pw.TextAlign.center : pw.TextAlign.left),
                style: pw.TextStyle(font: bold, fontSize: 10, color: _blanco),
              ),
            );
          }).toList(),
        ),
        ...cot.items.map((item) {
          final descripcionLimpia = item.descripcion.replaceAll('"', '"').replaceAll('"', '"');
          
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: pw.Text(item.tipo, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(descripcionLimpia, style: pw.TextStyle(font: bold, fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    ...item.detalles.map((d) {
                      final detalleLimpio = d.replaceAll('"', '"').replaceAll('"', '"');
                      return pw.Text(detalleLimpio, style: pw.TextStyle(font: regular, fontSize: 8));
                    }),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: pw.Text(item.cantidad.toStringAsFixed(1), textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: pw.Text(item.unidad, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: pw.Text(fmt.format(item.precioUnitario), textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: pw.Text(fmt.format(item.subtotal), textAlign: pw.TextAlign.right),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─── Totales ───────────────────────────────────────────────────────────────
  static pw.Widget _buildTotales(DatosCotizacion cot, pw.Font bold, pw.Font regular) {
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sub Total:', style: pw.TextStyle(font: regular, fontSize: 11)),
                  pw.Text('S/ ${fmt.format(cot.subTotal)}', style: pw.TextStyle(font: regular, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('IGV:', style: pw.TextStyle(font: regular, fontSize: 11)),
                  pw.Text('${cot.igvPorcentaje.toStringAsFixed(1)}%', style: pw.TextStyle(font: regular, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: _grisLinea, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total:', style: pw.TextStyle(font: bold, fontSize: 15, color: _verdeOscuro)),
                  pw.Text('S/ ${fmt.format(cot.total)}', style: pw.TextStyle(font: bold, fontSize: 15, color: _verdeOscuro)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Footer con QR ─────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(DatosCotizacion cot, pw.Font bold, pw.Font regular, int pagAct, int pagTot) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _grisLinea, thickness: 0.5),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CONCRETOS ORION S.A.C.', style: pw.TextStyle(font: bold, fontSize: 7)),
                pw.Text('RUC: 20614288095', style: pw.TextStyle(font: regular, fontSize: 7)),
                pw.Text('PLANTA: VIA DE EVITAMIENTO KM. 4.2 CERRO COLORADO', style: pw.TextStyle(font: regular, fontSize: 7)),
                pw.Text('ventas@laroca.pe | laroca.pe', style: pw.TextStyle(font: regular, fontSize: 7)),
              ],
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Text('Página $pagAct/$pagTot', style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey700)),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 50,
                  height: 50,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://laroca.pe/verificar/${cot.numeroCotizacion}',
                    drawText: false,
                    color: _negro,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Escanea para verificar', style: pw.TextStyle(font: regular, fontSize: 6, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ─── Página 2: Cajas de Condiciones ─────────────────────────────────────────
  static pw.Widget _buildCondicionesCajas(pw.Font bold, pw.Font regular) {
    
    pw.Widget construirCaja(String titulo, List<pw.Widget> contenido) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _verdeOscuro, width: 2),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: _verdeOscuro,
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text(
                titulo,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 10, color: _blanco),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              color: _blanco,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: contenido,
              ),
            ),
          ],
        ),
      );
    }

    final subtitleStyle = pw.TextStyle(font: bold, fontSize: 8);
    final bodyStyle = pw.TextStyle(font: regular, fontSize: 8);

    // Corregido el nombre de la función para que compile en Dart
    pw.Widget vineta(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: bodyStyle),
          pw.Expanded(child: pw.Text(text, style: bodyStyle)),
        ],
      ),
    );

    return pw.Column(
      children: [
        construirCaja(
          'CONDICIONES DE SERVICIO',
          [
            pw.Text('SERVICIO DE TRANSPORTE DE CONCRETO:', style: subtitleStyle),
            pw.SizedBox(height: 4),
            vineta('Contamos con camiones mixer con capacidad de hasta 12 m3.'),
            vineta('El volumen minimo de suministro de concreto por unidad es de 6 m3 diarios.'),
            vineta('Una vez que el camion mixer haya llegado a la obra e iniciado el vaciado, el tiempo maximo permitido para completar la descarga es de 1 hora. En caso de superar dicho tiempo, el cliente debera abonar un costo adicional de S/ 250.00 por hora excedida.'),
            pw.SizedBox(height: 8),
            pw.Text('SERVICIO DE BOMBEO:', style: subtitleStyle),
            pw.SizedBox(height: 4),
            vineta('Los precios cotizados para el servicio de bombeo aplican unicamente para volumenes mayores a 20 m3 diarios.'),
            vineta('En caso de requerirse el servicio de bombeo para volumenes menores a 20 m3 diarios, se aplicara un costo adicional por este servicio. El monto sera calculado sobre una base de S/. 750.00 y se ajustara de acuerdo con el volumen exacto solicitado.'),
            vineta('Si el volumen solicitado es menor a 5 m3 diarios, el costo total del servicio de bombeo sera de S/ 1,300.00.'),
            vineta('Una vez iniciado el bombeo, el proceso no debera prolongarse mas alla del tiempo indicado por el operador responsable, considerando que el concreto tiene un tiempo de vida util limitado para su vaciado. En caso de exceder este tiempo, el cliente debera abonar un costo adicional de S/ 250.00.'),
            vineta('El cliente debera proporcionar una bolsa de cemento al personal encargado de nuestros camiones bomba para la lubricacion de las tuberias.'),
            vineta('Asimismo, el cliente debe habilitar un lugar para la descarga del concreto residual proveniente de la batea al finalizar el bombeo.'),
          ],
        ),

        construirCaja(
          'CONDICIONES DE ATENCIÓN',
          [
            vineta('El area destinada para el ingreso de las unidades debera encontrarse habilitada, firme, sin inclinaciones y libre de elementos que representen riesgos, como fierros, materiales punzocortantes, monticulos de tierra u otros obstaculos que puedan comprometer la operacion del mixer o de la bomba de concreto.'),
            vineta('En caso de requerir el uso de bomba, el cliente debera proporcionar una bolsa de cemento para la lubricacion de las tuberias.'),
            vineta('Si se solicita solo diseño de mezcla, este tendra un costo adicional de S/ 150.00. El diseño sera entregado en un plazo de 3 dias calendario contados a partir de la solicitud y previo pago del importe correspondiente.'),
            vineta('Una vez que el mixer llegue a la obra, el inicio de vaciado no debe superar los 15 minutos, considerando que cada unidad cuenta con una programacion establecida y el concreto premezclado posee un tiempo de vida respectivo.'),
            vineta('Para cada atencion, el cliente debera efectuar el pago total del servicio de manera anticipada o, en su defecto, realizar un adelanto minimo del 50% a fin de garantizar la programacion del vaciado. El saldo restante (50%) debera cancelarse inmediatamente con la llegada de la primera maquinaria a obra.'),
            vineta('La empresa brindara un asesoramiento tecnico antes, durante y despues del vaciado, proporcionando soporte sobre los procedimientos constructivos y manteniendo comunicacion directa con los ingenieros, maestros o encargados de obra.'),
            vineta('No se realizan atenciones los dias sabados.'),
          ],
        ),

        construirCaja(
          'PROCEDIMIENTO DE ATENCIÓN',
          [
            pw.Text('Forma de pago al contado, en efectivo o con deposito a cuentas BCP y BBVA', style: bodyStyle),
            pw.SizedBox(height: 6),
            pw.Text('Pago a Cuenta Corriente BCP: CONCRETOS ORION S.A.C.', style: bodyStyle),
            vineta('N CTA. 2157214815034'),
            vineta('N CCI 00221500721481503424'),
            pw.SizedBox(height: 6),
            pw.Text('Pago a Cuenta Corriente BBVA: CONCRETOS ORION S.A.C.', style: bodyStyle),
            vineta('N CTA. 001102200100177397'),
            vineta('N CCI 01122000010017739715'),
            pw.SizedBox(height: 6),
            pw.Text('Enviar la foto del comprobante de pago por WHATSAPP al area de ventas 914581410, Sofia Romero; o por defecto, a su asesor comercial.', style: bodyStyle),
            pw.SizedBox(height: 2),
            pw.Text('Coordinar el dia y horario de atencion con su asesor comercial.', style: bodyStyle),
          ],
        ),
      ],
    );
  }
}