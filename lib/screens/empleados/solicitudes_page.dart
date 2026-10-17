import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/notificacion_service.dart';

class SolicitudesPage extends StatefulWidget {
  final String empleadoId;
  const SolicitudesPage({super.key, required this.empleadoId});

  @override
  State<SolicitudesPage> createState() => _SolicitudesPageState();
}

class _SolicitudesPageState extends State<SolicitudesPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _solicitudes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSolicitudes();
  }

  Future<void> _fetchSolicitudes() async {
    try {
      final data = await _supabase
          .from('solicitudes_empleados')
          .select()
          .eq('empleado_id', widget.empleadoId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _solicitudes = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch solicitudes: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _mostrarFormularioNuevaSolicitud() {
    String tipoSeleccionado = 'Vacaciones';
    final tipos = ['Vacaciones', 'Permiso Médico', 'Asunto Personal', 'Otros'];
    DateTime fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
    final comentariosCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Nueva Solicitud', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: tipoSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Solicitud',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => tipoSeleccionado = v!),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (dt != null) {
                          setModalState(() => fechaSeleccionada = dt);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha Solicitada',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(DateFormat('dd MMM yyyy', 'es_ES').format(fechaSeleccionada)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: comentariosCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comentarios adicionales (Opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _enviarSolicitud(
                            tipoSeleccionado,
                            DateFormat('yyyy-MM-dd').format(fechaSeleccionada),
                            comentariosCtrl.text.trim(),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF004899),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Enviar a RRHH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enviarSolicitud(String tipo, String fecha, String comentarios) async {
    setState(() => _loading = true);
    try {
      await _supabase.from('solicitudes_empleados').insert({
        'empleado_id': widget.empleadoId,
        'tipo_solicitud': tipo,
        'fecha_solicitada': fecha,
        'estado': 'Pendiente',
        'comentarios': comentarios,
      });
      
      // Enviar notificación a RRHH y Admins
      await NotificationService().notificarPorRoles(
        roles: ['rrhh', 'admin'],
        titulo: 'Nueva Solicitud: $tipo',
        cuerpo: 'Un empleado ha enviado una solicitud para el $fecha.',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada exitosamente'), backgroundColor: Colors.green),
      );
      _fetchSolicitudes();
    } catch (e) {
      debugPrint('Error enviando solicitud: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mis Solicitudes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormularioNuevaSolicitud,
        backgroundColor: const Color(0xFF004899),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Solicitud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: const Color(0xFF004899)))
          : _solicitudes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _solicitudes.length,
                  itemBuilder: (context, index) {
                    final sol = _solicitudes[index];
                    return _buildSolicitudCard(
                      sol['tipo_solicitud'] ?? 'Sin tipo',
                      sol['fecha_solicitada'] ?? '',
                      sol['estado'] ?? 'Pendiente',
                      sol['comentarios'] ?? '',
                      sol['created_at'] ?? '',
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Sin solicitudes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'No has enviado solicitudes a RRHH.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(String tipo, String fecha, String estado, String comentarios, String createdAt) {
    Color colorEstado = Colors.orange;
    IconData iconEstado = Icons.pending_actions;
    
    if (estado.toLowerCase() == 'aprobado') {
      colorEstado = Colors.green;
      iconEstado = Icons.check_circle;
    } else if (estado.toLowerCase() == 'rechazado') {
      colorEstado = Colors.red;
      iconEstado = Icons.cancel;
    }

    String fechaFmt = fecha;
    try {
      final dt = DateTime.parse(fecha);
      fechaFmt = DateFormat('dd MMM yyyy', 'es_ES').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_document, color: Colors.blue.shade400, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Solicitado para: $fechaFmt', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorEstado.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconEstado, size: 14, color: colorEstado),
                      const SizedBox(width: 4),
                      Text(estado.toUpperCase(), style: TextStyle(color: colorEstado, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            if (comentarios.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                '"$comentarios"',
                style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
