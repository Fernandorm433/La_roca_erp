import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  
  // Create a view or direct select from pg_constraint via REST if possible?
  // Supabase anon key usually doesn't have access to pg_catalog via REST.
  // We can try calling a custom rpc if they made one, but `execute_sql` didn't exist.
  // Instead, let's try to query the table using direct select to see what tables exist.
  
  // Let's check `ventas_programacion_historial`
  try {
     var res = await sb.from('ventas_programacion_historial').select().limit(1);
     print("ventas_programacion_historial: $res");
  } catch(e) {
     print("Error 1: $e");
  }

  // Let's check `historial_ventas`
  try {
     var res = await sb.from('historial_ventas').select().limit(1);
     print("historial_ventas: $res");
  } catch(e) {
     print("Error 2: $e");
  }
}
