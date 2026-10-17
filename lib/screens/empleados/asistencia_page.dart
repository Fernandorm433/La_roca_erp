import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

class AsistenciaPage extends StatefulWidget {
  final String empleadoId;
  const AsistenciaPage({super.key, required this.empleadoId});

  @override
  State<AsistenciaPage> createState() => _AsistenciaPageState();
}

class _AsistenciaPageState extends State<AsistenciaPage> {
  final _supabase = Supabase.instance.client;
  
  bool _loading = true;
  String? _asistenciaIdHoy;
  String? _horaEntrada;
  String? _horaSalida;
  
  List<Map<String, dynamic>> _historial = [];

  @override
  void initState() {
    super.initState();
    _fetchAsistencia();
  }

  Future<void> _fetchAsistencia() async {
    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 1. Obtener registro de hoy
      final dataHoy = await _supabase
          .from('asistencia_empleados')
          .select()
          .eq('empleado_id', widget.empleadoId)
          .eq('fecha', hoy)
          .maybeSingle();

      if (dataHoy != null) {
        _asistenciaIdHoy = dataHoy['id']?.toString();
        _horaEntrada = dataHoy['hora_entrada']?.toString();
        _horaSalida = dataHoy['hora_salida']?.toString();
      }

      // 2. Obtener historial de los últimos 7 días (excluyendo hoy o incluyéndolo para ver todo)
      final hace7Dias = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7)));
      final dataHistorial = await _supabase
          .from('asistencia_empleados')
          .select()
          .eq('empleado_id', widget.empleadoId)
          .gte('fecha', hace7Dias)
          .order('fecha', ascending: false);

      if (mounted) {
        setState(() {
          _historial = List<Map<String, dynamic>>.from(dataHistorial);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch asistencia: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _marcarAsistencia() async {
    if (_horaEntrada != null && _horaSalida != null) return;
    
    setState(() => _loading = true);
    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ahora = DateFormat('HH:mm').format(DateTime.now());

      if (_horaEntrada == null) {
        // Marcar Entrada
        final res = await _supabase.from('asistencia_empleados').insert({
          'empleado_id': widget.empleadoId,
          'fecha': hoy,
          'hora_entrada': ahora,
          'estado': 'Presente'
        }).select().single();
        
        _asistenciaIdHoy = res['id'].toString();
        _horaEntrada = ahora;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada registrada exitosamente'), backgroundColor: Colors.green));
      } else if (_horaSalida == null) {
        // Marcar Salida
        await _supabase.from('asistencia_empleados').update({
          'hora_salida': ahora,
        }).eq('id', _asistenciaIdHoy!);
        
        _horaSalida = ahora;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salida registrada exitosamente'), backgroundColor: Colors.green));
      }

      await _fetchAsistencia(); // Refrescar historial
    } catch (e) {
      debugPrint('Error marcando asistencia: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool completado = _horaEntrada != null && _horaSalida != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Asistencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Reloj en tiempo real
                  Text(
                    DateFormat('HH:mm').format(DateTime.now()),
                    style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color, letterSpacing: 2),
                  ),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now()).toUpperCase(),
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 40),

                  // Botón de Asistencia
                  GestureDetector(
                    onTap: _loading ? null : _marcarAsistencia,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: completado
                            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                            : LinearGradient(colors: [_horaEntrada == null ? AppColors.accent : Colors.orange, _horaEntrada == null ? const Color(0xFF1AA88A) : Colors.deepOrange]),
                        boxShadow: [
                          if (!completado)
                            BoxShadow(
                              color: (_horaEntrada == null ? AppColors.accent : Colors.orange).withOpacity(0.4),
                              blurRadius: 24,
                              spreadRadius: 6,
                              offset: const Offset(0, 8),
                            )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            completado ? Icons.done_all : (_horaEntrada == null ? Icons.login_rounded : Icons.logout_rounded),
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            completado ? 'Turno\nCompletado' : (_horaEntrada == null ? 'Marcar\nEntrada' : 'Marcar\nSalida'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, height: 1.2),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Historial de la Semana
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Últimos 7 días', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 20),
                        if (_historial.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text('No hay registros recientes', style: TextStyle(color: Colors.grey.shade500)),
                            ),
                          )
                        else
                          ..._historial.map((registro) {
                            String f = registro['fecha'] ?? '';
                            try {
                              f = DateFormat('EEEE dd MMM', 'es_ES').format(DateTime.parse(f));
                            } catch (_) {}
                            return _buildHistorial(
                              f,
                              registro['hora_entrada'] ?? '--:--',
                              registro['hora_salida'] ?? '--:--',
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHistorial(String dia, String entrada, String salida) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              dia, 
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _BadgeHora(label: 'Entrada', hora: entrada, color: Colors.green),
                const SizedBox(width: 8),
                _BadgeHora(label: 'Salida', hora: salida, color: Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeHora extends StatelessWidget {
  final String label;
  final String hora;
  final Color color;

  const _BadgeHora({required this.label, required this.hora, required this.color});

  @override
  Widget build(BuildContext context) {
    final bool isMissing = hora == '--:--';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMissing ? Colors.grey.shade100 : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMissing ? Colors.grey.shade300 : color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: isMissing ? Colors.grey.shade500 : color, fontWeight: FontWeight.bold)),
          Text(hora, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMissing ? Colors.grey.shade500 : Theme.of(context).textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }
}
