import 'dart:io';

void main() {
  final file = File('lib/screens/rrhh/recursos_humanos_page.dart');
  var content = file.readAsStringSync();
  
  final target = '''
    String area = (empleado?.area != null && empleado!.area != '—')
        ? empleado.area
        : _estructuraEmpresa.keys.first;
    String cargo = (empleado?.cargo != null && empleado!.cargo != '—')
        ? empleado.cargo
        : _estructuraEmpresa[area]!.first;
''';

  final replacement = '''
    String area = (empleado?.area != null && empleado!.area != '—')
        ? empleado.area
        : _estructuraEmpresa.keys.first;
    
    // Make sure area exists in keys
    if (!_estructuraEmpresa.containsKey(area)) {
      _estructuraEmpresa[area] = [];
    }
    
    String cargo = (empleado?.cargo != null && empleado!.cargo != '—')
        ? empleado.cargo
        : (_estructuraEmpresa[area]!.isNotEmpty ? _estructuraEmpresa[area]!.first : '');
        
    // Fix: if cargo is not in the list for this area, add it to avoid crash
    if (cargo.isNotEmpty && !_estructuraEmpresa[area]!.contains(cargo)) {
      _estructuraEmpresa[area]!.add(cargo);
    }
''';

  if (content.contains(target)) {
    content = content.replaceAll(target, replacement);
    file.writeAsStringSync(content);
    print("Patched successfully!");
  } else {
    print("Target not found!");
  }
}
