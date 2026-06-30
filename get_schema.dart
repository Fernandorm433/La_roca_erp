import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/core/config/supabase_config.dart';
import 'dart:convert';

Future<void> main() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  try {
    final res = await Supabase.instance.client.from('despachos_produccion').select().limit(1);
    print("despachos_produccion data: ${jsonEncode(res)}");
  } catch (e) {
    print("Error: $e");
  }
}
