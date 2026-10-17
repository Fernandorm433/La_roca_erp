import 'package:supabase/supabase.dart';
void main() async {
  final sb = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  
  try {
     var res = await sb.from('ventas_programacion').select().limit(1);
     if (res.isNotEmpty) {
       var vCopy = Map<String, dynamic>.from(res.first);
       vCopy.remove('id');
       vCopy.remove('created_at');
       print("Inserting duplicate clave_unica: ${vCopy['clave_unica']}");
       var inserted = await sb.from('ventas_programacion').insert(vCopy).select();
       print("Success: $inserted");
     }
  } catch(e) {
     print("Error inserting: $e");
  }
}
