import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  var res = await sb.from('ventas_programacion').select().limit(2);
  print('VENTAS_PROGRAMACION COLS: ${res.isNotEmpty ? res.first.keys.toList() : "empty"}');
  var tables = await sb.rpc('execute_sql', params: {'sql_query': "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"});
  print('ALL TABLES: $tables');
}
