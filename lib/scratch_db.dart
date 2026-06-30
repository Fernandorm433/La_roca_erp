import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );
  
  final res = await Supabase.instance.client.from('disenos_mezcla').select().limit(1);
  if (res.isNotEmpty) {
    print(res.first.keys.toList());
  } else {
    print("No rows");
  }
}
