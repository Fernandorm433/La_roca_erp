import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class CierreDiarioService {
  static final supabase = Supabase.instance.client;

  static Future<bool> isDiaCerrado(String fechaFiltro) async {
    try {
      final res = await supabase.from('cierre_operativo').select('cerrado').eq('fecha', fechaFiltro).maybeSingle();
      if (res != null) return res['cerrado'] == true;
    } catch (e) {
      // Table might not exist yet
      debugPrint("Warning: Tabla cierre_operativo podría no existir. Error: $e");
    }
    return false;
  }

  static Future<void> cerrarDia(String fechaFiltro) async {
    try {
      final existe = await supabase.from('cierre_operativo').select('id').eq('fecha', fechaFiltro).maybeSingle();
      if (existe != null) {
        await supabase.from('cierre_operativo').update({'cerrado': true}).eq('fecha', fechaFiltro);
      } else {
        await supabase.from('cierre_operativo').insert({'fecha': fechaFiltro, 'cerrado': true});
      }
    } catch (e) {
      debugPrint("Error cerrando día (crear tabla si es necesario): $e");
      throw Exception("Falta crear la tabla 'cierre_operativo' (fecha TEXT, cerrado BOOLEAN). Error: $e");
    }
  }
}
