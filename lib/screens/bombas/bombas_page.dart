import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';

class GestorBombasPage extends StatefulWidget {
  const GestorBombasPage({super.key});
  @override
  State<GestorBombasPage> createState() => _GestorBombasPageState();
}

class _GestorBombasPageState extends State<GestorBombasPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool loading = true;
  DateTime fechaSeleccionada = DateTime.now();

  final List<String> columnasBombas = [
    'POR ASIGNAR',
    'CBP 12',
    'CBP 13',
    'CBP 15',
    'CBP 16',
    'CBP 17',
    'CBP 18',
    'CBP 21',
    'DIRECTO',
    'ALQUILADO',
  ];

  final Map<String, String> mapaColumnasDB = {
    'CBP 12': 'cbp_12',
    'CBP 13': 'cbp_13',
    'CBP 15': 'cbp_15',
    'CBP 16': 'cbp_16',
    'CBP 17': 'cbp_17',
    'CBP 18': 'cbp_18',
    'CBP 21': 'cbp_21',
  };

  Map<String, List<dynamic>> obrasPorBomba = {};
  Map<String, double> volumenPorBomba = {};
  late TabController _tabController;

  final Set<String> columnasManuales = {};
  final Map<String, double> duracionesManuales = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: columnasBombas.length, vsync: this);
    cargarObras();
  }

  List<String> _detectarTodasLasBombas(Map<String, dynamic> v) {
    List<String> detectadas = [];
    mapaColumnasDB.forEach((nombreBonito, columnaDB) {
      var valor = v[columnaDB];
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
          detectadas.add(nombreBonito);
        }
      }
    });

    String general = v['bombas']?.toString().toUpperCase().trim() ?? '';
    if (general == 'DIRECTO') detectadas.add('DIRECTO');
    if (general == 'ALQUILADO') detectadas.add('ALQUILADO');
    return detectadas;
  }

  String _obtenerIdSeguro(Map<String, dynamic> obra) {
    String id = obra['id']?.toString() ?? '';
    if (id.isEmpty || id == 'null') {
      id = obra['numero_atencion']?.toString() ?? '';
    }
    return id;
  }

  Future cargarObras() async {
    setState(() => loading = true);
    String fechaFiltro = fechaSeleccionada.toIso8601String().split('T')[0];

    try {
      final ventasData = await supabase
          .from("ventas_programacion")
          .select()
          .eq('fecha_entrega', fechaFiltro)
          .order("hora_entrega");
      final asignacionesData = await supabase
          .from("asignacion_bombas")
          .select();

      Map<String, dynamic> asignacionesMap = {
        for (var a in asignacionesData) a['id_venta'].toString(): a,
      };

      Map<String, List<dynamic>> agrupado = {
        for (var b in columnasBombas) b: [],
        for (var b in columnasManuales) b: [],
      };
      Map<String, double> volumenCalculado = {
        for (var b in columnasBombas) b: 0.0,
        for (var b in columnasManuales) b: 0.0,
      };

      for (var v in ventasData) {
        if (v["numero_atencion"]?.toString() == "0" ||
            v["estado"]?.toString().toUpperCase() == "CANCELADO")
          continue;
        double volObra =
            double.tryParse(v["volumen"]?.toString() ?? '0') ?? 0.0;

        String idObra = _obtenerIdSeguro(v);
        v['id_seguro'] = idObra;

        if (duracionesManuales.containsKey(idObra)) {
          v['duracion_manual'] = duracionesManuales[idObra];
        }

        if (asignacionesMap.containsKey(idObra)) {
          var asignacion = asignacionesMap[idObra];
          v['bomba_asignada_real'] = asignacion['bomba_asignada'];
          v['hora_entrega_editada'] =
              asignacion['hora_entrega_real'] ?? v['hora_entrega'];
          v['estado_obra'] = asignacion['estado_obra'] ?? 'Pendiente';
        } else {
          v['bomba_asignada_real'] = null;
          v['hora_entrega_editada'] = v['hora_entrega'];
          v['estado_obra'] = 'Pendiente';
        }

        String bombaDefinitiva = v['bomba_asignada_real'] ?? '';

        if (bombaDefinitiva.isNotEmpty) {
          if (!agrupado.containsKey(bombaDefinitiva)) {
             agrupado[bombaDefinitiva] = [];
             volumenCalculado[bombaDefinitiva] = 0.0;
          }
          agrupado[bombaDefinitiva]!.add(v);
          volumenCalculado[bombaDefinitiva] =
              (volumenCalculado[bombaDefinitiva] ?? 0.0) + volObra;
        } else {
          List<String> sugeridas = _detectarTodasLasBombas(v);
          if (sugeridas.isEmpty || sugeridas.length > 1) {
            agrupado['POR ASIGNAR']!.add(v);
            volumenCalculado['POR ASIGNAR'] =
                (volumenCalculado['POR ASIGNAR'] ?? 0.0) + volObra;
          } else {
            String unica = sugeridas.first;
            if (agrupado.containsKey(unica)) {
              agrupado[unica]!.add(v);
              volumenCalculado[unica] =
                  (volumenCalculado[unica] ?? 0.0) + volObra;
            } else {
              agrupado['POR ASIGNAR']!.add(v);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          obrasPorBomba = agrupado;
          volumenPorBomba = volumenCalculado;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _actualizarProgramacion(
    String idSeguro,
    String bombaSeleccionada,
    String hora,
    String estado,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await supabase.from('asignacion_bombas').upsert({
        'id_venta': idSeguro,
        'bomba_asignada': bombaSeleccionada,
        'hora_entrega_real': hora,
        'estado_obra': estado,
      }, onConflict: 'id_venta');

      if (mounted) Navigator.pop(context);
      cargarObras();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirModalReasignacion(Map<String, dynamic> obra) {
    List<String> opcionesSugeridas = _detectarTodasLasBombas(obra);
    String bombaActual =
        obra['bomba_asignada_real'] ??
        (opcionesSugeridas.isNotEmpty ? opcionesSugeridas.first : 'CBP 15');
    String horaActual = obra['hora_entrega_editada'] ?? '08:00';
    String estadoActual = obra['estado_obra'] ?? 'Pendiente';
    String idSeguro = obra['id_seguro'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Asignar / Editar",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    obra["nombre_razon_social"] ?? "Obra",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 30),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Hora Programada"),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        horaActual,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(horaActual.split(":")[0]) ?? 8,
                            minute: int.tryParse(horaActual.split(":")[1]) ?? 0,
                          ),
                        );
                        if (picked != null)
                          setModalState(
                            () => horaActual =
                                "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}",
                          );
                      },
                    ),
                  ),

                  DropdownButtonFormField<String>(
                    value: estadoActual,
                    decoration: const InputDecoration(
                      labelText: 'Estado (Color)',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pendiente',
                        child: Text('Pendiente (Gris)'),
                      ),
                      DropdownMenuItem(
                        value: 'Atendiendo',
                        child: Text('Atendiendo (Amarillo)'),
                      ),
                      DropdownMenuItem(
                        value: 'Atendido',
                        child: Text('Atendido (Verde)'),
                      ),
                    ],
                    onChanged: (val) =>
                        setModalState(() => estadoActual = val!),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Bomba a enviar:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: columnasBombas
                        .where((b) => b != 'POR ASIGNAR')
                        .map((bomba) {
                          bool recomendada = opcionesSugeridas.contains(bomba);
                          bool seleccionada = bombaActual == bomba;
                          return ChoiceChip(
                            label: Text(bomba),
                            selected: seleccionada,
                            selectedColor: AppColors.accent,
                            labelStyle: TextStyle(
                              color: seleccionada
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            side: BorderSide(
                              color: recomendada
                                  ? Colors.amber.shade500
                                  : (seleccionada
                                        ? AppColors.accent
                                        : Colors.grey.shade300),
                              width: recomendada ? 3 : 1,
                            ),
                            onSelected: (selected) {
                              if (selected)
                                setModalState(() => bombaActual = bomba);
                            },
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _actualizarProgramacion(
                          idSeguro,
                          bombaActual,
                          horaActual,
                          estadoActual,
                        );
                      },
                      child: const Text(
                        "Guardar Programación",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBandejaObras(bool isMobile) {
    List obras = obrasPorBomba['POR ASIGNAR'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: const Text("Bandeja de Obras (Por Asignar)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16)),
        ),
        Expanded(
          child: obras.isEmpty 
            ? const Center(child: Text("No hay obras pendientes", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
              itemCount: obras.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                var obra = obras[index];
                Widget card = _buildObraCard(obra, isMobile);
                if (isMobile) return card;
                
                return Draggable<Map<String, dynamic>>(
                  data: obra,
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.transparent,
                    child: SizedBox(width: 280, child: _buildObraCard(obra, false)),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: card),
                  child: card,
                );
              },
            ),
        )
      ],
    );
  }

  Widget _buildObraCard(Map<String, dynamic> v, bool isMobile) {
    String hora = v["hora_entrega_editada"] ?? "08:00";
    String cliente = v["nombre_razon_social"] ?? "Sin Cliente";
    String volumen = v["volumen"]?.toString() ?? "0";
    String diseno = (v["diseno"]?.toString() ?? "210").toUpperCase().replaceAll("F'C=", "").replaceAll("F'C =", "").trim();
    String elemento = v["elemento"] ?? "";

    return InkWell(
      onTap: () => _abrirModalReasignacion(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(hora, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo.shade900)),
                 const Icon(Icons.edit, size: 16, color: Colors.grey),
               ]
             ),
             const SizedBox(height: 8),
             Text(cliente, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
             const SizedBox(height: 4),
             Text("$volumen m³ | F'c= $diseno", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
             const SizedBox(height: 4),
             Text(elemento.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
          ]
        ),
      ),
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.accent,
          indicatorColor: AppColors.accent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: columnasBombas.map((b) {
            int cantidad = obrasPorBomba[b]?.length ?? 0;
            double m3Total = volumenPorBomba[b] ?? 0.0;
            return Tab(
              height: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (cantidad > 0)
                    Text('$cantidad viajes | ${m3Total.toStringAsFixed(1)} m³', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: b == 'POR ASIGNAR' ? Colors.red : Colors.grey.shade600))
                  else
                    Text('Libre', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: columnasBombas.map((bomba) {
              List obras = obrasPorBomba[bomba] ?? [];
              if (obras.isEmpty) return Center(child: Text("Sin obras asignadas", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: obras.length,
                itemBuilder: (context, index) => _buildObraCard(obras[index], true).animate().fade().slideY(begin: 0.1, end: 0),
              );
            }).toList(),
          ),
        ),
      ]
    );
  }

  Widget _buildDesktopSplitView() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
             decoration: BoxDecoration(
               border: Border(right: BorderSide(color: Colors.grey.shade300, width: 2))
             ),
             child: _buildBandejaObras(false),
          ),
        ),
        Expanded(
          flex: 8,
          child: VistaCapturaTimeline(
             obrasPorBomba: obrasPorBomba,
             fecha: fechaSeleccionada,
             columnasManuales: columnasManuales,
             duracionesManuales: duracionesManuales,
             onRecargar: () {
                cargarObras();
             },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Gestión de Bombas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isMobile)
             IconButton(
               icon: const Icon(Icons.timeline, color: AppColors.accent),
               onPressed: () async {
                 await Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (_) => VistaCapturaTimeline(
                       obrasPorBomba: obrasPorBomba,
                       fecha: fechaSeleccionada,
                       columnasManuales: columnasManuales,
                       duracionesManuales: duracionesManuales,
                       onRecargar: () {},
                     ),
                   ),
                 );
                 cargarObras();
               },
             ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.accent),
            onPressed: () async {
              final DateTime? seleccion = await showDatePicker(
                context: context,
                initialDate: fechaSeleccionada,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (seleccion != null) {
                setState(() => fechaSeleccionada = seleccion);
                cargarObras();
              }
            },
          ),
        ],
      ),
      body: loading 
          ? const Center(child: CircularProgressIndicator()) 
          : (isMobile ? _buildMobileBody() : _buildDesktopSplitView()),
    );
  }
}

class VistaCapturaTimeline extends StatefulWidget {
  final Map<String, List<dynamic>> obrasPorBomba;
  final DateTime fecha;
  final Set<String> columnasManuales;
  final Map<String, double> duracionesManuales;
  final VoidCallback onRecargar;

  const VistaCapturaTimeline({
    super.key,
    required this.obrasPorBomba,
    required this.fecha,
    required this.columnasManuales,
    required this.duracionesManuales,
    required this.onRecargar,
  });

  @override
  State<VistaCapturaTimeline> createState() => _VistaCapturaTimelineState();
}

class _VistaCapturaTimelineState extends State<VistaCapturaTimeline> {
  final ScreenshotController screenshotController = ScreenshotController();

  Color _obtenerColorPorEstado(String? estado) {
    if (estado == 'Atendido') return const Color(0xFF86EFAC);
    if (estado == 'Atendiendo') return const Color(0xFFFDE047);
    return Colors.white;
  }

  Future<void> _cambiarColorBloque(Map<String, dynamic> obra) async {
    String? nuevoEstado = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Cambiar Color de Bloque",
            style: TextStyle(fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.square, color: Colors.grey.shade300),
                title: const Text("Pendiente"),
                onTap: () => Navigator.pop(context, 'Pendiente'),
              ),
              ListTile(
                leading: const Icon(Icons.square, color: Color(0xFFFDE047)),
                title: const Text("Atendiendo"),
                onTap: () => Navigator.pop(context, 'Atendiendo'),
              ),
              ListTile(
                leading: const Icon(Icons.square, color: Color(0xFF86EFAC)),
                title: const Text("Atendido"),
                onTap: () => Navigator.pop(context, 'Atendido'),
              ),
            ],
          ),
        );
      },
    );

    if (nuevoEstado != null) {
      String idSeguro = obra['id_seguro'];
      try {
        await Supabase.instance.client.from('asignacion_bombas').upsert({
          'id_venta': idSeguro,
          'bomba_asignada': obra['bomba_asignada_real'] ?? '',
          'hora_entrega_real': obra['hora_entrega_editada'] ?? '08:00',
          'estado_obra': nuevoEstado,
        }, onConflict: 'id_venta');
        setState(() {
          obra['estado_obra'] = nuevoEstado;
        });
        widget.onRecargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _moverBloque(Map<String, dynamic> obra, String nuevaBomba, String nuevaHora) async {
    String idSeguro = obra['id_seguro'];
    
    setState(() {
      for (var key in widget.obrasPorBomba.keys) {
        widget.obrasPorBomba[key]?.removeWhere((o) => o['id_seguro'] == idSeguro);
      }
      obra['bomba_asignada_real'] = nuevaBomba;
      obra['hora_entrega_editada'] = nuevaHora;
      if (!widget.obrasPorBomba.containsKey(nuevaBomba)) {
        widget.obrasPorBomba[nuevaBomba] = [];
      }
      widget.obrasPorBomba[nuevaBomba]!.add(obra);
    });

    try {
      await Supabase.instance.client.from('asignacion_bombas').upsert({
        'id_venta': idSeguro,
        'bomba_asignada': nuevaBomba,
        'hora_entrega_real': nuevaHora,
        'estado_obra': obra['estado_obra'] ?? 'Pendiente',
      }, onConflict: 'id_venta');
      widget.onRecargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al mover: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _compartirImagen() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final Uint8List? image = await screenshotController.capture(
        pixelRatio: 2.0,
      );

      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File(
          '${directory.path}/programacion_bombas.png',
        ).create();
        await imagePath.writeAsBytes(image);

        if (mounted) Navigator.pop(context);

        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text:
              'Programación de Bombas - ${widget.fecha.day}/${widget.fecha.month}',
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al compartir: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> columnasProcesadas = [];

    for (String bomba in widget.obrasPorBomba.keys) {
      if (bomba == 'POR ASIGNAR') continue;
      List obras = widget.obrasPorBomba[bomba] ?? [];
      if (obras.isEmpty && !widget.columnasManuales.contains(bomba)) continue;

      // Clonar y ordenar las obras por hora de entrega
      List obrasOrdenadas = List.from(obras);
      obrasOrdenadas.sort((a, b) {
        String ha = a['hora_entrega_editada'] ?? '08:00';
        String hb = b['hora_entrega_editada'] ?? '08:00';
        return ha.compareTo(hb);
      });

      List<List<dynamic>> lanes = [];

      if (bomba.toUpperCase().contains('DIRECTO')) {
        for (var obra in obrasOrdenadas) {
          String hora = obra['hora_entrega_editada'] ?? '08:00';
          double hInicio = (int.tryParse(hora.split(":")[0]) ?? 8) + (int.tryParse(hora.split(":")[1]) ?? 0) / 60.0;
          double vol = double.tryParse(obra['volumen'].toString()) ?? 15.0;
          double horasDuracion = 1.5 + (vol / 20.0);
          if (horasDuracion < 1.5) horasDuracion = 1.5;
          double hFin = hInicio + horasDuracion;

          bool placed = false;
          for (var lane in lanes) {
            bool solapa = false;
            for (var o in lane) {
              String oHora = o['hora_entrega_editada'] ?? '08:00';
              double ohInicio = (int.tryParse(oHora.split(":")[0]) ?? 8) + (int.tryParse(oHora.split(":")[1]) ?? 0) / 60.0;
              double oVol = double.tryParse(o['volumen'].toString()) ?? 15.0;
              double oHorasDuracion = 1.5 + (oVol / 20.0);
              if (oHorasDuracion < 1.5) oHorasDuracion = 1.5;
              double ohFin = ohInicio + oHorasDuracion;

              if (hInicio < (ohFin - 0.05) && ohInicio < (hFin - 0.05)) {
                solapa = true;
                break;
              }
            }
            if (!solapa) {
              lane.add(obra);
              placed = true;
              break;
            }
          }
          if (!placed) {
            lanes.add([obra]);
          }
        }
        if (lanes.isEmpty) {
          lanes.add([]);
        }
      } else {
        lanes.add(obrasOrdenadas);
      }

      for (int i = 0; i < lanes.length; i++) {
        columnasProcesadas.add({
          'titulo': lanes.length > 1 ? '$bomba (${i + 1})' : bomba,
          'bomba_original': bomba,
          'obras': lanes[i],
        });
      }
    }

    const double alturaHora = 90.0;
    const int horaInicio = 6;
    const int horaFin = 18;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Cuadro de Programación",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_box, color: Colors.blueAccent),
            tooltip: "Agregar columna vacía",
            onSelected: (String bombaSeleccionada) {
              setState(() {
                if (bombaSeleccionada == 'DIRECTO') {
                  int extraCount = 1;
                  String key = 'DIRECTO';
                  while (widget.obrasPorBomba.containsKey(key)) {
                    key = 'DIRECTO ($extraCount)';
                    extraCount++;
                  }
                  widget.obrasPorBomba[key] = [];
                  widget.columnasManuales.add(key);
                } else {
                  if (!widget.obrasPorBomba.containsKey(bombaSeleccionada)) {
                    widget.obrasPorBomba[bombaSeleccionada] = [];
                  }
                  widget.columnasManuales.add(bombaSeleccionada);
                }
              });
            },
            itemBuilder: (BuildContext context) {
              final opciones = [
                'DIRECTO', 'CBP 12', 'CBP 13', 'CBP 15', 'CBP 16', 
                'CBP 17', 'CBP 18', 'CBP 21', 'ESTACIONARIA'
              ];
              return opciones.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text("Agregar $choice"),
                );
              }).toList();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _compartirImagen,
            icon: const Icon(Icons.share, size: 18),
            label: const Text("Compartir"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Screenshot(
          controller: screenshotController,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            width: columnasProcesadas.isEmpty
                ? MediaQuery.of(context).size.width
                : (columnasProcesadas.length * 280) + 80, // Aumentado a 280 para mayor espacio
            height: ((horaFin - horaInicio + 1) * alturaHora) + 70,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade900, Colors.indigo.shade600],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "PROGRAMACIÓN DE BOMBAS • ${widget.fecha.day.toString().padLeft(2, '0')}/${widget.fecha.month.toString().padLeft(2, '0')}/${widget.fecha.year}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Container(height: 40),
                              ...List.generate(
                                horaFin - horaInicio + 1,
                                (i) => Container(
                                  height: alturaHora,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SizedBox(
                          width: 70,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: 0, left: 0, right: 0, height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: Colors.grey.shade300),
                                      bottom: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                ),
                              ),
                              ...List.generate(horaFin - horaInicio + 1, (index) {
                                int h = horaInicio + index;
                                String etiqueta = h < 12 
                                    ? "$h:00 am" 
                                    : (h == 12 ? "12:00 pm" : "${h - 12}:00 pm");
                                String etiquetaMitad = h < 12 
                                    ? "$h:30 am" 
                                    : (h == 12 ? "12:30 pm" : "${h - 12}:30 pm");
                                return Positioned(
                                  top: 40 + (index * alturaHora),
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: alturaHora,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          top: -8, left: 0, right: 0,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              color: Colors.white,
                                              child: Text(
                                                etiqueta,
                                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.indigo.shade900),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: (alturaHora / 2) - 7, left: 0, right: 0,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              color: Colors.white,
                                              child: Text(
                                                etiquetaMitad,
                                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.grey.shade500),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        ...columnasProcesadas.map((columna) {
                          String bomba = columna['titulo'];
                          List obras = columna['obras'];

                          return Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    bomba,
                                    style: TextStyle(
                                      color: Colors.indigo.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Builder(
                                      builder: (dropContext) => DragTarget<Map<String, dynamic>>(
                                        onAcceptWithDetails: (details) {
                                          final box = dropContext.findRenderObject() as RenderBox?;
                                          if (box != null) {
                                            final localOffset = box.globalToLocal(details.offset);
                                            double droppedTime = horaInicio + (localOffset.dy / alturaHora);
                                            int newH = droppedTime.floor();
                                            int newM = ((droppedTime - newH) * 60).round();
                                            if (newM < 15) newM = 0;
                                            else if (newM < 45) newM = 30;
                                            else { newM = 0; newH++; }
                                            String newHora = '${newH.toString().padLeft(2, '0')}:${newM.toString().padLeft(2, '0')}';
                                            String newBomba = columna['bomba_original'];
                                            _moverBloque(details.data, newBomba, newHora);
                                          }
                                        },
                                        builder: (context, candidates, rejects) {
                                          return Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              ...obras.map((obra) {
                                                String hora = obra['hora_entrega_editada'] ?? '08:00';
                                                int h = int.tryParse(hora.split(":")[0]) ?? 8;
                                                int m = int.tryParse(hora.split(":")[1]) ?? 0;
      
                                                double offsetTop = ((h - horaInicio) * alturaHora) + ((m / 60.0) * alturaHora);
      
                                                double vol = double.tryParse(obra['volumen'].toString()) ?? 15.0;
                                                double horasDuracion = obra['duracion_manual'] ?? (1.5 + (vol / 20.0));
                                                if (horasDuracion < 1.5 && obra['duracion_manual'] == null) horasDuracion = 1.5;
                                                double offsetHeight = alturaHora * horasDuracion;
      
                                                String estadoActual = obra['estado_obra'] ?? 'Pendiente';
      
                                                Widget cardContent = Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _obtenerColorPorEstado(estadoActual),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.black54, width: 1.5),
                                                    boxShadow: const [
                                                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 3)),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        "${obra['nombre_razon_social'] ?? 'Sin Cliente'}",
                                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87, height: 1.2),
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        "${obra['volumen'] ?? '0'} m³",
                                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.indigo.shade900, height: 1.2),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        "${obra['elemento'] ?? ''} / F'c= ${obra['diseno']?.toString().toUpperCase().replaceAll("F'C=", "").replaceAll("F'C =", "").trim() ?? ''}",
                                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.black54, height: 1.2),
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      if (obra['operador'] != null)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          child: Text(
                                                            obra['operador'],
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black87, height: 1.1),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );

                                                Widget resizableCard = Stack(
                                                  children: [
                                                    Positioned.fill(child: cardContent),
                                                    Positioned(
                                                      bottom: 0, left: 0, right: 0,
                                                      height: 15,
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.opaque,
                                                        onVerticalDragUpdate: (dragDetails) {
                                                          setState(() {
                                                            double dragInHours = dragDetails.delta.dy / alturaHora;
                                                            double newDur = horasDuracion + dragInHours;
                                                            if (newDur < 0.5) newDur = 0.5;
                                                            obra['duracion_manual'] = newDur;
                                                            widget.duracionesManuales[obra['id_seguro']] = newDur;
                                                          });
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withOpacity(0.15),
                                                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                                                          ),
                                                          child: Center(
                                                            child: Container(width: 30, height: 4, decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(2))),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
      
                                                return Positioned(
                                                  top: offsetTop,
                                                  left: 4,
                                                  right: 4,
                                                  height: offsetHeight,
                                                  child: Draggable<Map<String, dynamic>>(
                                                    data: Map<String, dynamic>.from(obra),
                                                    feedback: Material(
                                                      color: Colors.transparent,
                                                      child: SizedBox(
                                                        width: 272, // 280 - 8
                                                        height: offsetHeight,
                                                        child: Opacity(opacity: 0.8, child: resizableCard),
                                                      ),
                                                    ),
                                                    childWhenDragging: Opacity(
                                                      opacity: 0.3,
                                                      child: resizableCard,
                                                    ),
                                                    child: GestureDetector(
                                                      onTap: () => _cambiarColorBloque(obra),
                                                      child: resizableCard,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
