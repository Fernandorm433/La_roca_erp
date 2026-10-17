import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsultaDocService {
  final _supabase = Supabase.instance.client;

  /// Consulta un RUC (11 dígitos) o DNI (8 dígitos)
  /// 1. Busca en la base de datos local (Cotizaciones y Ventas anteriores)
  /// 2. Si no existe, consulta online a SUNAT (RUC) o RENIEC (DNI)
  Future<Map<String, dynamic>?> consultarDocumento(String documento) async {
    final doc = documento.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (doc.length != 8 && doc.length != 11) return null;

    // ─── 1. BÚSQUEDA LOCAL EN COTIZACIONES ──────────────────────────
    try {
      final cot = await _supabase
          .from('cotizaciones')
          .select('cliente_nombre, cliente_documento, cliente_telefono, cliente_direccion, obra_direccion, obra_distrito')
          .eq('cliente_documento', doc)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (cot != null && cot['cliente_nombre'] != null && cot['cliente_nombre'].toString().isNotEmpty) {
        return {
          'nombre_razon_social': cot['cliente_nombre'],
          'dni_ruc': cot['cliente_documento'] ?? doc,
          'telefono': cot['cliente_telefono'] ?? '',
          'direccion': cot['cliente_direccion'] ?? cot['obra_direccion'] ?? '',
          'distrito': cot['obra_distrito'] ?? '',
          'estado': 'ACTIVO',
          'condicion': 'HABIDO',
          'fuente': 'BASE DE DATOS NOVACONCRET',
        };
      }
    } catch (e) {
      debugPrint('Error en consulta local cotizaciones: $e');
    }

    // ─── 2. BÚSQUEDA LOCAL EN VENTAS PROGRAMACIÓN ───────────────────
    try {
      final vp = await _supabase
          .from('ventas_programacion')
          .select('nombre_razon_social, dni_ruc, telefono, direccion, distrito')
          .eq('dni_ruc', doc)
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (vp != null && vp['nombre_razon_social'] != null && vp['nombre_razon_social'].toString().isNotEmpty) {
        return {
          'nombre_razon_social': vp['nombre_razon_social'],
          'dni_ruc': vp['dni_ruc'] ?? doc,
          'telefono': vp['telefono'] ?? '',
          'direccion': vp['direccion'] ?? '',
          'distrito': vp['distrito'] ?? '',
          'estado': 'ACTIVO',
          'condicion': 'HABIDO',
          'fuente': 'VENTAS PREVIAS',
        };
      }
    } catch (e) {
      debugPrint('Error en consulta local ventas_programacion: $e');
    }

    // ─── 3. CONSULTA EXTERNA ONLINE (SUNAT / RENIEC) ────────────────
    if (doc.length == 11) {
      return await _consultarRucOnline(doc);
    } else {
      return await _consultarDniOnline(doc);
    }
  }

  Future<Map<String, dynamic>?> _consultarRucOnline(String ruc) async {
    try {
      final res = await http.get(
        Uri.parse('https://api.apis.net.pe/v1/ruc?numero=$ruc'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final nombre = data['nombre'] ?? data['razon_social'] ?? data['razonSocial'] ?? '';
        final direccion = data['direccion'] ?? data['domicilio_fiscal'] ?? '';
        final distrito = data['distrito'] ?? '';
        final estado = data['estado'] ?? 'ACTIVO';
        final condicion = data['condicion'] ?? 'HABIDO';
        final ubigeo = data['ubigeo'] ?? '';

        if (nombre.toString().isNotEmpty) {
          return {
            'nombre_razon_social': nombre,
            'dni_ruc': ruc,
            'direccion': direccion,
            'distrito': distrito,
            'ubigeo': ubigeo,
            'estado': estado,
            'condicion': condicion,
            'fuente': 'SUNAT ONLINE',
          };
        }
      }
    } catch (e) {
      debugPrint('Error consultando RUC en APIs net pe: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>?> _consultarDniOnline(String dni) async {
    try {
      final res = await http.get(
        Uri.parse('https://api.apis.net.pe/v1/dni?numero=$dni'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final nombre = data['nombre'] ?? '';
        final apellidoP = data['apellidoPaterno'] ?? '';
        final apellidoM = data['apellidoMaterno'] ?? '';
        final nombres = data['nombres'] ?? '';
        final nombreCompleto = nombre.toString().isNotEmpty ? nombre : '$nombres $apellidoP $apellidoM'.trim();

        if (nombreCompleto.toString().isNotEmpty) {
          return {
            'nombre_razon_social': nombreCompleto,
            'dni_ruc': dni,
            'direccion': data['direccion'] ?? '',
            'distrito': data['distrito'] ?? '',
            'ubigeo': data['ubigeo'] ?? '',
            'estado': 'ACTIVO',
            'condicion': 'HABIDO',
            'fuente': 'RENIEC ONLINE',
          };
        }
      }
    } catch (e) {
      debugPrint('Error consultando DNI en APIs net pe: $e');
    }

    return null;
  }
}
