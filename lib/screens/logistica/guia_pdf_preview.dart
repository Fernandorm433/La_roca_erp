import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/sunat_pdf_generator.dart';

class GuiaPdfPreview extends StatelessWidget {
  final Map<String, dynamic> venta;
  final Map<String, dynamic> carguio;

  const GuiaPdfPreview({super.key, required this.venta, required this.carguio});

  Future<Uint8List> _generatePdf() async {
    String tipoDoc = (venta['tipo_documento']?.toString() ?? '').toUpperCase();
    
    if (tipoDoc == 'FACTURA' || tipoDoc == 'BOLETA') {
      // Pasar datos individuales para que el generador arme la descripción
      final dataPDF = {
        'serie_correlativo': 'T001 - ${carguio['nro_guia'] ?? '00000000'}',
        'fecha_emision': (venta['fecha_entrega'] ?? '').toString().split(' ').first,
        'fecha_traslado': (venta['fecha_entrega'] ?? '').toString().split(' ').first,
        'op_nro': venta['orden_pedido'] ?? '',
        'domicilio_llegada': venta['direccion'] ?? 'Obra registrada',
        'cliente_nombre': venta['nombre_razon_social'] ?? '',
        'cliente_documento': venta['dni_ruc'] ?? venta['ruc'] ?? venta['dni'] ?? '',
        'conductor': carguio['operador_nombre'] ?? '',
        'licencia': carguio['licencia'] ?? '',
        'placa': carguio['codigo_mixer'] ?? '',
        'factura_ref': '',
        // Datos individuales para la descripción (igual que pdf_generator)
        'diseno': venta['diseno'] ?? '',
        'slump': venta['slump'] ?? '',
        'huso': venta['huso'] ?? '',
        'aditivo': venta['aditivo'] ?? '',
        'bomba': venta['bomba'] ?? '',
        'cemento': venta['tipo_cemento'] ?? '',
        'hora_salida': carguio['hora_salida'] ?? '',
        'precinto': carguio['precinto'] ?? '',
        'volumen': (double.tryParse(carguio['volumen']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2),
      };
      return await SunatPdfGenerator.generarGRE(dataPDF);
    }

    // Para RECIBO u otros, generamos la guía interna de siempre
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
        pdfFileName: 'Guia_${carguio['nro_guia'] ?? 'despacho'}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        build: (format) => _generatePdf(),
      ),
    );
  }
}
