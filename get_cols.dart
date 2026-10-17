import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient('http://167.233.215.224:8000', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE');
  try {
    var res = await supabase.rpc('get_columns_info', params: {'table_name': 'ventas_programacion'});
    print(res);
  } catch(e) {
    print("rpc failed, trying direct select 1");
    try {
      var r2 = await supabase.from('ventas_programacion').select().limit(1);
      if (r2.isNotEmpty) {
        print(r2.first.keys.toList());
      } else {
        print("Empty table");
      }
    } catch(e) {
      print(e);
    }
  }
}
