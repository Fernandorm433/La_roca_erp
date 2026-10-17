import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  
  try {
     final res = await sb.rpc('execute_sql', params: {
       'sql_query': 'SELECT constraint_name, table_name FROM information_schema.table_constraints WHERE constraint_type = \'UNIQUE\' AND table_name = \'ventas_programacion\';'
     });
     print("Constraints: $res");
  } catch(e) {
     print("Error: $e");
  }
}
