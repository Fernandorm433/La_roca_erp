import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  try {
    final res = await Supabase.instance.client.from('carguios_mixers').select().limit(1);
    if (res.isNotEmpty) {
      print("Columnas de carguios_mixers:");
      print(res[0].keys.join(', '));
    } else {
      print("La tabla está vacía, no puedo inferir el esquema.");
    }
  } catch (e) {
    print(e);
  }
}
