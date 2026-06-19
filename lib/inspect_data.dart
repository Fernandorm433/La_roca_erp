import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  try {
    final client = Supabase.instance.client;
    final res = await client
        .from('despachos_produccion')
        .select('*')
        .gte('fecha', '2026-05-29')
        .lte('fecha', '2026-05-29')
        .ilike('mixer', '%CMX 44%');

    print('Registros en despachos_produccion para CMX 44 el 2026-05-29: ${res.length}');
    for (var r in res) {
      print('ID: ${r['id']}, Cliente: ${r['cliente']}, Volumen: ${r['volumen']}, Volumen Guias: ${r['volumen_guias']}, Optimizado: ${r['optimizado']}, Orden: ${r['orden_carguio']}, Guia: ${r['n_guia']}, Creado: ${r['created_at']}');
    }
  } catch (e) {
    print(e);
  }
}
