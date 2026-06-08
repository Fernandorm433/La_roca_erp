// Archivo: lib/screens/calidad/calidad_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import 'package:intl/intl.dart';

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

    // 2. Agrupación por Día y luego por Cliente
    Map<String, Map<String, List<dynamic>>> agrupadosPorDiaYCliente = {};
    
    for (var f in filtrados) {
      String fechaFull = (f["fecha"] ?? '').toString();
      // Extraemos solo la fecha (YYYY-MM-DD)
      String dia = fechaFull.isNotEmpty 
          ? (fechaFull.contains(' ') ? fechaFull.split(' ').first : (fechaFull.contains('T') ? fechaFull.split('T').first : fechaFull))
          : 'Sin Fecha';
          
      String cliente = f["cliente"] ?? f["nombre_razon_social"] ?? "Cliente Desconocido";

      agrupadosPorDiaYCliente.putIfAbsent(dia, () => {});
      agrupadosPorDiaYCliente[dia]!.putIfAbsent(cliente, () => []);
      agrupadosPorDiaYCliente[dia]![cliente]!.add(f);
    }

    // Ordenamos los días del más reciente al más antiguo
    List<String> diasOrdenados = agrupadosPorDiaYCliente.keys.toList()
      ..sort((a, b) => b.compareTo(a));

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Container(
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
                      prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
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
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : agrupadosPorDiaYCliente.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              queryBusqueda.isEmpty
                                  ? "Cargando historial..."
                                  : "No se encontraron registros.",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: diasOrdenados.length,
                        itemBuilder: (context, index) {
                          String dia = diasOrdenados[index];
                          Map<String, List<dynamic>> clientesDelDia = agrupadosPorDiaYCliente[dia]!;

                          var cardDia = _buildCardDia(dia, clientesDelDia, index == 0);
                          return queryBusqueda.isEmpty
                              ? cardDia
                                    .animate()
                                    .fade(delay: (index < 10 ? index * 50 : 0).ms)
                                    .slideY(begin: 0.1, end: 0)
                              : cardDia;
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NUEVO: Tarjeta agrupadora por Día con resumen de materiales ---
  Widget _buildCardDia(String dia, Map<String, List<dynamic>> clientes, bool expandir) {
    double totalVolumen = 0;
    double totalCemento = 0;
    double totalArena = 0;
    double totalPiedra = 0;
    double totalAgua = 0;
    double totalAditivo = 0;

    List<dynamic> todosMixersDelDia = clientes.values.expand((x) => x).toList();

    for (var m in todosMixersDelDia) {
      double vol = limpiarYExtraerNumero(m["volumen_guias"]);
      if (vol == 0) vol = limpiarYExtraerNumero(m["volumen"]);
      totalVolumen += vol;

      totalCemento += limpiarYExtraerNumero(m["cemento"]);
      totalArena += limpiarYExtraerNumero(m["arena"]);
      totalPiedra += limpiarYExtraerNumero(m["piedra_12"]) + 
                     limpiarYExtraerNumero(m["piedra_34"]) + 
                     limpiarYExtraerNumero(m["piedra_38"]);
      totalAgua += limpiarYExtraerNumero(m["agua"]);
      totalAditivo += limpiarYExtraerNumero(m["aditivo"]);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: expandir || queryBusqueda.isNotEmpty,
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_month, color: AppColors.primaryDark, size: 24),
        ),
        title: Text(
          "Fecha: $dia",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
        ),
        subtitle: Text(
          "Producción: ${totalVolumen.toStringAsFixed(1)} m³ | ${todosMixersDelDia.length} Despachos",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        children: [
          // Resumen de Materiales Utilizados en el Día
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Consumo Total del Día",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChipMaterial("Cemento", totalCemento / 1500, "BIG-BAG", Colors.blueGrey),
                      _buildChipMaterial("Arena", totalArena, "KG", Colors.orange),
                      _buildChipMaterial("Piedra", totalPiedra, "KG", Colors.grey),
                      _buildChipMaterial("Agua", totalAgua, "LT", Colors.blue),
                      _buildChipMaterial("Aditivo", totalAditivo, "KG", Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Lista de Clientes dentro de este día
          ...clientes.keys.map((c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildCardClienteAgrupado(c, clientes[c]!),
          )).toList(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- Helper para mostrar el consumo diario de forma elegante ---
  Widget _buildChipMaterial(String nombre, double total, String unidad, MaterialColor color) {
    if (total <= 0) return const SizedBox.shrink();
    final String formattedTotal = NumberFormat('#,##0.0', 'en_US').format(total);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        children: [
          Text(nombre, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.shade700)),
          const SizedBox(height: 2),
          Text(
            "$formattedTotal $unidad", 
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryDark)
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: queryBusqueda.isNotEmpty,
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.apartment, color: AppColors.accent, size: 20),
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
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
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
    // 1. Obtener Volumen Base
    double volMixer = limpiarYExtraerNumero(r["volumen_guias"]);
    if (volMixer == 0.0) volMixer = limpiarYExtraerNumero(r["volumen"]);
    if (volMixer == 0.0) volMixer = 1.0; // Prevenir div/0 global
    
    // 2. Extraer Optimización
    double optimizado = limpiarYExtraerNumero(r["optimizado"]);
    bool tieneOptimizacion = optimizado > 0;
    
    // 3. Calcular Volumen Efectivo para dividir los materiales
    double volumenEfectivo = volMixer;
    if (tieneOptimizacion && optimizado < volMixer) {
      volumenEfectivo = volMixer - optimizado;
    }
    // Failsafe por si la resta da 0 por error de tipeo en BD
    if (volumenEfectivo <= 0) volumenEfectivo = 1.0; 

    String fechaDespacho = r["fecha"] ?? 'S/F';
    // Si viene fecha larga, extraemos solo la hora si ya estamos agrupando por día
    if(fechaDespacho.contains(' ')) {
      fechaDespacho = fechaDespacho.split(' ')[1]; // Muestra la hora
    }

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tieneOptimizacion ? Colors.green.shade50 : Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        tieneOptimizacion ? Icons.auto_awesome : Icons.fire_truck,
                        color: tieneOptimizacion ? Colors.green.shade600 : AppColors.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          // CORREGIDO AQUÍ: Comillas simples adentro para r['mixer']
                          "Mixer: ${r['mixer'] ?? 'S/M'}  •  $fechaDespacho",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.primaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // BADGE DE OPTIMIZACIÓN
                      if (tieneOptimizacion) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Optimizado: -${optimizado.toStringAsFixed(1)} m³",
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  // CORREGIDO AQUÍ: Comillas simples adentro para r['diseno']
                  "${volMixer.toStringAsFixed(1)} m³ | F'c: ${r['diseno'] ?? 'S/D'}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: tieneOptimizacion ? Colors.green.shade700 : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),

          // Grid de Materiales.
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double anchoDisponible = constraints.maxWidth;
                int columnas = anchoDisponible < 350 ? 2 : (anchoDisponible < 600 ? 3 : 4);
                double spacing = 8.0;
                double anchoItem = (anchoDisponible - ((columnas - 1) * spacing)) / columnas;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _itemMaterialDoble("Cemento", r["cemento"], volumenEfectivo, "KG", Colors.blueGrey.shade700, anchoItem),
                    _itemMaterialDoble("Agua", r["agua"], volumenEfectivo, "LT", Colors.blue.shade600, anchoItem),
                    _itemMaterialDoble("Arena", r["arena"], volumenEfectivo, "KG", Colors.orange.shade700, anchoItem),
                    _itemMaterialDoble("Piedra 1/2", r["piedra_12"], volumenEfectivo, "KG", Colors.grey.shade700, anchoItem),
                    _itemMaterialDoble("Piedra 3/4", r["piedra_34"], volumenEfectivo, "KG", Colors.grey.shade700, anchoItem),
                    _itemMaterialDoble("Piedra 3/8", r["piedra_38"], volumenEfectivo, "KG", Colors.grey.shade700, anchoItem),
                    _itemMaterialDoble("Aditivo", r["aditivo"], volumenEfectivo, "KG", Colors.purple.shade600, anchoItem),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMaterialDoble(
    String label,
    dynamic val,
    double volumenMixerEfectivo,
    String unit,
    Color color,
    double width,
  ) {
    double total = double.tryParse(val?.toString() ?? '0') ?? 0;
    // Se divide por el volumen con optimización ya aplicada
    double porM3 = volumenMixerEfectivo > 0 ? (total / volumenMixerEfectivo) : 0;
    bool esCero = total == 0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: esCero ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: esCero ? Colors.transparent : Colors.grey.shade200),
        boxShadow: esCero ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: esCero ? Colors.grey.shade200 : color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              "$label ($unit)",
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
                        style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        esCero ? "-" : NumberFormat('#,##0.0', 'en_US').format(total),
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
                        style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
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