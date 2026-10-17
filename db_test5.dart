import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  
  // attempt inserting a duplicate clave_unica in ventas_programacion
  try {
     var res = await sb.from('ventas_programacion').insert({
       'clave_unica': 'TEST_HISTORIAL',
       'cliente_id': 1
     });
     print("insert 1: $res");
     var res2 = await sb.from('ventas_programacion').insert({
       'clave_unica': 'TEST_HISTORIAL',
       'cliente_id': 1
     });
     print("insert 2: $res2");
  } catch(e) {
     print("Error inserting: $e");
  }
}
