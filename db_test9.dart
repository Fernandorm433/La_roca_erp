import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  
  try {
     final res = await sb.from('ventas_programacion').insert({
       'clave_unica': 'TEST_UNIQUE_CLAVE',
       'fecha_entrega': '2026-07-06'
     });
     print("Insert 1 successful");
     
     final res2 = await sb.from('ventas_programacion').insert({
       'clave_unica': 'TEST_UNIQUE_CLAVE',
       'fecha_entrega': '2026-07-06'
     });
     print("Insert 2 successful");
  } catch(e) {
     print("Error: $e");
  }
}
