import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GpsSettingsPage extends StatefulWidget {
  const GpsSettingsPage({super.key});

  @override
  State<GpsSettingsPage> createState() => _GpsSettingsPageState();
}

class _GpsSettingsPageState extends State<GpsSettingsPage> {
  final _supabase = Supabase.instance.client;

  final Map<String, IconData> _iconOptions = {
    'mixer': Icons.local_shipping_rounded,
    'camioneta': Icons.directions_car_filled_outlined,
    'auto': Icons.directions_car_outlined,
    'cargador': Icons.agriculture_outlined,
    'volquete': Icons.local_shipping_outlined,
  };

  void _mostrarFormulario({Map<String, dynamic>? unidadActual, String? docId}) {
    final TextEditingController imeiCtrl = TextEditingController(text: docId ?? '');
    final TextEditingController nombreCtrl = TextEditingController(text: unidadActual?['nombre'] ?? '');
    final TextEditingController telefonoCtrl = TextEditingController(text: unidadActual?['telefono'] ?? '');
    String selectedIcon = unidadActual?['icono'] ?? 'mixer';
    bool isActive = unidadActual?['activo'] == true || unidadActual == null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    docId == null ? 'Nueva Unidad GPS' : 'Editar Unidad',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // IMEI (Solo editable si es nuevo)
                  TextField(
                    controller: imeiCtrl,
                    enabled: docId == null,
                    decoration: InputDecoration(
                      labelText: 'IMEI del GPS',
                      prefixIcon: const Icon(Icons.qr_code_2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: docId == null ? Colors.transparent : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Nombre / Alias
                  TextField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre / Alias (Ej. Mixer 01)',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Teléfono
                  TextField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Número de Celular (SIM)',
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text("Ícono del vehículo", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _iconOptions.entries.map((entry) {
                      final isSelected = selectedIcon == entry.key;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedIcon = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                entry.value,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Estado
                  SwitchListTile(
                    title: const Text("Unidad Activa"),
                    subtitle: const Text("Si se desactiva, se ocultará en el mapa principal"),
                    value: isActive,
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (val) => setModalState(() => isActive = val),
                  ),
                  const SizedBox(height: 20),

                  // Botón Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final imei = imeiCtrl.text.trim();
                        if (imei.isEmpty || nombreCtrl.text.trim().isEmpty) return;
                        
                        await _supabase.from('unidades_gps').upsert({
                          'imei': imei,
                          'nombre': nombreCtrl.text.trim(),
                          'telefono': telefonoCtrl.text.trim(),
                          'icono': selectedIcon,
                          'activo': isActive,
                        });
                        
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Guardar Configuración', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _eliminarUnidad(String imei) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Unidad"),
        content: Text("¿Estás seguro de eliminar la unidad con IMEI $imei? Esto la borrará del sistema."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await _supabase.from('unidades_gps').delete().eq('imei', imei);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ajustes de Flota GPS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF4F46E5), size: 28),
            onPressed: () => _mostrarFormulario(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('unidades_gps').stream(primaryKey: ['imei']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.satellite_alt_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No hay unidades registradas", style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarFormulario(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Registrar GPS", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                  )
                ],
              ),
            ).animate().fade();
          }

          final docs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final imei = data['imei'] ?? '';
              final iconoClave = data['icono'] ?? 'mixer';
              final isActive = data['activo'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFEEF2FF) : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconOptions[iconoClave] ?? Icons.local_shipping,
                      color: isActive ? const Color(0xFF4F46E5) : Colors.red.shade400,
                    ),
                  ),
                  title: Text(
                    data['nombre'] ?? 'Sin Nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("IMEI: $imei", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if (data['telefono'] != null && data['telefono'].toString().isNotEmpty)
                        Text("SIM: ${data['telefono']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _mostrarFormulario(unidadActual: data, docId: imei),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _eliminarUnidad(imei),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.2, curve: Curves.easeOutQuad, duration: Duration(milliseconds: 300 + (index * 50)));
            },
          );
        },
      ),
    );
  }
}
