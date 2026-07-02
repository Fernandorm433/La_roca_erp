import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class MisCarguiosPage extends StatefulWidget {
  const MisCarguiosPage({super.key});

  @override
  State<MisCarguiosPage> createState() => _MisCarguiosPageState();
}

class _MisCarguiosPageState extends State<MisCarguiosPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> misCarguios = [];
  Map<String, dynamic> infoVentas = {}; // Mapa de id_venta -> info de la venta

  @override
  void initState() {
    super.initState();
    _cargarMisViajes();
  }

  Future<void> _cargarMisViajes() async {
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      // 1. Obtener mi ID de conductor
      final condData = await supabase.from('conductores').select('id').eq('usuario_id', user.id).maybeSingle();
      if (condData == null) {
        if (mounted) setState(() => loading = false);
        return;
      }
      String miConductorId = condData['id'].toString();

      // 2. Obtener mis carguíos para el día de hoy
      String hoy = DateTime.now().toIso8601String().split('T')[0];
      
      List<dynamic> carguiosData = [];
      try {
        carguiosData = await supabase
            .from('carguios_mixers')
            .select()
            .eq('operador_id', miConductorId)
            // Asumimos que los carguios se crean para el dia actual (o podríamos filtrar por creado_en, 
            // pero para esta lógica simplificada mostramos los que no están 'Completado' o los de hoy)
            .neq('estado', 'Completado')
            .order('orden_carga');
      } catch (e) {
        debugPrint("Tabla carguios_mixers no existe aún: $e");
      }

      if (carguiosData.isEmpty) {
        if (mounted) setState(() { misCarguios = []; loading = false; });
        return;
      }

      // 3. Obtener la información de las obras (Ventas)
      List<String> idsVentas = carguiosData.map((e) => e['id_venta'].toString()).toSet().toList();
      final ventasData = await supabase.from('ventas_programacion').select().inFilter('id', idsVentas);
      
      // 4. Obtener bombas asignadas si es necesario
      final asignacionesData = await supabase.from('asignacion_bombas').select().inFilter('id_venta', idsVentas);
      Map<String, String> mapaBombas = {
        for (var a in asignacionesData) a['id_venta'].toString(): a['bomba_asignada'].toString(),
      };

      Map<String, dynamic> ventasMap = {};
      for (var v in ventasData) {
        String vId = v['id'].toString();
        v['bomba_asignada_real'] = mapaBombas[vId];
        ventasMap[vId] = v;
      }

      if (mounted) {
        setState(() {
          misCarguios = List<Map<String, dynamic>>.from(carguiosData);
          infoVentas = ventasMap;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _abrirGoogleMaps(String direccion, String coordenadas) async {
    String query = coordenadas.isNotEmpty ? coordenadas : direccion;
    if (query.isEmpty) return;
    if (query.contains('http')) {
      final uri = Uri.parse(query);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _actualizarEstado(String idCarguio, String nuevoEstado) async {
    try {
      await supabase.from('carguios_mixers').update({'estado': nuevoEstado}).eq('id', idCarguio);
      _cargarMisViajes();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Mis Carguíos (Viajes)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: _cargarMisViajes,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : misCarguios.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.done_all, size: 60, color: Colors.green),
                      SizedBox(height: 10),
                      Text("No tienes viajes pendientes", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: misCarguios.length,
                  itemBuilder: (context, index) {
                    final c = misCarguios[index];
                    final venta = infoVentas[c['id_venta'].toString()] ?? {};
                    String bomba = venta['bomba_asignada_real'] ?? venta['bombas'] ?? 'DIRECTO';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text("Viaje ${c['orden_carga']} • Ticket: ${c['numero_carguio']}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                ),
                                const Spacer(),
                                Text(c['hora_carguio'] ?? '--:--', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              venta['nombre_razon_social'] ?? 'Obra Desconocida',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.water_drop, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Text("${c['volumen_carguio']} m³ asignados", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.fire_truck, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Text("Bomba: $bomba", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () => _abrirGoogleMaps(venta['direccion'] ?? '', venta['mapa_coordenadas'] ?? ''),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.red),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        venta['direccion'] ?? 'Ver Ubicación en Mapa',
                                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text("Estado del Viaje", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: ['Pendiente', 'En Camino', 'En Obra', 'Vaciando', 'Completado'].contains(c['estado']?.toString())
                                  ? c['estado'].toString()
                                  : 'Pendiente',
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente en Planta')),
                                DropdownMenuItem(value: 'En Camino', child: Text('En Camino a Obra')),
                                DropdownMenuItem(value: 'En Obra', child: Text('Llegué a Obra')),
                                DropdownMenuItem(value: 'Vaciando', child: Text('Inicié Vaciado')),
                                DropdownMenuItem(value: 'Completado', child: Text('Completado (Regresando)')),
                              ],
                              onChanged: (val) {
                                if (val != null) _actualizarEstado(c['id'].toString(), val);
                              },
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
