import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CapacitacionesPage extends StatefulWidget {
  final String rol;
  const CapacitacionesPage({super.key, required this.rol});

  @override
  State<CapacitacionesPage> createState() => _CapacitacionesPageState();
}

class _CapacitacionesPageState extends State<CapacitacionesPage> {
  // Datos MOCK simulando BD
  final List<Map<String, dynamic>> _capacitaciones = [
    {
      'id': '1',
      'titulo': 'Seguridad en Planta - Semana 22',
      'fecha': '25 Mayo 2026',
      'completado': false,
      'pdf_url': 'https://ejemplo.com/pdf',
      'estadisticas': '12/15 Empleados completaron'
    },
    {
      'id': '2',
      'titulo': 'Uso correcto de EPP',
      'fecha': '18 Mayo 2026',
      'completado': true,
      'pdf_url': 'https://ejemplo.com/pdf2',
      'estadisticas': '15/15 Empleados completaron'
    }
  ];

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.rol.toLowerCase() == 'admin' || widget.rol.toLowerCase() == 'rrhh' || widget.rol.toLowerCase() == 'jefatura';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Capacitaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        elevation: 0,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Formulario para RRHH (Subir PDF y Preguntas)'), behavior: SnackBarBehavior.floating),
                );
              },
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nueva Capacitación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _capacitaciones.length,
        itemBuilder: (context, index) {
          final cap = _capacitaciones[index];
          return _buildCapacitacionCard(cap, isAdmin);
        },
      ),
    );
  }

  Widget _buildCapacitacionCard(Map<String, dynamic> cap, bool isAdmin) {
    bool completado = cap['completado'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(cap['titulo'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                ),
                if (!isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: completado ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      completado ? 'Completado' : 'Pendiente',
                      style: TextStyle(color: completado ? Colors.green : Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Publicado el: ${cap['fecha']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 16),
            if (isAdmin) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.bar_chart, size: 16, color: Colors.purple.shade300),
                  const SizedBox(width: 6),
                  Text(cap['estadisticas'], style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.people, size: 16),
                label: const Text('Ver Resultados Detallados'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Abriendo PDF simulado...'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Leer Material'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: const Color(0xFF0D2137),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: completado ? null : () {
                        _abrirEncuesta(context, cap['titulo']);
                      },
                      icon: const Icon(Icons.assignment, size: 16),
                      label: Text(completado ? 'Encuesta Lista' : 'Tomar Encuesta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completado ? Colors.grey.shade300 : Colors.purple,
                        foregroundColor: completado ? Colors.grey : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _abrirEncuesta(BuildContext context, String titulo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('1. ¿Entendió las medidas de seguridad mencionadas en el PDF?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  RadioListTile(value: 1, groupValue: 0, onChanged: (v){}, title: const Text('Sí, completamente')),
                  RadioListTile(value: 2, groupValue: 0, onChanged: (v){}, title: const Text('No del todo')),
                  const SizedBox(height: 20),
                  const Text('2. ¿Qué EPP es obligatorio en planta?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  RadioListTile(value: 1, groupValue: 0, onChanged: (v){}, title: const Text('Casco y botas')),
                  RadioListTile(value: 2, groupValue: 0, onChanged: (v){}, title: const Text('Solo chaleco')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Encuesta enviada correctamente'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
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
    );
  }
}
