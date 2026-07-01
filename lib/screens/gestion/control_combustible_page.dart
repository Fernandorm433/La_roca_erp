import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class ControlCombustiblePage extends StatefulWidget {
  const ControlCombustiblePage({super.key});

  @override
  State<ControlCombustiblePage> createState() => _ControlCombustiblePageState();
}

class _ControlCombustiblePageState extends State<ControlCombustiblePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _mesSeleccionado = DateTime.now();

  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _registros = [];

  // Variables formulario
  DateTime _fechaForm = DateTime.now();
  String? _vehiculoSeleccionado;
  final _operadorController = TextEditingController();
  final _galonesController = TextEditingController();
  final _montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final vData = await supabase.from('vehiculos_maestro').select().order('nombre_vehiculo');
      _vehiculos = List<Map<String, dynamic>>.from(vData);

      final sInicio = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, 1);
      final sFin = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0);
      final fmtDate = DateFormat('yyyy-MM-dd');

      final rData = await supabase
          .from('registro_combustible')
          .select('*, vehiculos_maestro(nombre_vehiculo)')
          .gte('fecha', fmtDate.format(sInicio))
          .lte('fecha', fmtDate.format(sFin))
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);

      _registros = List<Map<String, dynamic>>.from(rData);
    } catch (e) {
      debugPrint("Error al cargar combustible: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarRegistro() async {
    if (_vehiculoSeleccionado == null || _galonesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete vehículo y galones')));
      return;
    }

    try {
      await supabase.from('registro_combustible').insert({
        'fecha': DateFormat('yyyy-MM-dd').format(_fechaForm),
        'id_vehiculo': _vehiculoSeleccionado,
        'operador': _operadorController.text,
        'galones': double.tryParse(_galonesController.text) ?? 0,
        'monto_total': double.tryParse(_montoController.text) ?? 0,
      });

      _operadorController.clear();
      _galonesController.clear();
      _montoController.clear();
      _cargarDatos();
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado exitosamente'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _eliminarRegistro(String id) async {
    try {
      await supabase.from('registro_combustible').delete().eq('id', id);
      _cargarDatos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildForm()),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Control de Combustible', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text('Registro diario de abastecimiento', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nuevo Registro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _fechaForm, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _fechaForm = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Fecha', border: OutlineInputBorder()),
              child: Text(DateFormat('dd / MM / yyyy').format(_fechaForm)),
            ),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Vehículo', border: OutlineInputBorder()),
            value: _vehiculoSeleccionado,
            items: _vehiculos.map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['nombre_vehiculo']))).toList(),
            onChanged: (v) => setState(() => _vehiculoSeleccionado = v),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _operadorController,
            decoration: const InputDecoration(labelText: 'Operador / Conductor', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _galonesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Galones', border: OutlineInputBorder(), suffixText: 'gal'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _montoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto Total', border: OutlineInputBorder(), prefixText: 'S/ '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _guardarRegistro,
              child: const Text('Guardar Registro', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () { setState(() => _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month - 1)); _cargarDatos(); }),
              Text(DateFormat('MMMM yyyy', 'es_ES').format(_mesSeleccionado).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { setState(() => _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1)); _cargarDatos(); }),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _registros.length,
              itemBuilder: (context, i) {
                final r = _registros[i];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: AppColors.background,
                  child: ListTile(
                    title: Text('${r['vehiculos_maestro']?['nombre_vehiculo'] ?? 'Desc'} - ${r['galones']} gal', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r['fecha']} | Operador: ${r['operador'] ?? '-'} | Monto: S/ ${r['monto_total']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarRegistro(r['id']),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
