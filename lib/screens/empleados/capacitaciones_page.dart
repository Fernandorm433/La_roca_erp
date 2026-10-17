import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class CapacitacionesPage extends StatefulWidget {
  final String rol;
  final String empleadoId;
  const CapacitacionesPage({super.key, required this.rol, required this.empleadoId});

  @override
  State<CapacitacionesPage> createState() => _CapacitacionesPageState();
}

class _CapacitacionesPageState extends State<CapacitacionesPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _capacitaciones = [];

  @override
  void initState() {
    super.initState();
    _fetchCapacitaciones();
  }

  Future<void> _fetchCapacitaciones() async {
    try {
      // Obtenemos todas las capacitaciones y revisamos si el usuario actual las ha completado
      final res = await _supabase.from('capacitaciones').select('''
        *,
        capacitaciones_completadas (
          completado,
          empleado_id
        )
      ''').order('fecha_publicacion', ascending: false);

      final List<Map<String, dynamic>> list = [];
      for (var row in res) {
        final compList = row['capacitaciones_completadas'] as List<dynamic>? ?? [];
        final userComp = compList.firstWhere(
          (c) => c['empleado_id'] == widget.empleadoId,
          orElse: () => null,
        );

        final bool isCompletado = userComp != null && (userComp['completado'] == true);
        
        // Estadísticas para RRHH/Admin
        final int totalCompletados = compList.where((c) => c['completado'] == true).length;

        list.add({
          'id': row['id'],
          'titulo': row['titulo'] ?? 'Sin título',
          'fecha': row['fecha_publicacion'] ?? '',
          'descripcion': row['descripcion'] ?? '',
          'pdf_url': row['archivo_pdf_url'] ?? '',
          'completado': isCompletado,
          'estadisticas': '$totalCompletados Empleados completaron',
        });
      }

      if (mounted) {
        setState(() {
          _capacitaciones = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch capacitaciones: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _descargarPdf(String urlOrFilename) async {
    if (urlOrFilename.isEmpty) return;
    try {
      String url = urlOrFilename;
      if (!url.startsWith('http')) {
        // Es un archivo en el bucket
        url = _supabase.storage.from('capacitaciones').getPublicUrl(urlOrFilename);
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir $url';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirEncuesta(BuildContext context, Map<String, dynamic> cap) {
    int p1 = 0;
    int p2 = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(cap['titulo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              ),
              const Divider(height: 30),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const Text('1. ¿Entendió claramente los conceptos explicados en el material?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    RadioListTile(value: 1, groupValue: p1, onChanged: (v) => setModalState(() => p1 = v as int), title: const Text('Sí, completamente')),
                    RadioListTile(value: 2, groupValue: p1, onChanged: (v) => setModalState(() => p1 = v as int), title: const Text('No del todo')),
                    const SizedBox(height: 20),
                    const Text('2. ¿Qué aspecto le pareció más importante?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    RadioListTile(value: 1, groupValue: p2, onChanged: (v) => setModalState(() => p2 = v as int), title: const Text('La seguridad en planta')),
                    RadioListTile(value: 2, groupValue: p2, onChanged: (v) => setModalState(() => p2 = v as int), title: const Text('Las nuevas políticas')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (p1 == 0 || p2 == 0) ? null : () async {
                      Navigator.pop(ctx);
                      await _enviarEncuesta(cap['id'], {'p1': p1, 'p2': p2});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enviar Respuestas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviarEncuesta(String capacitacionId, Map<String, dynamic> respuestas) async {
    setState(() => _loading = true);
    try {
      await _supabase.from('capacitaciones_completadas').upsert({
        'capacitacion_id': capacitacionId,
        'empleado_id': widget.empleadoId,
        'completado': true,
        'respuestas_encuesta': jsonEncode(respuestas),
      }, onConflict: 'capacitacion_id, empleado_id');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encuesta enviada correctamente'), backgroundColor: Colors.green),
      );
      _fetchCapacitaciones();
    } catch (e) {
      debugPrint('Error enviar encuesta: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.rol.toLowerCase() == 'admin' || widget.rol.toLowerCase() == 'rrhh' || widget.rol.toLowerCase() == 'jefatura';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Capacitaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: const Color(0xFF0284C7)))
          : _capacitaciones.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _capacitaciones.length,
                  itemBuilder: (context, index) {
                    final cap = _capacitaciones[index];
                    return _buildCapacitacionCard(cap, isAdmin);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Sin capacitaciones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay cursos disponibles actualmente.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacitacionCard(Map<String, dynamic> cap, bool isAdmin) {
    bool completado = cap['completado'] ?? false;
    String fecha = cap['fecha'] ?? '';
    try {
      fecha = DateFormat('dd MMM yyyy', 'es_ES').format(DateTime.parse(fecha));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cap['titulo'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      const SizedBox(height: 4),
                      Text('Publicado el: $fecha', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
                if (!isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: completado ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      completado ? 'Completado' : 'Pendiente',
                      style: TextStyle(color: completado ? Colors.green : Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (cap['descripcion'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                cap['descripcion'],
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            if (isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, size: 20, color: Colors.lightBlue.shade400),
                    const SizedBox(width: 8),
                    Text(cap['estadisticas'], style: TextStyle(color: Colors.lightBlue.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _descargarPdf(cap['pdf_url']),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Material'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: completado ? null : () => _abrirEncuesta(context, cap),
                      icon: const Icon(Icons.assignment, size: 18),
                      label: Text(completado ? 'Lista' : 'Encuesta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completado ? Colors.grey.shade300 : const Color(0xFF0284C7),
                        foregroundColor: completado ? Colors.grey : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ],
        ),
      ),
    );
  }
}
