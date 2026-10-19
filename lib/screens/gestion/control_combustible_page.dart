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
  int _mobileTab = 0; // 0: Formulario, 1: Historial

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

  @override
  void dispose() {
    _operadorController.dispose();
    _galonesController.dispose();
    _montoController.dispose();
    super.dispose();
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
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado exitosamente'), backgroundColor: Colors.green),
      );
      // En móvil, pasamos a la pestaña de historial para ver el resultado
      setState(() => _mobileTab = 1);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _eliminarRegistro(String id) async {
    try {
      await supabase.from('registro_combustible').delete().eq('id', id);
      _cargarDatos();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              if (isMobile) ...[
                // Selector de pestañas móvil
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _mobileTab = 0),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _mobileTab == 0 ? AppColors.primaryDark : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, size: 18, color: _mobileTab == 0 ? Colors.white : Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Nuevo Registro',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _mobileTab == 0 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _mobileTab = 1),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _mobileTab == 1 ? AppColors.primaryDark : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.list_alt_rounded, size: 18, color: _mobileTab == 1 ? Colors.white : Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Historial (${_registros.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _mobileTab == 1 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _mobileTab == 0
                      ? SingleChildScrollView(child: _buildForm(isMobile))
                      : (_isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildList(isMobile)),
                ),
              ] else ...[
                // Vista Escritorio / Tablet
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: SingleChildScrollView(child: _buildForm(false))),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildList(false),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_gas_station_rounded, color: AppColors.primaryDark, size: isMobile ? 24 : 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control de Combustible',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Registro diario de abastecimiento',
                  style: TextStyle(color: Colors.black54, fontSize: isMobile ? 12 : 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nuevo Registro', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _fechaForm,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _fechaForm = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
              ),
              child: Text(DateFormat('dd / MM / yyyy').format(_fechaForm)),
            ),
          ),
          const SizedBox(height: 14),
          
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Vehículo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_car_rounded, size: 20),
            ),
            value: _vehiculoSeleccionado,
            items: _vehiculos
                .map((v) => DropdownMenuItem(
                      value: v['id'].toString(),
                      child: Text(v['nombre_vehiculo'], overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _vehiculoSeleccionado = v),
          ),
          const SizedBox(height: 14),
          
          TextFormField(
            controller: _operadorController,
            decoration: const InputDecoration(
              labelText: 'Operador / Conductor',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _galonesController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Galones',
                    border: OutlineInputBorder(),
                    suffixText: 'gal',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto Total',
                    border: OutlineInputBorder(),
                    prefixText: 'S/ ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _guardarRegistro,
              label: const Text(
                'Guardar Registro',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildList(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month - 1));
                  _cargarDatos();
                },
              ),
              Text(
                DateFormat('MMMM yyyy', 'es_ES').format(_mesSeleccionado).toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1));
                  _cargarDatos();
                },
              ),
            ],
          ),
          const Divider(),
          if (_registros.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  Icon(Icons.local_gas_station_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'No hay registros para este mes',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _registros.length,
                itemBuilder: (context, i) {
                  final r = _registros[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryDark, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r['vehiculos_maestro']?['nombre_vehiculo'] ?? 'Vehículo'} — ${r['galones']} gal',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${r['fecha']} | Operador: ${r['operador'] ?? '-'}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                if (r['monto_total'] != null && (double.tryParse(r['monto_total'].toString()) ?? 0) > 0)
                                  Text(
                                    'Total: S/ ${r['monto_total']}',
                                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _eliminarRegistro(r['id']),
                          ),
                        ],
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
