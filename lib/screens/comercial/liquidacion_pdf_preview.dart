import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class LiquidacionPdfPreview extends StatelessWidget {
  final Future<Uint8List> Function() generarPdf;

  const LiquidacionPdfPreview({super.key, required this.generarPdf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista Previa de Liquidación')),
      body: PdfPreview(
        build: (format) async => await generarPdf(),
      ),
    );
  }
}
