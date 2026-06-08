import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../core/utils/pdf_generator.dart';

class GuiaPdfPreview extends StatelessWidget {
  final Map<String, dynamic> venta;
  final Map<String, dynamic> carguio;

  const GuiaPdfPreview({super.key, required this.venta, required this.carguio});

  Future<Uint8List> _generatePdf() async {
    Map<String, dynamic> datos = {
      'vol_m3': double.tryParse(carguio['volumen']?.toString() ?? '0') ?? 0.0,
      'fecha': venta['fecha_entrega'] ?? '',
      'op_nro': venta['orden_pedido'] ?? '',
      'direccion_obra': venta['direccion'] ?? '',
      'cliente': venta['nombre_razon_social'] ?? '',
      'ruc_dni': venta['dni_ruc'] ?? venta['ruc'] ?? venta['dni'] ?? '',
      'conductor': carguio['operador_nombre'] ?? '',
      'marca_vehiculo': '', 
      'placa_vehiculo': carguio['codigo_mixer'] ?? '',
      'nro_guia': carguio['nro_guia'] ?? '',
      'diseno': venta['diseno'] ?? '',
      'slump': venta['slump'] ?? '',
      'huso': venta['huso'] ?? '',
      'aditivo': venta['aditivo'] ?? '',
      'bomba': venta['bomba'] ?? '',
      'hora_salida': carguio['hora_salida'] ?? '',
      'nro_precinto': carguio['precinto'] ?? '',
      'cemento': venta['tipo_cemento'] ?? '',
    };
    return await PdfGenerator.generarGuiaDespacho(datos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista Previa de Guía')),
      body: PdfPreview(
        build: (format) => _generatePdf(),
      ),
    );
  }
}
