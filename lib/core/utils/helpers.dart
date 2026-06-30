import 'package:flutter/material.dart';

double limpiarYExtraerNumero(dynamic valorRaw) {
  if (valorRaw == null) return 0.0;
  String texto = valorRaw.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(texto) ?? 0.0;
}

BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor, 
  borderRadius: BorderRadius.circular(16), 
  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))]
);

class Helpers {
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}