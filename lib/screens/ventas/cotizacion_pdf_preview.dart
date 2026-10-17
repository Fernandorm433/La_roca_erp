import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/utils/cotizacion_pdf_generator.dart';

class CotizacionPdfPreview extends StatelessWidget {
  final DatosCotizacion cotizacion;

  const CotizacionPdfPreview({super.key, required this.cotizacion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista Previa de Cotización')),
      body: PdfPreview(
        pdfFileName: '${cotizacion.numeroCotizacion.replaceAll("/", "_")}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        build: (format) async {
          return await CotizacionPdfGenerator.generar(cotizacion: cotizacion);
        },
      ),
    );
  }
}
