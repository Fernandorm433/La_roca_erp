import 'dart:io';

class MapUtils {
  /// Extrae la latitud y longitud de un enlace de Google Maps.
  /// Soporta enlaces largos y cortos (ej. maps.app.goo.gl).
  static Future<Map<String, double>?> extractCoordinates(String url) async {
    if (url.isEmpty) return null;
    
    String finalUrl = url;
    
    // Si es un enlace corto, intentamos expandirlo obteniendo el header Location
    if (url.contains('goo.gl') || url.contains('maps.app.goo.gl')) {
      try {
        final client = HttpClient();
        var request = await client.getUrl(Uri.parse(url));
        request.followRedirects = false;
        var response = await request.close();
        if (response.isRedirect) {
          final loc = response.headers.value(HttpHeaders.locationHeader);
          if (loc != null) {
            finalUrl = loc;
          }
        }
      } catch (e) {
        // Ignorar error y usar url original
      }
    }
    
    // Buscar coordenadas con formato @lat,lng
    final regex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final match = regex.firstMatch(finalUrl);
    
    if (match != null && match.groupCount >= 2) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng};
      }
    }
    
    // Buscar formato antiguo q=lat,lng
    final regexQ = RegExp(r'q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final matchQ = regexQ.firstMatch(finalUrl);
    
    if (matchQ != null && matchQ.groupCount >= 2) {
      final lat = double.tryParse(matchQ.group(1)!);
      final lng = double.tryParse(matchQ.group(2)!);
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng};
      }
    }
    
    return null;
  }
}
