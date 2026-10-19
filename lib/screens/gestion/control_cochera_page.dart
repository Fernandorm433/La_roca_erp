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
  DateTime _diaSeleccionado = DateTime.now();
  int _vistaModo = 0; // 0: Vista Diaria (ideal móvil), 1: Matriz Mensual

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
          const SnackBar(content: Text('Error al guardar registro'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int get _diasEnMes {
    return DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0).day;
  }

  int get _totalPernoctanHoy {
    final strFecha = DateFormat('yyyy-MM-dd').format(_diaSeleccionado);
    int count = 0;
    for (var v in _vehiculos) {
      final idV = v['id'].toString();
      if (_registroPernoctes['${idV}_$strFecha'] == true) {
        count++;
      }
    }
    return count;
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
              const SizedBox(height: 14),
              // Selector de vista: Diaria (Móvil) vs Matriz (Mensual)
              _buildVistaSelector(isMobile),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_vistaModo == 0 ? _buildVistaDiaria(isMobile) : _buildTablaMensual()),
              ),
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
            child: Icon(Icons.garage_rounded, color: AppColors.primaryDark, size: isMobile ? 24 : 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro de Cochera',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unidades que pernoctan en la planta',
                  style: TextStyle(color: Colors.black54, fontSize: isMobile ? 12 : 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaSelector(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _vistaModo = 0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _vistaModo == 0 ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.today_rounded, size: 18, color: _vistaModo == 0 ? Colors.white : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Vista Diaria (Checklist)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _vistaModo == 0 ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _vistaModo = 1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _vistaModo == 1 ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_view_month_rounded, size: 18, color: _vistaModo == 1 ? Colors.white : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Matriz Mensual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _vistaModo == 1 ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VISTA DIARIA (Optimizada para celular: lista clara de unidades)
  // ─────────────────────────────────────────────────────────────
  Widget _buildVistaDiaria(bool isMobile) {
    final strFecha = DateFormat('yyyy-MM-dd').format(_diaSeleccionado);
    final countPernoctan = _totalPernoctanHoy;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Barra de navegación del día
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () {
                    setState(() {
                      _diaSeleccionado = _diaSeleccionado.subtract(const Duration(days: 1));
                      if (_diaSeleccionado.month != _mesSeleccionado.month) {
                        _mesSeleccionado = _diaSeleccionado;
                        _cargarDatos();
                      }
                    });
                  },
                ),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _diaSeleccionado,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setState(() {
                        _diaSeleccionado = d;
                        if (d.month != _mesSeleccionado.month) {
                          _mesSeleccionado = d;
                          _cargarDatos();
                        }
                      });
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 18, color: AppColors.primaryDark),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'es_ES').format(_diaSeleccionado).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    setState(() {
                      _diaSeleccionado = _diaSeleccionado.add(const Duration(days: 1));
                      if (_diaSeleccionado.month != _mesSeleccionado.month) {
                        _mesSeleccionado = _diaSeleccionado;
                        _cargarDatos();
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Contador resumen del día
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unidades en planta:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    '$countPernoctan de ${_vehiculos.length} vehículos',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de vehículos
          Expanded(
            child: _vehiculos.isEmpty
                ? const Center(child: Text("No hay vehículos registrados."))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _vehiculos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final v = _vehiculos[i];
                      final idV = v['id'].toString();
                      final bool marcado = _registroPernoctes['${idV}_$strFecha'] ?? false;
                      final nombreVehiculo = v['nombre_vehiculo'] ?? 'Vehículo';
                      final responsable = v['responsable'] ?? 'Sin asignar';
                      final tipo = v['tipo'] ?? 'Unidad';

                      return InkWell(
                        onTap: () => _togglePernocte(idV, _diaSeleccionado, marcado),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: marcado ? Colors.green.shade50.withOpacity(0.6) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: marcado ? Colors.green.shade400 : Colors.grey.shade200,
                              width: marcado ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: marcado ? Colors.green.shade100 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  tipo.toString().toLowerCase().contains('bomba')
                                      ? Icons.water_drop_rounded
                                      : Icons.local_shipping_rounded,
                                  color: marcado ? Colors.green.shade800 : Colors.grey.shade600,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombreVehiculo,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: marcado ? Colors.green.shade900 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Responsable: $responsable',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              // Switch / Indicador
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: marcado ? Colors.green.shade600 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      marcado ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: marcado ? Colors.white : Colors.grey.shade600,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      marcado ? 'EN PLANTA' : 'NO PERNOCTA',
                                      style: TextStyle(
                                        color: marcado ? Colors.white : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
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

  // ─────────────────────────────────────────────────────────────
  // MATRIZ MENSUAL (Vista de tabla general)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTablaMensual() {
    if (_vehiculos.isEmpty) {
      return const Center(child: Text("No hay vehículos registrados."));
    }

    final dias = _diasEnMes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Selector de mes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () {
                    setState(() {
                      _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month - 1);
                    });
                    _cargarDatos();
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy', 'es_ES').format(_mesSeleccionado).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    setState(() {
                      _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1);
                    });
                    _cargarDatos();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 14,
                  headingRowColor: MaterialStateProperty.all(AppColors.primaryDark.withOpacity(0.06)),
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
                        DataCell(Text(v['nombre_vehiculo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(v['responsable'] ?? '', style: const TextStyle(fontSize: 12))),
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
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    marcado ? Icons.check_circle_rounded : Icons.cancel_outlined,
                                    color: marcado ? Colors.green : Colors.red.withOpacity(0.25),
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
          ),
        ],
      ),
    );
  }
}
