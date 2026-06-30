import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/core/config/supabase_config.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  try {
    final client = Supabase.instance.client;
    final res = await client.from('asignacion_bombas').select().limit(1);
    print(res);
  } catch (e) {
    print(e);
  }
}
