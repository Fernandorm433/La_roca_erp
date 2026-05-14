import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class ProgramacionPage extends StatefulWidget {
  const ProgramacionPage({super.key});
  @override
  State<ProgramacionPage> createState() => _ProgramacionPageState();
}

class _ProgramacionPageState extends State<ProgramacionPage> {
  final supabase = Supabase.instance.client;
  List ventas = [];
  bool loading = true;
  DateTime fechaSeleccionada = DateTime.now();
  int filtroActivo = 0;
  bool vistaTabla = false;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future cargar() async {
    setState(() => loading = true);
    String fechaFiltro = fechaSeleccionada.toIso8601String().split('T')[0];
    try {
      final data = await supabase
          .from("ventas_programacion")
          .select()
          .eq('fecha_entrega', fechaFiltro)
          .order("hora_entrega");

      final asignaciones = await supabase.from("asignacion_bombas").select();
      Map<String, String> mapaBombas = {
        for (var a in asignaciones)
          a['id_venta'].toString(): a['bomba_asignada'].toString(),
      };

      for (var v in data) {
        String id = v['id']?.toString() ?? '';
        if (id.isEmpty || id == 'null')
          id = v['numero_atencion']?.toString() ?? '';
        v['bomba_asignada_real'] = mapaBombas[id];
      }

      if (mounted) {
        setState(() {
          ventas = data;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );
    if (seleccion != null && seleccion != fechaSeleccionada) {
      setState(() {
        fechaSeleccionada = seleccion;
        filtroActivo = 2;
      });
      cargar();
    }
  }

  String _obtenerBombas(Map<String, dynamic> v) {
    String asignadaApp = v['bomba_asignada_real']?.toString() ?? '';
    if (asignadaApp.isNotEmpty && asignadaApp != 'null') return asignadaApp;

    List<String> bombasActivas = [];
    final Map<String, String> mapaColumnas = {
      'CBP 12': 'cbp_12',
      'CBP 13': 'cbp_13',
      'CBP 15': 'cbp_15',
      'CBP 16': 'cbp_16',
      'CBP 17': 'cbp_17',
      'CBP 18': 'cbp_18',
      'CBP 21': 'cbp_21',
    };

    mapaColumnas.forEach((nombre, columna) {
      var valor = v[columna];
      if (valor != null) {
        String vt = valor.toString().trim().toUpperCase();
        double? numero = double.tryParse(vt);
        bool esCero = (numero != null && numero == 0);

        if (vt.isNotEmpty &&
            !esCero &&
            vt != 'NO' &&
            vt != 'FALSE' &&
            vt != 'NULL' &&
            vt != '-' &&
            vt != 'NA' &&
            vt != 'N/A') {
          bombasActivas.add(nombre);
        }
      }
    });

    String bombaGeneral = v['bombas']?.toString().trim().toUpperCase() ?? '';
    if (bombaGeneral == 'DIRECTO' || bombaGeneral == 'ALQUILADO') {
      bombasActivas.add(bombaGeneral);
    } else if (bombaGeneral == 'SI' && bombasActivas.isEmpty)
      bombasActivas.add('Asignada');

    return bombasActivas.isNotEmpty ? bombasActivas.join(', ') : '-';
  }

  Future<void> _abrirGoogleMaps(String direccion, String coordenadas) async {
    String query = coordenadas.isNotEmpty ? coordenadas : direccion;
    if (query.isEmpty) return;
    if (query.contains('http')) {
      final uri = Uri.parse(query);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url))
      await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _buildVistaExcel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
            columnSpacing: 25,
            dataRowMaxHeight: 65,
            columns: const [
              DataColumn(
                label: Text(
                  'Hora',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Cliente / Obra',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Vol (m³)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Diseño F\'c',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Huso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Elemento',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Slump',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Bomba(s)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
            rows: ventas.map((v) {
              bool esCancelado =
                  v["numero_atencion"]?.toString() == "0" ||
                  v["estado"]?.toString().toUpperCase() == "CANCELADO";

              return DataRow(
                color: WidgetStateProperty.resolveWith<Color?>((
                  Set<WidgetState> states,
                ) {
                  if (esCancelado) return Colors.red.shade50;
                  return null;
                }),
                cells: [
                  DataCell(
                    Text(
                      v['hora_entrega'] ?? '--:--',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: esCancelado
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Text(
                        esCancelado
                            ? "🚫 CANCELADA - ${v['nombre_razon_social'] ?? 'Sin Cliente'}"
                            : v['nombre_razon_social'] ?? 'Sin Cliente',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          color: esCancelado
                              ? Colors.red.shade900
                              : Colors.black87,
                          fontWeight: esCancelado
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      v['volumen']?.toString() ?? '0',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: esCancelado ? Colors.red : Colors.teal,
                      ),
                    ),
                  ),
                  DataCell(Text(v['diseno'] ?? '-')),
                  DataCell(Text(v['huso']?.toString() ?? '-')),
                  DataCell(Text(v['elemento'] ?? '-')),
                  DataCell(Text(v['slump'] ?? '-')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _obtenerBombas(v),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0);
  }

  Widget _detalleGrid(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          valor.isEmpty ? "-" : valor,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text(
            "Programación",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          floating: true,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: Icon(
                vistaTabla
                    ? Icons.view_agenda_rounded
                    : Icons.table_chart_rounded,
                color: AppColors.accent,
              ),
              tooltip: "Cambiar Vista",
              onPressed: () => setState(() {
                vistaTabla = !vistaTabla;
              }),
            ),
            const SizedBox(width: 10),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                _buildFiltroChip("Hoy", 0, () {
                  setState(() {
                    fechaSeleccionada = DateTime.now();
                    filtroActivo = 0;
                  });
                  cargar();
                }),
                const SizedBox(width: 10),
                _buildFiltroChip("Mañana", 1, () {
                  setState(() {
                    fechaSeleccionada = DateTime.now().add(
                      const Duration(days: 1),
                    );
                    filtroActivo = 1;
                  });
                  cargar();
                }),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _seleccionarFecha(context),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    filtroActivo == 2
                        ? "${fechaSeleccionada.day}/${fechaSeleccionada.month}"
                        : "Calendario",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: filtroActivo == 2
                        ? AppColors.accent
                        : Colors.white,
                    foregroundColor: filtroActivo == 2
                        ? Colors.white
                        : Colors.black87,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ).animate().fade().slideY(begin: -0.1, end: 0),
          ),
        ),

        if (loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ventas.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  Text(
                    "No hay programación para esta fecha.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else if (vistaTabla)
          SliverToBoxAdapter(child: _buildVistaExcel())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final v = ventas[index];
              bool esCancelado =
                  v["numero_atencion"]?.toString() == "0" ||
                  v["estado"]?.toString().toUpperCase() == "CANCELADO";

              return Card(
                color: esCancelado ? Colors.red.shade50 : Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: esCancelado
                        ? Colors.red.shade200
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: esCancelado
                        ? Colors.red.shade100
                        : Colors.indigo.shade50,
                    child: Icon(
                      esCancelado ? Icons.cancel : Icons.access_time,
                      color: esCancelado ? Colors.red : AppColors.accent,
                    ),
                  ),
                  title: Text(
                    esCancelado
                        ? "🚫 CANCELADA - ${v["nombre_razon_social"] ?? "Sin Cliente"}"
                        : v["nombre_razon_social"] ?? "Cliente No Registrado",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: esCancelado ? Colors.red.shade900 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    "Hora: ${v["hora_entrega"] ?? '--:--'} | Vol: ${v["volumen"] ?? 0} m³ | Huso: ${v["huso"] ?? '-'}",
                    style: TextStyle(
                      color: esCancelado
                          ? Colors.red.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 30,
                            runSpacing: 10,
                            children: [
                              _detalleGrid(
                                "Diseño",
                                v["diseno"]?.toString() ?? "",
                              ),
                              _detalleGrid(
                                "Elemento",
                                v["elemento"]?.toString() ?? "",
                              ),
                              _detalleGrid("Huso", v["huso"]?.toString() ?? ""),
                              _detalleGrid(
                                "Slump",
                                v["slump"]?.toString() ?? "",
                              ),
                              _detalleGrid(
                                "Bombas Asignadas",
                                _obtenerBombas(v),
                              ),
                              _detalleGrid(
                                "Tiempo Vaciado",
                                v["tiempo_estimado_vaciado"]?.toString() ?? "",
                              ),
                            ],
                          ),
                          const Divider(height: 30),
                          InkWell(
                            onTap: () => _abrirGoogleMaps(
                              v["direccion"]?.toString() ?? "",
                              v["mapa_coordenadas"]?.toString() ?? "",
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Ubicación (Abrir Maps)",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        v["direccion"]?.toString() ??
                                            "Sin dirección",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.blueAccent,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.open_in_new,
                                  color: Colors.blueAccent,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
            }, childCount: ventas.length),
          ),
      ],
    );
  }

  Widget _buildFiltroChip(String texto, int index, VoidCallback onTap) {
    bool activo = filtroActivo == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? AppColors.primaryDark : Colors.grey.shade300,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: activo ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
