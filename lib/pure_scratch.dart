import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final client = SupabaseClient(
    "http://167.233.215.224:8000",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
  );
  
  // Try to add column if not exists
  // First get columns
  final res = await client.from('disenos_mezcla').select().limit(1);
  if (res.isNotEmpty) {
    print("COLUMNS: ${res.first.keys.toList()}");
  } else {
    print("NO DATA");
  }
}
