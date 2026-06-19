import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  await Supabase.initialize(
    url: "http://91.98.135.205:8000",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE",
  );
  
  final _sb = Supabase.instance.client;
  final res = await _sb.from('ventas_programacion').select().limit(1);
  if (res.isNotEmpty) {
    print("Columnas de ventas_programacion:");
    for (var key in res[0].keys) {
      print("- $key");
    }
  } else {
    print("La tabla está vacía o no existe.");
  }
  exit(0);
}
