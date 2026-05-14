import 'package:flutter/material.dart';

double limpiarYExtraerNumero(dynamic valorRaw) {
  if (valorRaw == null) return 0.0;
  String texto = valorRaw.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(texto) ?? 0.0;
}

BoxDecoration cardDecoration() => BoxDecoration(
  color: Colors.white, 
  borderRadius: BorderRadius.circular(16), 
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))]
);