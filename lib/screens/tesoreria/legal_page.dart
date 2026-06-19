import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _documentos = [];
  
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await _sb.from('tesoreria_legal').select().order('fecha_vencimiento', ascending: true);
      if (mounted) setState(() {
        _documentos = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _obtenerColorSemaforo(String? fechaStr) {
    if (fechaStr == null) return Colors.grey;
    final fechaVenc = DateTime.tryParse(fechaStr);
    if (fechaVenc == null) return Colors.grey;
    
    final hoy = DateTime.now();
    final difDias = fechaVenc.difference(hoy).inDays;
    
    if (difDias < 0) return Colors.red; // Vencido
    if (difDias <= 30) return Colors.orange; // Por vencer
    return Colors.green; // Vigente
  }

  void _abrirFormulario() {
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipoDoc = 'CONTRATO';
    DateTime? fechaVencimiento;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (context, setStateModal) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nuevo Documento Legal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: tipoDoc,
                  decoration: const InputDecoration(labelText: 'Tipo de Documento', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'CONTRATO', child: Text('Contrato')),
                    DropdownMenuItem(value: 'PERMISO', child: Text('Permiso / Licencia')),
                    DropdownMenuItem(value: 'TRIBUTARIO', child: Text('Tributario / SUNAT')),
                    DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                  ],
                  onChanged: (v) => setStateModal(() => tipoDoc = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título del Documento', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción / Detalles', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de Vencimiento'),
                  subtitle: Text(fechaVencimiento != null ? DateFormat('yyyy-MM-dd').format(fechaVencimiento!) : 'No seleccionada'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (date != null) setStateModal(() => fechaVencimiento = date);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await _sb.from('tesoreria_legal').insert({
                        'titulo': tituloCtrl.text,
                        'descripcion': descCtrl.text,
                        'tipo_documento': tipoDoc,
                        'fecha_vencimiento': fechaVencimiento != null ? DateFormat('yyyy-MM-dd').format(fechaVencimiento!) : null,
                      });
                      if (context.mounted) Navigator.pop(context);
                      _cargar();
                    },
                    child: const Text('GUARDAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Control de Vencimientos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('AÑADIR', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                onPressed: _abrirFormulario,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _documentos.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, i) {
              final d = _documentos[i];
              final Color colorSemaforo = _obtenerColorSemaforo(d['fecha_vencimiento']);
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorSemaforo.withValues(alpha: 0.2),
                    child: Icon(Icons.gavel, color: colorSemaforo),
                  ),
                  title: Text(d['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${d['tipo_documento']} - Vence: ${d['fecha_vencimiento'] ?? "Sin fecha"}'),
                  trailing: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: colorSemaforo, shape: BoxShape.circle),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
