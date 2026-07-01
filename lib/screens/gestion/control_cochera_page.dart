import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class ControlCocheraPage extends StatefulWidget {
  const ControlCocheraPage({super.key});

  @override
  State<ControlCocheraPage> createState() => _ControlCocheraPageState();
}

class _ControlCocheraPageState extends State<ControlCocheraPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _mesSeleccionado = DateTime.now();

  List<Map<String, dynamic>> _vehiculos = [];
  // Mapa para busqueda rápida de fechas pernoctadas: "idVehiculo_YYYY-MM-DD" -> bool
  final Map<String, bool> _registroPernoctes = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar vehículos
      final vData = await supabase
          .from('vehiculos_maestro')
          .select()
          .order('tipo')
          .order('nombre_vehiculo');
      
      _vehiculos = List<Map<String, dynamic>>.from(vData);

      // Cargar registros del mes actual
      final sInicio = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, 1);
      final sFin = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0);
      
      final fmtDate = DateFormat('yyyy-MM-dd');

      final cData = await supabase
          .from('registro_cochera')
          .select('fecha, id_vehiculo, pernocto')
          .gte('fecha', fmtDate.format(sInicio))
          .lte('fecha', fmtDate.format(sFin));

      _registroPernoctes.clear();
      for (var row in cData) {
        if (row['pernocto'] == true) {
          final idV = row['id_vehiculo'].toString();
          final fecha = row['fecha'].toString();
          _registroPernoctes['${idV}_$fecha'] = true;
        }
      }
    } catch (e) {
      debugPrint("Error al cargar cochera: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePernocte(String idVehiculo, DateTime fecha, bool currentVal) async {
    final key = '${idVehiculo}_${DateFormat('yyyy-MM-dd').format(fecha)}';
    // Optimistic UI update
    setState(() {
      if (currentVal) {
        _registroPernoctes.remove(key);
      } else {
        _registroPernoctes[key] = true;
      }
    });

    try {
      if (currentVal) {
        // Eliminar
        await supabase
            .from('registro_cochera')
            .delete()
            .eq('id_vehiculo', idVehiculo)
            .eq('fecha', DateFormat('yyyy-MM-dd').format(fecha));
      } else {
        // Insertar
        await supabase.from('registro_cochera').upsert({
          'id_vehiculo': idVehiculo,
          'fecha': DateFormat('yyyy-MM-dd').format(fecha),
          'pernocto': true,
        });
      }
    } catch (e) {
      debugPrint("Error toggle: $e");
      // Revertir
      setState(() {
        if (currentVal) {
          _registroPernoctes[key] = true;
        } else {
          _registroPernoctes.remove(key);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar registro'), backgroundColor: Colors.red));
      }
    }
  }

  int get _diasEnMes {
    return DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0).day;
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTabla(),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registro de Cochera',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unidades que pernoctan en la planta',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month - 1);
                  });
                  _cargarDatos();
                },
              ),
              Text(
                DateFormat('MMMM yyyy', 'es_ES').format(_mesSeleccionado).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1);
                  });
                  _cargarDatos();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabla() {
    if (_vehiculos.isEmpty) {
      return const Center(child: Text("No hay vehículos registrados."));
    }

    final dias = _diasEnMes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
            columns: [
              const DataColumn(label: Text('VEHÍCULO', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('RESPONSABLE', style: TextStyle(fontWeight: FontWeight.bold))),
              for (int i = 1; i <= dias; i++)
                DataColumn(
                  label: Text(
                    i.toString().padLeft(2, '0'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
            rows: _vehiculos.map((v) {
              final idV = v['id'].toString();
              return DataRow(
                cells: [
                  DataCell(Text(v['nombre_vehiculo'] ?? '')),
                  DataCell(Text(v['responsable'] ?? '')),
                  for (int i = 1; i <= dias; i++) ...[
                    DataCell(
                      Builder(builder: (context) {
                        final fechaObj = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, i);
                        final strFecha = DateFormat('yyyy-MM-dd').format(fechaObj);
                        final bool marcado = _registroPernoctes['${idV}_$strFecha'] ?? false;
                        
                        return InkWell(
                          onTap: () => _togglePernocte(idV, fechaObj, marcado),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              marcado ? Icons.check : Icons.close,
                              color: marcado ? Colors.green : Colors.red.withOpacity(0.3),
                              size: 20,
                            ),
                          ),
                        );
                      }),
                    )
                  ]
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
