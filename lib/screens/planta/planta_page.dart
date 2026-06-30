import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

class ControlPlantaPage extends StatefulWidget {
  const ControlPlantaPage({super.key});
  @override
  State<ControlPlantaPage> createState() => _ControlPlantaPageState();
}

class _ControlPlantaPageState extends State<ControlPlantaPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  DateTime fechaSeleccionada = DateTime.now();
  List<Map<String, dynamic>> obrasPlanta = [];

  @override
  void initState() {
    super.initState();
    cargarDatosPlanta();
  }

  Future cargarDatosPlanta() async {
    setState(() => loading = true);
    String fechaFiltro = fechaSeleccionada.toIso8601String().split('T')[0];

    try {
      final ventas = await supabase
          .from("ventas_programacion")
          .select()
          .eq('fecha_entrega', fechaFiltro)
          .order("hora_entrega");
      final asignaciones = await supabase.from("asignacion_bombas").select();

      Map<String, dynamic> bombasMap = {
        for (var a in asignaciones) a['id_venta'].toString(): a,
      };

      List<Map<String, dynamic>> dataProcesada = [];

      for (var v in ventas) {
        if (v["numero_atencion"]?.toString() == "0" ||
            v["estado"]?.toString().toUpperCase() == "CANCELADO")
          continue;

        String idObra = v['id']?.toString() ?? '';
        if (idObra.isEmpty || idObra == 'null')
          idObra = v['numero_atencion']?.toString() ?? '';

        String bombaAsignada = "";
        if (bombasMap.containsKey(idObra)) {
          bombaAsignada = bombasMap[idObra]['bomba_asignada'] ?? "";
        }

        dataProcesada.add({
          "id_seguro": idObra,
          "orden_pedido": v["numero_atencion"] ?? "S/N",
          "volumen_pedido": v["volumen"] ?? "0",
          "orden_carga": "",
          "carguio_nro": "",
          "volumen_carguio": "",
          "mixer": "",
          "diseno": v["diseno"] ?? "",
          "cliente":
              "${v["direccion"] ?? ''} / ${v["nombre_razon_social"] ?? ''}",
          "hora_prog": v["hora_entrega"] ?? "",
          "bomba": bombaAsignada.isNotEmpty ? bombaAsignada : "POR ASIGNAR",
          "asesor_elemento":
              "${v["asesor_comercial"] ?? ''} / ${v["elemento"] ?? ''}",
          "estado_color": "blanco",
        });
      }

      if (mounted) {
        setState(() {
          obrasPlanta = dataProcesada;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Planta: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Color _obtenerColor(String estado) {
    if (estado == "amarillo") return AppColors.mixerCargando;
    if (estado == "celeste") return AppColors.mixerRegulando;
    if (estado == "verde") return AppColors.mixerSalio;
    return Colors.white;
  }

  void _ciclarEstado(int index) {
    setState(() {
      String actual = obrasPlanta[index]["estado_color"];
      if (actual == "blanco") {
        obrasPlanta[index]["estado_color"] = "amarillo";
      } else if (actual == "amarillo")
        obrasPlanta[index]["estado_color"] = "celeste";
      else if (actual == "celeste")
        obrasPlanta[index]["estado_color"] = "verde";
      else
        obrasPlanta[index]["estado_color"] = "blanco";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Control de Despacho Planta",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.accent),
            onPressed: () async {
              final seleccion = await showDatePicker(
                context: context,
                initialDate: fechaSeleccionada,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (seleccion != null) {
                setState(() => fechaSeleccionada = seleccion);
                cargarDatosPlanta();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: cargarDatosPlanta,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  color: Colors.white,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 10,
                    children: [
                      _leyendaColor(AppColors.mixerCargando, "Cargando"),
                      _leyendaColor(AppColors.mixerRegulando, "Regulando"),
                      _leyendaColor(AppColors.mixerSalio, "Salió de Planta"),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFF10B981),
                          ),
                          dataRowMaxHeight: 60,
                          columnSpacing: 15,
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'ORDEN\nPEDIDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'VOL\nPEDIDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ORDEN\nCARGA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'CARGUÍO N°',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'VOL\nCARGUÍO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'MIXER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'DISEÑO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'DIRECCIÓN / CLIENTE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'HORA\nPROG',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'BOMBA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ASESOR / ELEMENTO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                          rows: obrasPlanta.asMap().entries.map((entry) {
                            int index = entry.key;
                            var row = entry.value;
                            Color rowColor = _obtenerColor(row["estado_color"]);

                            return DataRow(
                              color: WidgetStateProperty.all(rowColor),
                              cells: [
                                DataCell(
                                  Text(
                                    row["orden_pedido"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(row["volumen_pedido"].toString()),
                                ),
                                DataCell(
                                  _buildInputCelda(
                                    row["orden_carga"],
                                    (val) => row["orden_carga"] = val,
                                    50,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildInputCelda(row["carguio_nro"], (
                                        val,
                                      ) {
                                        row["carguio_nro"] = val;
                                        if (val.isNotEmpty &&
                                            row["estado_color"] == "blanco") {
                                          setState(
                                            () => row["estado_color"] =
                                                "amarillo",
                                          );
                                        }
                                      }, 90),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _ciclarEstado(index),
                                        borderRadius: BorderRadius.circular(15),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              _obtenerColor(
                                                    row["estado_color"],
                                                  ) ==
                                                  Colors.white
                                              ? Colors.grey.shade300
                                              : _obtenerColor(
                                                  row["estado_color"],
                                                ),
                                          child: const Icon(
                                            Icons.touch_app,
                                            size: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  _buildInputCelda(
                                    row["volumen_carguio"],
                                    (val) => row["volumen_carguio"] = val,
                                    60,
                                  ),
                                ),
                                DataCell(
                                  _buildInputCelda(
                                    row["mixer"],
                                    (val) => row["mixer"] = val,
                                    70,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row["diseno"],
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 250,
                                    child: Text(
                                      row["cliente"],
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row["hora_prog"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row["bomba"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      row["asesor_elemento"],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.teal,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInputCelda(
    String valorInicial,
    Function(String) onChanged,
    double width,
  ) {
    return Container(
      width: width,
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: TextFormField(
        initialValue: valorInicial,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _leyendaColor(Color color, String texto) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
