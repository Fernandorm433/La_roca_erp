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
      };
      Map<String, double> volumenCalculado = {
        for (var b in columnasBombas) b: 0.0,
      };

      for (var v in ventasData) {
        if (v["numero_atencion"]?.toString() == "0" ||
            v["estado"]?.toString().toUpperCase() == "CANCELADO")
          continue;
        double volObra =
            double.tryParse(v["volumen"]?.toString() ?? '0') ?? 0.0;

        String idObra = _obtenerIdSeguro(v);
        v['id_seguro'] = idObra;

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

        if (bombaDefinitiva.isNotEmpty &&
            agrupado.containsKey(bombaDefinitiva)) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Gestión de Bombas",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: AppColors.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VistaCapturaTimeline(
                  obrasPorBomba: obrasPorBomba,
                  fecha: fechaSeleccionada,
                  onRecargar: cargarObras,
                ),
              ),
            ),
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
        bottom: TabBar(
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
                  Text(
                    b,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (cantidad > 0)
                    Text(
                      '$cantidad viajes | ${m3Total.toStringAsFixed(1)} m³',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: b == 'POR ASIGNAR'
                            ? Colors.red
                            : Colors.grey.shade600,
                      ),
                    )
                  else
                    Text(
                      'Libre',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: columnasBombas.map((bomba) {
                List obras = obrasPorBomba[bomba] ?? [];
                if (obras.isEmpty)
                  return Center(
                    child: Text(
                      "Sin obras asignadas",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: obras.length,
                  itemBuilder: (context, index) {
                    final v = obras[index];
                    String hora = v["hora_entrega_editada"] ?? "08:00";
                    String cliente = v["nombre_razon_social"] ?? "Sin Cliente";
                    String volumen = v["volumen"]?.toString() ?? "0";

                    String disenoRaw = v["diseno"]?.toString() ?? "210";
                    String diseno = disenoRaw
                        .toUpperCase()
                        .replaceAll("F'C=", "")
                        .replaceAll("F'C =", "")
                        .trim();

                    String elemento = v["elemento"] ?? "";

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 70,
                          child: Column(
                            children: [
                              Text(
                                hora,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 90,
                                color: Colors.grey.shade300,
                                margin: const EdgeInsets.only(top: 8),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _abrirModalReasignacion(v),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFEFEF),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          cliente,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    "$volumen m³ | F'c= $diseno",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  Text(
                                    elemento.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fade().slideY(begin: 0.1, end: 0);
                  },
                );
              }).toList(),
            ),
    );
  }
}

class VistaCapturaTimeline extends StatefulWidget {
  final Map<String, List<dynamic>> obrasPorBomba;
  final DateTime fecha;
  final VoidCallback onRecargar;

  const VistaCapturaTimeline({
    super.key,
    required this.obrasPorBomba,
    required this.fecha,
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
                title: const Text("Pendiente (Blanco)"),
                onTap: () => Navigator.pop(context, 'Pendiente'),
              ),
              ListTile(
                leading: const Icon(Icons.square, color: Color(0xFFFDE047)),
                title: const Text("Atendiendo (Amarillo)"),
                onTap: () => Navigator.pop(context, 'Atendiendo'),
              ),
              ListTile(
                leading: const Icon(Icons.square, color: Color(0xFF86EFAC)),
                title: const Text("Atendido (Verde)"),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
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
    List<String> columnasActivas = widget.obrasPorBomba.keys
        .where((k) => k != 'POR ASIGNAR' && widget.obrasPorBomba[k]!.isNotEmpty)
        .toList();

    const double alturaHora = 65.0;
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
      body: InteractiveViewer(
        constrained: false,
        child: Screenshot(
          controller: screenshotController,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            width: columnasActivas.isEmpty
                ? MediaQuery.of(context).size.width
                : (columnasActivas.length * 170) + 80,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 70,
                          child: Stack(
                            children: List.generate(horaFin - horaInicio + 1, (
                              index,
                            ) {
                              int h = horaInicio + index;
                              String etiqueta = h <= 12
                                  ? "$h:00 am"
                                  : "${h - 12}:00 pm";
                              return Positioned(
                                top: index * alturaHora,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: alturaHora,
                                  alignment: Alignment.topCenter,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    etiqueta,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        ...columnasActivas.map((bomba) {
                          List obras = widget.obrasPorBomba[bomba] ?? [];

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
                                        ...List.generate(
                                          horaFin - horaInicio + 1,
                                          (i) => Positioned(
                                            top: i * alturaHora,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 1,
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),

                                        ...obras.map((obra) {
                                          String hora =
                                              obra['hora_entrega_editada'] ??
                                              '08:00';
                                          int h =
                                              int.tryParse(
                                                hora.split(":")[0],
                                              ) ??
                                              8;
                                          int m =
                                              int.tryParse(
                                                hora.split(":")[1],
                                              ) ??
                                              0;

                                          double offsetTop =
                                              ((h - horaInicio) * alturaHora) +
                                              ((m / 60.0) * alturaHora);

                                          double vol =
                                              double.tryParse(
                                                obra['volumen'].toString(),
                                              ) ??
                                              15.0;
                                          double horasDuracion =
                                              1.5 + (vol / 20.0);
                                          if (horasDuracion < 1.5)
                                            horasDuracion = 1.5;
                                          double offsetHeight =
                                              alturaHora * horasDuracion;

                                          String estadoActual =
                                              obra['estado_obra'] ??
                                              'Pendiente';

                                          return Positioned(
                                            top: offsetTop,
                                            left: 4,
                                            right: 4,
                                            height: offsetHeight,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _cambiarColorBloque(obra),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _obtenerColorPorEstado(
                                                    estadoActual,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.black54,
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black12,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "${obra['nombre_razon_social'] ?? 'Sin Cliente'}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 11,
                                                        color: Colors.black87,
                                                        height: 1.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "${obra['volumen'] ?? '0'} m³",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 12,
                                                        color: Colors
                                                            .indigo
                                                            .shade900,
                                                        height: 1.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "${obra['elemento'] ?? ''} / F'c= ${obra['diseno']?.toString().toUpperCase().replaceAll("F'C=", "").replaceAll("F'C =", "").trim() ?? ''}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 10,
                                                        color: Colors.black54,
                                                        height: 1.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    if (obra['operador'] !=
                                                        null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                        child: Text(
                                                          obra['operador'],
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 9,
                                                                color: Colors
                                                                    .black87,
                                                                height: 1.1,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
