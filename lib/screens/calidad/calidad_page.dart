// Archivo: lib/screens/calidad/calidad_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';

class ControlCalidadPage extends StatefulWidget {
  const ControlCalidadPage({super.key});
  @override
  State<ControlCalidadPage> createState() => _ControlCalidadPageState();
}

class _ControlCalidadPageState extends State<ControlCalidadPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String queryBusqueda = "";
  List registrosCalidad = [];

  @override
  void initState() {
    super.initState();
    cargarHistorialGlobal();
  }

  Future cargarHistorialGlobal() async {
    setState(() => loading = true);

    try {
      final data = await supabase
          .from("despachos_produccion")
          .select()
          .order('fecha', ascending: false)
          .limit(3000);

      if (mounted) {
        setState(() {
          registrosCalidad = data;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Calidad: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filtrado dinámico por Cliente o Mixer
    List filtrados = registrosCalidad.where((r) {
      String cliente = (r["cliente"] ?? r["nombre_razon_social"] ?? "")
          .toString()
          .toLowerCase();
      String mixer = (r["mixer"] ?? "").toString().toLowerCase();
      return cliente.contains(queryBusqueda.toLowerCase()) ||
          mixer.contains(queryBusqueda.toLowerCase());
    }).toList();

    // 2. Agrupación por Cliente
    Map<String, List<dynamic>> agrupadosPorCliente = {};
    for (var f in filtrados) {
      String cliente =
          f["cliente"] ?? f["nombre_razon_social"] ?? "Cliente Desconocido";
      if (!agrupadosPorCliente.containsKey(cliente)) {
        agrupadosPorCliente[cliente] = [];
      }
      agrupadosPorCliente[cliente]!.add(f);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Historial Global de Dosificación",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.primaryDark,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.accent),
            tooltip: "Actualizar datos",
            onPressed: cargarHistorialGlobal,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        // ConstrainedBox para que en Escritorio/Tablet no se estire de borde a borde
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Container(
                  // CORRECCIÓN: La sombra va aquí en el Container, no en el InputDecoration
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => queryBusqueda = val),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                    decoration: InputDecoration(
                      hintText: "Buscar cliente o mixer...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.accent,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.accent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : agrupadosPorCliente.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              queryBusqueda.isEmpty
                                  ? "Cargando clientes..."
                                  : "No se encontró ningún registro.",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: agrupadosPorCliente.keys.length,
                        itemBuilder: (context, index) {
                          String cliente = agrupadosPorCliente.keys.elementAt(
                            index,
                          );
                          List<dynamic> mixers = agrupadosPorCliente[cliente]!;

                          var card = _buildCardClienteAgrupado(cliente, mixers);
                          return queryBusqueda.isEmpty
                              ? card
                                    .animate()
                                    .fade(
                                      delay: (index < 10 ? index * 50 : 0).ms,
                                    )
                                    .slideY(begin: 0.1, end: 0)
                              : card;
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardClienteAgrupado(String cliente, List<dynamic> mixers) {
    double volumenTotalCliente = 0;
    for (var m in mixers) {
      double v = limpiarYExtraerNumero(m["volumen_guias"]);
      if (v == 0) v = limpiarYExtraerNumero(m["volumen"]);
      volumenTotalCliente += v;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.apartment, color: AppColors.accent, size: 22),
        ),
        title: Text(
          cliente,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "Historial: ${mixers.length} Mixers | Vol Total: ${volumenTotalCliente.toStringAsFixed(1)} m³",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              children: mixers.map((m) => _buildMixerDetalle(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixerDetalle(Map<String, dynamic> r) {
    double volMixer = limpiarYExtraerNumero(r["volumen_guias"]);
    if (volMixer == 0.0) volMixer = limpiarYExtraerNumero(r["volumen"]);
    if (volMixer == 0.0) volMixer = 1.0;

    String fechaDespacho = r["fecha"] ?? 'S/F';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del Mixer responsivo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fire_truck,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      // Flexible permite que el texto se acorte si la pantalla es muy pequeña
                      Flexible(
                        child: Text(
                          "Mixer: ${r["mixer"] ?? 'S/M'}  •  $fechaDespacho",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.primaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${volMixer.toStringAsFixed(1)} m³ | F'c: ${r["diseno"] ?? 'S/D'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),

          // Cuadros de Materiales con LayoutBuilder (Grid dinámico)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Lógica de columnas: 2 en celular, 3 en tablet, 4 en PC
                double anchoDisponible = constraints.maxWidth;
                int columnas = anchoDisponible < 350
                    ? 2
                    : (anchoDisponible < 600 ? 3 : 4);

                // Calculamos el ancho exacto de cada tarjeta restando el espaciado
                double spacing = 8.0;
                double anchoItem =
                    (anchoDisponible - ((columnas - 1) * spacing)) / columnas;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _itemMaterialDoble(
                      "Cemento",
                      r["cemento"],
                      volMixer,
                      "KG",
                      Colors.blueGrey.shade700,
                      anchoItem,
                    ),
                    _itemMaterialDoble(
                      "Agua",
                      r["agua"],
                      volMixer,
                      "LT",
                      Colors.blue.shade600,
                      anchoItem,
                    ),
                    _itemMaterialDoble(
                      "Arena",
                      r["arena"],
                      volMixer,
                      "KG",
                      Colors.orange.shade700,
                      anchoItem,
                    ),
                    _itemMaterialDoble(
                      "Piedra 1/2",
                      r["piedra_12"],
                      volMixer,
                      "KG",
                      Colors.grey.shade700,
                      anchoItem,
                    ),
                    _itemMaterialDoble(
                      "Piedra 3/4",
                      r["piedra_34"],
                      volMixer,
                      "KG",
                      Colors.grey.shade700,
                      anchoItem,
                    ),
                    _itemMaterialDoble(
                      "Piedra 3/8",
                      r["piedra_38"],
                      volMixer,
                      "KG",
                      Colors.grey.shade700,
                      anchoItem,
                    ),
                    _itemMaterialDoble(
                      "Aditivo",
                      r["aditivo"],
                      volMixer,
                      "KG",
                      Colors.purple.shade600,
                      anchoItem,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta de material ajustada para recibir un ancho estático en lugar de usar Expanded
  Widget _itemMaterialDoble(
    String label,
    dynamic val,
    double volumenMixer,
    String unit,
    Color color,
    double width,
  ) {
    double total = double.tryParse(val?.toString() ?? '0') ?? 0;
    double porM3 = volumenMixer > 0 ? (total / volumenMixer) : 0;
    bool esCero = total == 0;

    return Container(
      width: width, // Se adapta dinámicamente según el Wrap
      decoration: BoxDecoration(
        color: esCero ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esCero ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: esCero
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: esCero ? Colors.grey.shade200 : color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: esCero ? Colors.grey.shade500 : color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "TOTAL",
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        esCero ? "-" : total.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: esCero ? Colors.grey : AppColors.primaryDark,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey.shade200),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "x 1m³",
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        esCero ? "-" : porM3.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: esCero ? Colors.grey : Colors.black87,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
