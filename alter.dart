import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  try {
    var res = await supabase.rpc('execute_sql', params: {'sql_query': 'ALTER TABLE cotizaciones DROP CONSTRAINT IF EXISTS cotizaciones_asesor_id_fkey; ALTER TABLE cotizaciones ADD CONSTRAINT cotizaciones_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES usuarios(id);'});
    print(res);
  } catch(e) {
    print("Error: $e");
  }
}
