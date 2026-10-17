import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DisenosService {
  static final DisenosService _instance = DisenosService._internal();
  factory DisenosService() => _instance;
  DisenosService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String googleSheetsCsvUrl =
      'https://docs.google.com/spreadsheets/d/e/2PACX-1vRoLc2mQMgkTEwLDVy4XzppokihnVBslMyXpwGVWxaeQC09bfWkBMB5Rem9GQpLLOOgQvu3t_P5ROdD/pub?output=csv';

  static const String _kCacheKey = 'disenos_mezcla_cache_v1';

  /// Obtiene la lista de diseños de mezcla.
  /// 1. Intenta desde Supabase (si existe la tabla).
  /// 2. Si la tabla no existe en Supabase (PGRST205), lee desde el caché local (SharedPreferences).
  /// 3. Si el caché local está vacío, descarga automáticamente desde Google Drive (Google Sheets) y lo almacena.
  Future<List<Map<String, dynamic>>> obtenerDisenos({bool forceDrive = false}) async {
    if (!forceDrive) {
      try {
        final data = await _supabase
            .from('disenos_mezcla')
            .select()
            .order('resistencia', ascending: true);
        if (data.isNotEmpty) {
          // Guardar copia de respaldo en caché local
          await _guardarEnCache(List<Map<String, dynamic>>.from(data));
          return List<Map<String, dynamic>>.from(data);
        }
      } catch (e) {
        debugPrint('ℹ️ Supabase disenos_mezcla no disponible ($e). Usando Drive/Caché local.');
      }
    }

    // Leer desde caché local
    final cached = await _leerDeCache();
    if (cached.isNotEmpty && !forceDrive) {
      return cached;
    }

    // Si no hay datos en caché o se fuerza Drive, sincronizar desde Google Drive
    return await sincronizarDesdeGoogleSheets();
  }

  /// Descarga y procesa la data histórica de Google Drive (Google Sheets CSV)
  Future<List<Map<String, dynamic>>> sincronizarDesdeGoogleSheets() async {
    final res = await http.get(Uri.parse(googleSheetsCsvUrl)).timeout(
      const Duration(seconds: 25),
    );

    if (res.statusCode != 200) {
      throw Exception('No se pudo acceder a Google Drive (código ${res.statusCode})');
    }

    final csvData = const CsvDecoder().convert(res.body);
    if (csvData.length <= 2) {
      throw Exception('La hoja de cálculo en Drive no contiene filas de datos.');
    }

    // Estructura de columnas en Drive:
    // Col 10: VOLUMEN
    // Col 11: DISEÑO
    // Col 12: CEMENTO (HE / 1P)
    // Col 13: TIPO DE VACIADO
    // Col 14: HUSO
    // Col 15: CEMENTO X M3
    // Col 16: ARENA (KG)
    // Col 17: CEMENTO (KG)
    // Col 18: AGUA (LT)
    // Col 19: ADITIVO (KG)
    // Col 20: 1/2 (KG)
    // Col 21: 3/4 (KG)
    // Col 22: 3/8 (KG)

    final Map<String, List<Map<String, double>>> agrupados = {};

    for (int i = 2; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.length <= 22) continue;

      try {
        final vol = double.tryParse(row[10].toString().replaceAll(',', '.')) ?? 0.0;
        if (vol <= 0) continue;

        final diseno = row[11].toString().trim();
        final tipo = row[13].toString().trim().toUpperCase();
        final huso = row[14].toString().trim();

        if (diseno.isEmpty || tipo.isEmpty) continue;

        final cementoKgTotal = double.tryParse(row[17].toString().replaceAll(',', '.')) ?? 0.0;
        final arenaKgTotal = double.tryParse(row[16].toString().replaceAll(',', '.')) ?? 0.0;
        final aguaLtTotal = double.tryParse(row[18].toString().replaceAll(',', '.')) ?? 0.0;
        final aditivoKgTotal = double.tryParse(row[19].toString().replaceAll(',', '.')) ?? 0.0;
        final p12KgTotal = double.tryParse(row[20].toString().replaceAll(',', '.')) ?? 0.0;
        final p34KgTotal = double.tryParse(row[21].toString().replaceAll(',', '.')) ?? 0.0;
        final p38KgTotal = double.tryParse(row[22].toString().replaceAll(',', '.')) ?? 0.0;

        final key = '$diseno|$huso|$tipo';
        agrupados.putIfAbsent(key, () => []).add({
          'cemento_m3': cementoKgTotal / vol,
          'arena_m3': arenaKgTotal / vol,
          'agua_m3': aguaLtTotal / vol,
          'aditivo_m3': aditivoKgTotal / vol,
          'p12_m3': p12KgTotal / vol,
          'p34_m3': p34KgTotal / vol,
          'p38_m3': p38KgTotal / vol,
        });
      } catch (_) {
        continue;
      }
    }

    if (agrupados.isEmpty) {
      throw Exception('No se detectaron recetas válidas en la hoja de Drive.');
    }

    final List<Map<String, dynamic>> recetas = [];

    agrupados.forEach((key, lista) {
      final parts = key.split('|');
      final diseno = parts[0];
      final huso = parts[1];
      final tipo = parts[2];
      final count = lista.length;

      double avgCem = lista.map((e) => e['cemento_m3']!).reduce((a, b) => a + b) / count;
      double avgAre = lista.map((e) => e['arena_m3']!).reduce((a, b) => a + b) / count;
      double avgAgu = lista.map((e) => e['agua_m3']!).reduce((a, b) => a + b) / count;
      double avgAdi = lista.map((e) => e['aditivo_m3']!).reduce((a, b) => a + b) / count;
      double avgP12 = lista.map((e) => e['p12_m3']!).reduce((a, b) => a + b) / count;
      double avgP34 = lista.map((e) => e['p34_m3']!).reduce((a, b) => a + b) / count;
      double avgP38 = lista.map((e) => e['p38_m3']!).reduce((a, b) => a + b) / count;

      double pTotal = avgP12 + avgP34 + avgP38;
      double pct12 = pTotal > 0 ? ((avgP12 / pTotal) * 100) : 100;
      double pct34 = pTotal > 0 ? ((avgP34 / pTotal) * 100) : 0;
      double pct38 = pTotal > 0 ? ((avgP38 / pTotal) * 100) : 0;

      recetas.add({
        'id': 'drv_${diseno}_${huso}_${tipo.toLowerCase()}'.replaceAll(' ', '_'),
        'resistencia': diseno,
        'huso': huso.isEmpty ? '67' : huso,
        'tipo_vaciado': tipo,
        'cemento_kg': double.parse(avgCem.toStringAsFixed(1)),
        'arena_kg': double.parse(avgAre.toStringAsFixed(1)),
        'piedra_total_kg': double.parse(pTotal.toStringAsFixed(1)),
        'piedra_12_porcentaje': double.parse(pct12.toStringAsFixed(1)),
        'piedra_34_porcentaje': double.parse(pct34.toStringAsFixed(1)),
        'piedra_38_porcentaje': double.parse(pct38.toStringAsFixed(1)),
        'arena_1_porcentaje': 100.0,
        'arena_2_porcentaje': 0.0,
        'agua_lt': double.parse(avgAgu.toStringAsFixed(1)),
        'aditivo_kg': double.parse(avgAdi.toStringAsFixed(2)),
        'muestra_count': count,
      });
    });

    // Ordenar de mayor a menor frecuencia
    recetas.sort((a, b) => (b['muestra_count'] as int).compareTo(a['muestra_count'] as int));

    // Guardar siempre en caché local para que la app funcione independientemente
    await _guardarEnCache(recetas);

    // Intentar también subir a Supabase silenciosamente si la tabla existe
    try {
      for (final r in recetas) {
        final payload = Map<String, dynamic>.from(r)..remove('muestra_count');
        await _supabase.from('disenos_mezcla').upsert(payload);
      }
    } catch (_) {
      // Ignorar error si la tabla de Supabase aún no fue creada
    }

    return recetas;
  }

  /// Actualiza los porcentajes de un diseño tanto localmente como en Supabase
  Future<void> actualizarPorcentajes({
    required dynamic id,
    required double p12,
    required double p34,
    required double p38,
    required double a1,
    required double a2,
  }) async {
    // 1. Actualizar caché local
    final lista = await _leerDeCache();
    final index = lista.indexWhere((e) => e['id']?.toString() == id.toString());
    if (index != -1) {
      lista[index]['piedra_12_porcentaje'] = p12;
      lista[index]['piedra_34_porcentaje'] = p34;
      lista[index]['piedra_38_porcentaje'] = p38;
      lista[index]['arena_1_porcentaje'] = a1;
      lista[index]['arena_2_porcentaje'] = a2;
      await _guardarEnCache(lista);
    }

    // 2. Intentar actualizar en Supabase si es posible
    try {
      await _supabase.from('disenos_mezcla').update({
        'piedra_12_porcentaje': p12,
        'piedra_34_porcentaje': p34,
        'piedra_38_porcentaje': p38,
        'arena_1_porcentaje': a1,
        'arena_2_porcentaje': a2,
      }).eq('id', id);
    } catch (e) {
      debugPrint('ℹ️ Guardado en local. Supabase no disponible: $e');
    }
  }

  /// Guarda o crea un diseño manualmente
  Future<void> guardarDiseno(Map<String, dynamic> diseno, {dynamic idExistente}) async {
    final lista = await _leerDeCache();

    if (idExistente != null) {
      final idx = lista.indexWhere((e) => e['id']?.toString() == idExistente.toString());
      if (idx != -1) {
        lista[idx] = {...lista[idx], ...diseno};
      }
    } else {
      final nuevoId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      lista.insert(0, {'id': nuevoId, ...diseno});
    }

    await _guardarEnCache(lista);

    try {
      if (idExistente == null) {
        await _supabase.from('disenos_mezcla').insert(diseno);
      } else {
        await _supabase.from('disenos_mezcla').update(diseno).eq('id', idExistente);
      }
    } catch (_) {}
  }

  /// Elimina un diseño
  Future<void> eliminarDiseno(dynamic id) async {
    final lista = await _leerDeCache();
    lista.removeWhere((e) => e['id']?.toString() == id.toString());
    await _guardarEnCache(lista);

    try {
      await _supabase.from('disenos_mezcla').delete().eq('id', id);
    } catch (_) {}
  }

  // --- Manejo de Caché Local en SharedPreferences ---

  Future<void> _guardarEnCache(List<Map<String, dynamic>> recetas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonEncode(recetas));
  }

  Future<List<Map<String, dynamic>>> _leerDeCache() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kCacheKey);
    if (str == null || str.isEmpty) return [];
    try {
      final List decoded = jsonDecode(str);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
