import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class AsistenciaPage extends StatefulWidget {
  const AsistenciaPage({super.key});

  @override
  State<AsistenciaPage> createState() => _AsistenciaPageState();
}

class _AsistenciaPageState extends State<AsistenciaPage> {
  bool _marcoEntrada = true;
  bool _marcoSalida = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Asistencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Reloj en tiempo real
            Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now()).toUpperCase(),
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Botón de Asistencia
            GestureDetector(
              onTap: () {
                if (_marcoEntrada && _marcoSalida) return;
                setState(() {
                  if (!_marcoEntrada) _marcoEntrada = true;
                  else if (!_marcoSalida) _marcoSalida = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registro guardado exitosamente'), behavior: SnackBarBehavior.floating),
                );
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _marcoEntrada && _marcoSalida ? Colors.grey.shade300 : AppColors.accent,
                  boxShadow: [
                    if (!(_marcoEntrada && _marcoSalida))
                      BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _marcoEntrada && _marcoSalida ? Icons.done_all : Icons.touch_app_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _marcoEntrada && _marcoSalida ? 'Completado' : (!_marcoEntrada ? 'Marcar Entrada' : 'Marcar Salida'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Historial de la Semana
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Historial de la Semana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  _buildHistorial('Lunes', '08:00 AM', '18:00 PM', true),
                  _buildHistorial('Martes', '07:55 AM', '18:05 PM', true),
                  _buildHistorial('Miércoles', '08:10 AM', '18:00 PM', true), // Tardanza
                  _buildHistorial('Hoy', _marcoEntrada ? '07:58 AM' : '--:--', _marcoSalida ? '18:01 PM' : '--:--', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorial(String dia, String entrada, String salida, bool pasado) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(dia, style: TextStyle(fontWeight: pasado ? FontWeight.normal : FontWeight.bold, color: pasado ? Colors.grey.shade500 : Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Entrada: $entrada', style: const TextStyle(fontSize: 12)),
                Text('Salida: $salida', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
