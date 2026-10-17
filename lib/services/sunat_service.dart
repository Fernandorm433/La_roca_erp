import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SunatService {
  final _supabase = Supabase.instance.client;

  // ─── CONFIGURACIÓN DE APISUNAT (PRODUCCIÓN NOVACONCRET S.A.C.) ────────
  static const String baseUrl = 'https://back.apisunat.com';
  static const String personaId = '6ac039056db37e0021e9abed';
  static const String personaToken = 'PRD_d3VmlCGcXzOuNtqIK0F391q0bxROJqVe1cBa7XfCITh7yi5AWvWAZ4Bgud352Y8t';
  static const String rucEmisor = '20616487141';
  static const String razonSocialEmisor = 'NOVACONCRET S.A.C.';
  static const String direccionEmisor = 'AV. ATAHUALPA NRO. 204 URB. ALTO SELVA ALEGRE AREQUIPA';

  // ────────────────────────────────────────────────────────────────────────
  // 1. OBTENER PRÓXIMO CORRELATIVO DESDE APISUNAT
  // ────────────────────────────────────────────────────────────────────────
  Future<int> obtenerSiguienteCorrelativo({
    required String tipoDoc, // '01' Factura, '03' Boleta, '09' Guía
    required String serie,   // 'F001', 'B001', 'T001'
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/personas/lastDocument'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'personaId': personaId,
          'personaToken': personaToken,
          'type': tipoDoc,
          'serie': serie,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final suggested = data['suggestedNumber']?.toString() ?? '1';
        return int.tryParse(suggested) ?? 1;
      }
    } catch (e) {
      debugPrint('Error al consultar correlativo en APISUNAT: $e');
    }

    // Fallback: consultar el correlativo más alto registrado en la base de datos local
    try {
      final tabla = (tipoDoc == '09') ? 'guias_remision' : 'facturacion_sunat';
      final rows = await _supabase
          .from(tabla)
          .select('correlativo')
          .eq('serie', serie)
          .order('correlativo', ascending: false)
          .limit(1);

      if (rows.isNotEmpty && rows.first['correlativo'] != null) {
        return (rows.first['correlativo'] as int) + 1;
      }
    } catch (e) {
      debugPrint('Error en fallback de correlativo: $e');
    }

    return 1;
  }

  // ────────────────────────────────────────────────────────────────────────
  // 2. ETAPA 1: REGISTRAR COMPROBANTE LOCALMENTE (PENDIENTE DE ENVÍO)
  // ────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> registrarFacturaLocal({
    required String cotizacionId,
    required String tipoDoc, // '01' o '03'
    required String serie,
    required int correlativo,
    required double montoTotal,
    bool anticipada = false,
  }) async {
    try {
      // Verificar si ya existe registro para esta cotización
      final existentes = await _supabase
          .from('facturacion_sunat')
          .select()
          .eq('cotizacion_id', cotizacionId)
          .eq('serie', serie)
          .eq('correlativo', correlativo)
          .maybeSingle();

      if (existentes != null) {
        return existentes;
      }

      final insertData = {
        'cotizacion_id': cotizacionId,
        'tipo_comprobante': tipoDoc,
        'serie': serie,
        'correlativo': correlativo,
        'monto_total': montoTotal,
        'anticipada': anticipada,
        'estado_sunat': 'PENDIENTE',
        'mensaje_sunat': 'Pendiente de envío a SUNAT',
      };

      final res = await _supabase
          .from('facturacion_sunat')
          .insert(insertData)
          .select()
          .single();

      // Actualizar estado en la cotización
      await _supabase.from('cotizaciones').update({
        'estado_facturacion': anticipada ? 'POR_FACTURAR_ANTICIPADO' : 'POR_FACTURAR',
      }).eq('id', cotizacionId);

      return res;
    } catch (e) {
      debugPrint('Error registrando factura local: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 3. ETAPA 2: ENVIAR FACTURA / BOLETA A SUNAT (AL CIERRE O A DEMANDA)
  // ────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> enviarFacturaASunat(String facturaId) async {
    try {
      // 1. Obtener datos completos de la factura y de la cotización
      final factura = await _supabase
          .from('facturacion_sunat')
          .select()
          .eq('id', facturaId)
          .single();

      final cotizacionId = factura['cotizacion_id'];
      Map<String, dynamic> cotizacion = {};
      List<dynamic> items = [];

      if (cotizacionId != null) {
        cotizacion = await _supabase
            .from('cotizaciones')
            .select()
            .eq('id', cotizacionId)
            .single();

        items = await _supabase
            .from('cotizacion_items')
            .select()
            .eq('cotizacion_id', cotizacionId);
      }

      final tipoDoc = factura['tipo_comprobante'] ?? '01';
      final serie = factura['serie'] ?? 'F001';
      final correlativo = factura['correlativo'] as int;
      final correlativoStr = correlativo.toString().padLeft(8, '0');
      final fileName = '$rucEmisor-$tipoDoc-$serie-$correlativoStr';

      final total = (factura['monto_total'] ?? cotizacion['total'] ?? 0.0).toDouble();
      final subtotal = (total / 1.18);
      final igv = total - subtotal;

      final clienteDoc = cotizacion['cliente_documento']?.toString().trim() ?? '20000000001';
      final clienteNombre = cotizacion['cliente_nombre'] ?? 'CLIENTE GENERAL';
      final clienteDireccion = cotizacion['cliente_direccion'] ?? cotizacion['obra_direccion'] ?? 'AREQUIPA';
      final tipoDocCliente = (clienteDoc.length == 11) ? '6' : '1';

      // Construcción de detalles de los ítems
      List<Map<String, dynamic>> details = [];
      if (items.isNotEmpty) {
        for (var item in items) {
          final cant = ((item['cantidad'] ?? 1.0) as num).toDouble();
          final precioUnitConIgv = ((item['precio_unitario'] ?? 0.0) as num).toDouble();
          final valorUnitSinIgv = precioUnitConIgv / 1.18;
          final totalItemSinIgv = valorUnitSinIgv * cant;
          final igvItem = totalItemSinIgv * 0.18;

          details.add({
            'codProducto': (item['codigo'] ?? 'CONC01').toString(),
            'unidad': 'MTQ', // Metros cúbicos
            'cantidad': cant,
            'mtoValorUnitario': double.parse(valorUnitSinIgv.toStringAsFixed(2)),
            'descripcion': (item['descripcion'] ?? 'CONCRETO PREMEZCLADO').toString(),
            'mtoBaseIgv': double.parse(totalItemSinIgv.toStringAsFixed(2)),
            'porcentajeIgv': 18,
            'igv': double.parse(igvItem.toStringAsFixed(2)),
            'tipAfeIgv': '10', // Gravado - Operación Onerosa
            'totalImpuestos': double.parse(igvItem.toStringAsFixed(2)),
            'mtoValorVenta': double.parse(totalItemSinIgv.toStringAsFixed(2)),
            'mtoPrecioUnitario': double.parse(precioUnitConIgv.toStringAsFixed(2)),
          });
        }
      } else {
        // Ítem por defecto si no hay desglose
        details.add({
          'codProducto': 'CONC01',
          'unidad': 'MTQ',
          'cantidad': 1,
          'mtoValorUnitario': double.parse(subtotal.toStringAsFixed(2)),
          'descripcion': 'CONCRETO PREMEZCLADO Y SERVICIOS',
          'mtoBaseIgv': double.parse(subtotal.toStringAsFixed(2)),
          'porcentajeIgv': 18,
          'igv': double.parse(igv.toStringAsFixed(2)),
          'tipAfeIgv': '10',
          'totalImpuestos': double.parse(igv.toStringAsFixed(2)),
          'mtoValorVenta': double.parse(subtotal.toStringAsFixed(2)),
          'mtoPrecioUnitario': double.parse(total.toStringAsFixed(2)),
        });
      }

      final fechaEmision = DateTime.now().toIso8601String().split('T').first;

      // 2. Estructura oficial del sendBill para APISUNAT
      final payload = {
        'personaId': personaId,
        'personaToken': personaToken,
        'fileName': fileName,
        'documentBody': {
          'ublVersion': '2.1',
          'tipoOperacion': '0101', // Venta interna
          'tipoDoc': tipoDoc,
          'serie': serie,
          'correlativo': correlativo.toString(),
          'fechaEmision': '${fechaEmision}T00:00:00-05:00',
          'formaPago': {
            'moneda': 'PEN',
            'tipo': 'Contado',
          },
          'mtoOperGravadas': double.parse(subtotal.toStringAsFixed(2)),
          'mtoIGV': double.parse(igv.toStringAsFixed(2)),
          'totalImpuestos': double.parse(igv.toStringAsFixed(2)),
          'valorVenta': double.parse(subtotal.toStringAsFixed(2)),
          'mtoImpVenta': double.parse(total.toStringAsFixed(2)),
          'client': {
            'tipoDoc': tipoDocCliente,
            'numDoc': clienteDoc,
            'rznSocial': clienteNombre,
            'address': {
              'direccion': clienteDireccion,
              'departamento': 'Arequipa',
              'provincia': 'Arequipa',
              'distrito': 'Alto Selva Alegre',
              'ubigeo': '040101',
            },
          },
          'details': details,
        },
      };

      final response = await http.post(
        Uri.parse('$baseUrl/personas/v1/sendBill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      final resBody = jsonDecode(response.body);

      // 3. Analizar respuesta de SUNAT
      if (response.statusCode == 200 && (resBody['status'] == 'ACEPTADO' || resBody['status'] == 'OBSERVADO')) {
        final apisunatId = resBody['id'] ?? '';
        final xmlUrl = resBody['xml'] ?? '';
        final cdrUrl = resBody['cdr'] ?? '';
        final pdfUrl = '$baseUrl/documents/$apisunatId/getPDF/A4/$fileName.PDF';

        // Actualizar tabla facturacion_sunat
        await _supabase.from('facturacion_sunat').update({
          'estado_sunat': 'ACEPTADO',
          'apisunat_id': apisunatId,
          'xml_url': xmlUrl,
          'cdr_url': cdrUrl,
          'pdf_url': pdfUrl,
          'mensaje_sunat': 'Comprobante aceptado por SUNAT',
        }).eq('id', facturaId);

        if (cotizacionId != null) {
          final esAnticipo = factura['anticipada'] == true;
          await _supabase.from('cotizaciones').update({
            'estado_facturacion': esAnticipo ? 'FACTURADO_ANTICIPADO' : 'FACTURADO_FINAL',
          }).eq('id', cotizacionId);
        }

        return {
          'exito': true,
          'estado': 'ACEPTADO',
          'mensaje': 'El comprobante $fileName ha sido ACEPTADO por SUNAT',
          'pdf_url': pdfUrl,
          'xml_url': xmlUrl,
          'cdr_url': cdrUrl,
        };
      } else {
        // Extraer mensaje detallado de error
        String detalleError = 'Error desconocido al conectar con SUNAT';
        if (resBody['faults'] != null && (resBody['faults'] as List).isNotEmpty) {
          final fault = resBody['faults'][0];
          detalleError = 'Código ${fault['code'] ?? ''}: ${fault['message'] ?? 'Rechazado por SUNAT'}';
        } else if (resBody['error'] != null) {
          detalleError = resBody['error']['message'] ?? resBody['error'].toString();
        } else if (resBody['message'] != null) {
          detalleError = resBody['message'].toString();
        }

        // Registrar estado de ERROR con su especificación exacta
        await _supabase.from('facturacion_sunat').update({
          'estado_sunat': 'ERROR',
          'mensaje_sunat': detalleError,
        }).eq('id', facturaId);

        return {
          'exito': false,
          'estado': 'ERROR',
          'mensaje': detalleError,
        };
      }
    } catch (e) {
      final err = 'Error al enviar comprobante a SUNAT: $e';
      await _supabase.from('facturacion_sunat').update({
        'estado_sunat': 'ERROR',
        'mensaje_sunat': err,
      }).eq('id', facturaId);

      return {
        'exito': false,
        'estado': 'ERROR',
        'mensaje': err,
      };
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 4. ETAPA 1: REGISTRAR GUÍA LOCALMENTE (PENDIENTE DE ENVÍO)
  // ────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> registrarGuiaLocal({
    required String cotizacionId,
    required String carguioId,
    required String serie,
    required int correlativo,
    required String clienteDocumento,
    required String clienteNombre,
  }) async {
    try {
      final existentes = await _supabase
          .from('guias_remision')
          .select()
          .eq('serie', serie)
          .eq('correlativo', correlativo)
          .maybeSingle();

      if (existentes != null) return existentes;

      final insertData = {
        'cotizacion_id': cotizacionId,
        'carguio_id': carguioId,
        'serie': serie,
        'correlativo': correlativo,
        'cliente_documento': clienteDocumento,
        'cliente_nombre': clienteNombre,
        'estado_sunat': 'PENDIENTE',
        'mensaje_sunat': 'Pendiente de envío a SUNAT',
      };

      final res = await _supabase
          .from('guias_remision')
          .insert(insertData)
          .select()
          .single();

      return res;
    } catch (e) {
      debugPrint('Error registrando guía local: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 5. ETAPA 2: ENVIAR GUÍA DE REMISIÓN A SUNAT (AL CIERRE O A DEMANDA)
  // ────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> enviarGuiaASunat(String guiaId) async {
    try {
      final guia = await _supabase
          .from('guias_remision')
          .select()
          .eq('id', guiaId)
          .single();

      final carguioId = guia['carguio_id'] ?? guia['cotizacion_id'];
      Map<String, dynamic> carguio = {};
      Map<String, dynamic> despacho = {};

      if (carguioId != null) {
        carguio = await _supabase
            .from('carguios_mixers')
            .select()
            .eq('id', carguioId)
            .maybeSingle() ?? {};

        final idVenta = carguio['id_venta'];
        if (idVenta != null) {
          despacho = await _supabase
              .from('ventas_programacion')
              .select()
              .eq('id', idVenta)
              .maybeSingle() ?? {};
        }
      }

      if (despacho.isEmpty && guia['cotizacion_id'] != null) {
        try {
          despacho = await _supabase
              .from('cotizaciones')
              .select()
              .eq('id', guia['cotizacion_id'])
              .maybeSingle() ?? {};
        } catch (_) {}
      }

      final serie = guia['serie'] ?? 'T001';
      final correlativo = guia['correlativo'] as int;
      final correlativoStr = correlativo.toString().padLeft(8, '0');
      final fileName = '$rucEmisor-09-$serie-$correlativoStr';

      final clienteDoc = (guia['cliente_documento'] ?? despacho['dni_ruc'] ?? despacho['cliente_documento'] ?? '20000000001').toString().trim();
      final clienteNombre = (guia['cliente_nombre'] ?? despacho['nombre_razon_social'] ?? despacho['cliente_nombre'] ?? 'CLIENTE GENERAL').toString();
      final direccionLlegada = (despacho['direccion'] ?? despacho['obra_direccion'] ?? 'OBRA AREQUIPA').toString();
      final placaMixer = (carguio['codigo_mixer'] ?? 'V1A-850').toString().toUpperCase().replaceAll('-', '').replaceAll(' ', '');

      String choferDni = (carguio['chofer_dni'] ?? '').toString().trim();
      String choferLicencia = (carguio['chofer_licencia'] ?? '').toString().trim();
      final choferNombre = (carguio['operador_nombre'] ?? 'CONDUCTOR NOVACON').toString();

      if (choferLicencia.isEmpty || choferDni.isEmpty) {
        try {
          final condRes = await _supabase
              .from('conductores')
              .select()
              .ilike('nombre', '%$choferNombre%')
              .limit(1)
              .maybeSingle();

          if (condRes != null) {
            choferLicencia = condRes['licencia']?.toString() ?? choferLicencia;
            final matchDni = RegExp(r'\d{8}').firstMatch(choferLicencia);
            if (matchDni != null && choferDni.isEmpty) {
              choferDni = matchDni.group(0)!;
            }
          }
        } catch (_) {}
      }

      if (choferDni.isEmpty) choferDni = '47586932';
      if (choferLicencia.isEmpty) choferLicencia = 'Q$choferDni';

      final volumenM3 = ((carguio['volumen_carguio'] ?? carguio['volumen'] ?? despacho['volumen'] ?? 8.0) as num).toDouble();
      final pesoKilos = volumenM3 * 2400.0; // 2400 kg por m³ de concreto

      final fechaEmision = DateTime.now().toIso8601String().split('T').first;

      final payload = {
        'personaId': personaId,
        'personaToken': personaToken,
        'fileName': fileName,
        'documentBody': {
          'ublVersion': '2.0',
          'tipoDoc': '09',
          'serie': serie,
          'correlativo': correlativo.toString(),
          'fechaEmision': '${fechaEmision}T00:00:00-05:00',
          'fechaInicioTraslado': '${fechaEmision}T00:00:00-05:00',
          'motivoTraslado': '01', // Venta
          'descripcionMotivo': 'VENTA DE CONCRETO PREMEZCLADO',
          'modalidadTraslado': '02', // Transporte privado
          'pesoBrutoTotal': pesoKilos,
          'unidadMedidaPeso': 'KGM',
          'numBultos': 1,
          'remitente': {
            'tipoDoc': '6',
            'numDoc': rucEmisor,
            'rznSocial': razonSocialEmisor,
          },
          'destinatario': {
            'tipoDoc': clienteDoc.length == 11 ? '6' : '1',
            'numDoc': clienteDoc,
            'rznSocial': clienteNombre,
          },
          'envio': {
            'partida': {
              'ubigeo': '040101',
              'direccion': direccionEmisor,
            },
            'llegada': {
              'ubigeo': '040101',
              'direccion': direccionLlegada,
            },
            'vehiculo': {
              'placa': placaMixer,
            },
            'conductor': {
              'tipoDoc': '1',
              'numDoc': choferDni,
              'nombres': choferNombre,
              'licencia': choferLicencia,
            },
          },
          'details': [
            {
              'codigo': 'CONC-GRE',
              'descripcion': 'CONCRETO PREMEZCLADO',
              'unidad': 'MTQ',
              'cantidad': volumenM3,
            }
          ],
        },
      };

      final response = await http.post(
        Uri.parse('$baseUrl/personas/v1/sendBill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      final resBody = jsonDecode(response.body);

      if (response.statusCode == 200 && (resBody['status'] == 'ACEPTADO' || resBody['status'] == 'OBSERVADO')) {
        final apisunatId = resBody['id'] ?? '';
        final xmlUrl = resBody['xml'] ?? '';
        final cdrUrl = resBody['cdr'] ?? '';
        final pdfUrl = '$baseUrl/documents/$apisunatId/getPDF/A4/$fileName.PDF';

        await _supabase.from('guias_remision').update({
          'estado_sunat': 'ACEPTADO',
          'apisunat_id': apisunatId,
          'xml_url': xmlUrl,
          'cdr_url': cdrUrl,
          'pdf_url': pdfUrl,
          'mensaje_sunat': 'Guía Aceptada por SUNAT',
        }).eq('id', guiaId);

        return {
          'exito': true,
          'estado': 'ACEPTADO',
          'mensaje': 'Guía Electrónica $fileName ACEPTADA por SUNAT',
          'pdf_url': pdfUrl,
          'xml_url': xmlUrl,
          'cdr_url': cdrUrl,
        };
      } else {
        String detalleError = 'Error al emitir GRE ante SUNAT';
        if (resBody['faults'] != null && (resBody['faults'] as List).isNotEmpty) {
          final fault = resBody['faults'][0];
          detalleError = 'Código ${fault['code'] ?? ''}: ${fault['message'] ?? 'Rechazado por SUNAT'}';
        } else if (resBody['error'] != null) {
          detalleError = resBody['error']['message'] ?? resBody['error'].toString();
        } else if (resBody['message'] != null) {
          detalleError = resBody['message'].toString();
        }

        await _supabase.from('guias_remision').update({
          'estado_sunat': 'ERROR',
          'mensaje_sunat': detalleError,
        }).eq('id', guiaId);

        return {
          'exito': false,
          'estado': 'ERROR',
          'mensaje': detalleError,
        };
      }
    } catch (e) {
      final err = 'Excepción al enviar GRE a SUNAT: $e';
      await _supabase.from('guias_remision').update({
        'estado_sunat': 'ERROR',
        'mensaje_sunat': err,
      }).eq('id', guiaId);

      return {
        'exito': false,
        'estado': 'ERROR',
        'mensaje': err,
      };
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 6. CONSULTAR DETALLE Y URLS DE PDF OFICIALES
  // ────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> obtenerDetalleDocumento(String docId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/documents/$docId/getById?personaId=$personaId&personaToken=$personaToken'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error al obtener documento de APISUNAT: $e');
    }
    return null;
  }
}
