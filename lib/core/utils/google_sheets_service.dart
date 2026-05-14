import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  // 👇 REEMPLAZA ESTO CON LA URL EXACTA QUE COPIASTE DE APPS SCRIPT 👇
  static const String _url = "https://script.google.com/macros/s/AKfycbwcQnhn7Uq0C0-UHnAv_5izUV5EFWQ40bE0TNiVkmGiqsZWXHe-mPc-UyF9k3T4M2jl/exec";

  static Future<bool> enviarChecklist(Map<String, dynamic> datos) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(datos),
      );

      // Apps Script suele responder con 302 (redirección) o 200 (OK)
      if (response.statusCode == 200 || response.statusCode == 302) {
        return true;
      } else {
        print("Error del servidor: Código ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error de conexión: $e");
      return false;
    }
  }
}