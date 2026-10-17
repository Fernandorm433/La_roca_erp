import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  var res = await sb.rpc('get_columns_info', params: {'table_name': 'ventas_programacion_historial'});
  print("ventas_programacion_historial columns: $res");
  try {
     var r2 = await sb.from('logistica_historial').select().limit(1);
     print("logistica_historial: ${r2}");
  } catch(e) {}
}
