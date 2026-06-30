import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SunatService {
  final _supabase = Supabase.instance.client;

  /// Envía los datos de una venta (Boleta o Factura) a la Edge Function de Supabase
  /// para procesarla en SUNAT (Entorno BETA actualmente).
  Future<Map<String, dynamic>?> emitirComprobante({
    required String tipoDoc, // '01' Factura, '03' Boleta
    required String serie, // ej. 'B001'
    required int correlativo, // ej. 1
    required String clienteDocumento, // DNI o RUC
    required double montoTotal,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'sunat-emision',
        body: {
          'tipoDoc': tipoDoc,
          'serie': serie,
          'correlativo': correlativo,
          'clienteDocumento': clienteDocumento,
          'montoTotal': montoTotal,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        debugPrint('Respuesta de SUNAT: $data');
        return data as Map<String, dynamic>;
      } else {
        debugPrint('Error en la función: ${response.status} - ${response.data}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción al llamar a sunat-emision: $e');
      return null;
    }
  }
}
