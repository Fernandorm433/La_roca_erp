// Archivo: lib/screens/ventas/ventas_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  final supabase = Supabase.instance.client;

  List ventasFiltradas = [];
  List despachosFiltrados = [];

  String filtroTiempo = 'Este Mes';
  String etiquetaFiltro = 'Este Mes';
  DateTime? fechaInicioFiltro;
  DateTime? fechaFinFiltro;

  double totalProgramado = 0;
  Map<String, double> volumenPorAsesor = {};
  Map<String, int> atencionesPorAsesor = {};
  double maxVolumenAsesor = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future cargarDatos() async {
    setState(() => loading = true);
    DateTime ahora = DateTime.now();
    DateTime inicio;
    DateTime fin;

    if (filtroTiempo == 'Hoy') {
      inicio = DateTime(ahora.year, ahora.month, ahora.day);
      fin = DateTime(ahora.year, ahora.month, ahora.day);
      etiquetaFiltro = "Hoy";
    } else if (filtroTiempo == 'Esta Semana') {
      inicio = DateTime(
        ahora.year,
        ahora.month,
        ahora.day - (ahora.weekday - 1),
      );
      fin = DateTime(ahora.year, ahora.month, ahora.day + (7 - ahora.weekday));
      etiquetaFiltro = "Esta Semana";
    } else if (filtroTiempo == 'Este Mes') {
      inicio = DateTime(ahora.year, ahora.month, 1);
      fin = DateTime(ahora.year, ahora.month + 1, 0);
      etiquetaFiltro = "Este Mes";
    } else if (filtroTiempo == 'Mes Pasado') {
      inicio = DateTime(ahora.year, ahora.month - 1, 1);
      fin = DateTime(ahora.year, ahora.month, 0);
      etiquetaFiltro = "Mes Pasado";
    } else {
      inicio = fechaInicioFiltro ?? DateTime(ahora.year, ahora.month, 1);
      fin = fechaFinFiltro ?? DateTime.now();
    }

    String strInicio =
        "${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}";
    DateTime finMasUno = fin.add(const Duration(days: 1));
    String strFin =
        "${finMasUno.year}-${finMasUno.month.toString().padLeft(2, '0')}-${finMasUno.day.toString().padLeft(2, '0')}";

    try {
      final v = await supabase
          .from("ventas_programacion")
          .select()
          .gte('fecha_entrega', strInicio)
          .lt('fecha_entrega', strFin)
          .limit(10000);

      final d = await supabase
          .from("despachos_produccion")
          .select()
          .gte('fecha', strInicio)
          .lt('fecha', strFin)
          .limit(10000);

      final asig = await supabase.from("asignacion_bombas").select();
      Map<String, String> mapaBombas = {
        for (var a in asig)
          a['id_venta'].toString(): a['bomba_asignada'].toString(),
      };

      for (var venta in v) {
        String idVenta = venta['id']?.toString() ?? '';
        if (idVenta.isEmpty || idVenta == 'null') {
          idVenta = venta['numero_atencion']?.toString() ?? '';
        }
        venta['bomba_asignada_real'] = mapaBombas[idVenta];
      }

      if (mounted) {
        setState(() {
          ventasFiltradas = v;
          despachosFiltrados = d;
          loading = false;
        });
        _calcularMetricasVentas();
      }
    } catch (e) {
      debugPrint("Error Ventas: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _seleccionarRangoPersonalizado() async {
    final DateTime? fechaInicio = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'FECHA INICIAL (1/2)',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );

    if (fechaInicio == null) return;

    final DateTime? fechaFin = await showDatePicker(
      context: context,
      initialDate: fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'FECHA FINAL (2/2)',
      cancelText: 'Atrás',
      confirmText: 'Aplicar',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );

    if (fechaFin != null) {
      setState(() {
        filtroTiempo = 'Personalizado';
        fechaInicioFiltro = fechaInicio;
        fechaFinFiltro = fechaFin;

        if (fechaInicio.isAtSameMomentAs(fechaFin)) {
          etiquetaFiltro = "${fechaInicio.day}/${fechaInicio.month}";
        } else {
          etiquetaFiltro =
              "${fechaInicio.day}/${fechaInicio.month} - ${fechaFin.day}/${fechaFin.month}";
        }
      });
      cargarDatos();
    }
  }

  void _calcularMetricasVentas() {
    double prog = 0;
    Map<String, double> vAsesor = {};
    Map<String, int> aAsesor = {};
    double maxAsesor = 0;

    for (var i in ventasFiltradas) {
      String asesor =
          i["asesor_comercial"]?.toString().toUpperCase() ?? "SIN ASIGNAR";
      if (asesor.trim().isEmpty || asesor == "NULL") asesor = "SIN ASIGNAR";

      vAsesor.putIfAbsent(asesor, () => 0.0);
      aAsesor.putIfAbsent(asesor, () => 0);
      aAsesor[asesor] = aAsesor[asesor]! + 1;

      bool esCancelado =
          i["numero_atencion"]?.toString() == "0" ||
          i["estado"]?.toString().toUpperCase() == "CANCELADO";

      if (!esCancelado) {
        double vol = limpiarYExtraerNumero(i["volumen"]);
        prog += vol;
        vAsesor[asesor] = vAsesor[asesor]! + vol;
        if (vAsesor[asesor]! > maxAsesor) maxAsesor = vAsesor[asesor]!;
      }
    }

    setState(() {
      totalProgramado = prog;
      volumenPorAsesor = vAsesor;
      atencionesPorAsesor = aAsesor;
      maxVolumenAsesor = maxAsesor;
    });
  }

  void _mostrarDetalleAsesor(String asesor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PortafolioAsesorModal(
          asesor: asesor,
          ventasFiltradas: ventasFiltradas,
          despachosFiltrados: despachosFiltrados,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    var asesoresOrdenados = volumenPorAsesor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    int totalClientesGenerados = atencionesPorAsesor.values.fold(
      0,
      (sum, val) => sum + val,
    );

    return RefreshIndicator(
      onRefresh: cargarDatos,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ventas & Asesores",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (String valor) {
                    if (valor == 'Personalizado') {
                      _seleccionarRangoPersonalizado();
                    } else {
                      setState(() => filtroTiempo = valor);
                      cargarDatos();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          etiquetaFiltro,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'Hoy',
                          child: Text('Hoy'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Esta Semana',
                          child: Text('Esta Semana'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Este Mes',
                          child: Text('Este Mes'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Mes Pasado',
                          child: Text('Mes Pasado'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'Personalizado',
                          child: Text('📅 Rango Personalizado...'),
                        ),
                      ],
                ),
              ],
            ).animate().fade().slideY(begin: -0.2, end: 0),

            const SizedBox(height: 20),

            Row(
              children: [
                _buildModernKPI(
                  "Volumen Vendido",
                  "${totalProgramado.toStringAsFixed(1)} m³",
                  Icons.monetization_on_rounded,
                  AppColors.success,
                ),
                const SizedBox(width: 15),
                _buildModernKPI(
                  "Clientes/Atenciones",
                  "$totalClientesGenerados",
                  Icons.groups_rounded,
                  const Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (asesoresOrdenados.isNotEmpty) ...[
              const Text(
                "Rendimiento Comercial",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: cardDecoration(),
                child: Column(
                  children: asesoresOrdenados.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var asesor = entry.value;
                    int atenciones = atencionesPorAsesor[asesor.key] ?? 0;
                    double proporcion = maxVolumenAsesor > 0
                        ? (asesor.value / maxVolumenAsesor)
                        : 0;

                    Widget iconoPosicion;
                    if (idx == 0) {
                      iconoPosicion = const Text(
                        "🥇",
                        style: TextStyle(fontSize: 24),
                      );
                    } else if (idx == 1)
                      iconoPosicion = const Text(
                        "🥈",
                        style: TextStyle(fontSize: 24),
                      );
                    else if (idx == 2)
                      iconoPosicion = const Text(
                        "🥉",
                        style: TextStyle(fontSize: 24),
                      );
                    else
                      iconoPosicion = Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );

                    return InkWell(
                      onTap: () => _mostrarDetalleAsesor(asesor.key),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 18,
                          top: 8,
                          left: 4,
                          right: 4,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 35,
                              child: Center(child: iconoPosicion),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          asesor.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        "${asesor.value.toStringAsFixed(1)} m³",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: idx == 0
                                              ? Colors.green.shade700
                                              : AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: proporcion,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 800,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: idx == 0
                                                  ? [
                                                      Colors.green.shade400,
                                                      Colors.green.shade600,
                                                    ]
                                                  : [
                                                      AppColors.accent,
                                                      Colors.indigo.shade600,
                                                    ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$atenciones clientes atendidos",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_off_rounded,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "No hay datos de asesores en este periodo",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernKPI(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 15),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DEL PORTAFOLIO DEL ASESOR
// ==========================================

class _PortafolioAsesorModal extends StatefulWidget {
  final String asesor;
  final List ventasFiltradas;
  final List despachosFiltrados;

  const _PortafolioAsesorModal({
    required this.asesor,
    required this.ventasFiltradas,
    required this.despachosFiltrados,
  });

  @override
  State<_PortafolioAsesorModal> createState() => _PortafolioAsesorModalState();
}

class _PortafolioAsesorModalState extends State<_PortafolioAsesorModal> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    List ventasAsesor = widget.ventasFiltradas.where((v) {
      String a =
          v["asesor_comercial"]?.toString().toUpperCase() ?? "SIN ASIGNAR";
      if (a.trim().isEmpty || a == "NULL") a = "SIN ASIGNAR";
      return a == widget.asesor;
    }).toList();

    List validosOriginales = ventasAsesor
        .where(
          (v) =>
              v["numero_atencion"]?.toString() != "0" &&
              v["estado"]?.toString().toUpperCase() != "CANCELADO",
        )
        .toList();
    List canceladosOriginales = ventasAsesor
        .where(
          (v) =>
              v["numero_atencion"]?.toString() == "0" ||
              v["estado"]?.toString().toUpperCase() == "CANCELADO",
        )
        .toList();

    List validos = validosOriginales
        .where(
          (v) => (v["nombre_razon_social"] ?? "").toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
    List cancelados = canceladosOriginales
        .where(
          (v) => (v["nombre_razon_social"] ?? "").toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 24.0,
                left: 24.0,
                right: 24.0,
                bottom: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Portafolio del Asesor",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.asesor,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${validosOriginales.length} Efectivos",
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${canceladosOriginales.length} Caídos",
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Buscar cliente o proyecto...",
                  prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.indigo,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),
            const TabBar(
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
              tabs: [
                Tab(text: "Efectivos"),
                Tab(text: "Cancelados"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildListaClientes(validos, true),
                  _buildListaClientes(cancelados, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaClientes(List lista, bool esValido) {
    if (lista.isEmpty) {
      return Center(
        child: Text(
          "No hay registros",
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final v = lista[i];
        double volProgramado = limpiarYExtraerNumero(v["volumen"]);
        String nombreCliente = v["nombre_razon_social"] ?? "Sin Cliente";
        String bombaAsignadaApp = v["bomba_asignada_real"] ?? "POR ASIGNAR";

        List despachosReales = widget.despachosFiltrados
            .where(
              (d) =>
                  (d["cliente"]?.toString().toUpperCase() ??
                      d["nombre_razon_social"]?.toString().toUpperCase() ??
                      "") ==
                  nombreCliente.toUpperCase(),
            )
            .toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            shape: const Border(),
            leading: CircleAvatar(
              backgroundColor: esValido
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Icon(
                esValido ? Icons.check_circle : Icons.cancel,
                color: esValido ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              nombreCliente,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                "📅 Fecha: ${v["fecha_entrega"] ?? '-'}\n🏗️ Obra: ${v["direccion"] ?? 'S/D'} \n⚙️ F'c: ${v["diseno"] ?? '-'} | Prog: ${volProgramado.toStringAsFixed(1)} m³",
                style: const TextStyle(height: 1.4),
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "🚚 Despachos Reales Ejecutados:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (despachosReales.isEmpty)
                      const Text(
                        "No hay guías de despacho registradas aún.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      )
                    else
                      ...despachosReales.map((d) {
                        double volDespachado = limpiarYExtraerNumero(
                          d["volumen_guias"],
                        );
                        if (volDespachado == 0) {
                          volDespachado = limpiarYExtraerNumero(d["volumen"]);
                        }
                        String operador = d["operador"] ?? "S/O";

                        String optimizadoRaw =
                            d["optimizado"]?.toString() ?? "";
                        bool tieneOptimizado =
                            optimizadoRaw.isNotEmpty &&
                            optimizadoRaw.toLowerCase() != "null" &&
                            optimizadoRaw != "-";

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Op: $operador | Bomba: $bombaAsignadaApp",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (tieneOptimizado)
                                      Text(
                                        "Opt: $optimizadoRaw",
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                "${volDespachado.toStringAsFixed(1)} m³",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.teal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
