// Archivo: lib/screens/dashboard/dashboard_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';

class DashboardGerencial extends StatefulWidget {
  const DashboardGerencial({super.key});
  @override
  State<DashboardGerencial> createState() => _DashboardGerencialState();
}

class _DashboardGerencialState extends State<DashboardGerencial> {
  final supabase = Supabase.instance.client;

  List ventasFiltradas = [];
  List despachosFiltrados = [];

  String filtroTiempo = 'Este Mes';
  String etiquetaFiltro = 'Este Mes';
  DateTime? fechaInicioFiltro;
  DateTime? fechaFinFiltro;

  double totalProgramado = 0;
  double totalDespachado = 0;
  Map<String, double> volumenPorMixer = {};
  Map<String, double> volumenPorOperador = {};
  Map<String, String> operadorMixer = {};

  int vistaActiva = 0; // 0 = Operaciones, 1 = Cancelados

  double totalVolumenCancelado = 0;
  int totalObrasCanceladas = 0;
  List listaObrasCanceladas = [];

  bool loading = true;

  final List<Color> mixerColors = [
    const Color(0xFF4F46E5),
    const Color(0xFF0D9488),
    const Color(0xFFF59E0B),
    const Color(0xFFE11D48),
    const Color(0xFF0284C7),
    const Color(0xFF7C3AED),
    const Color(0xFF16A34A),
    const Color(0xFFD97706),
  ];

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
        _calcularMetricas();
      }
    } catch (e) {
      debugPrint("Error Dashboard: $e");
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

    if (!context.mounted) return;
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

  void _calcularMetricas() {
    double prog = 0;
    double desp = 0;
    Map<String, double> vMixer = {};
    Map<String, double> vOperador = {};
    Map<String, String> oMixer = {};

    double volCaidoTemp = 0;
    List listaCaidosTemp = [];

    for (var i in ventasFiltradas) {
      bool esCancelado =
          i["numero_atencion"]?.toString() == "0" ||
          i["estado"]?.toString().toUpperCase() == "CANCELADO";

      if (!esCancelado) {
        double vol = limpiarYExtraerNumero(i["volumen"]);
        prog += vol;
      } else {
        double volCaido = limpiarYExtraerNumero(i["volumen"]);
        volCaidoTemp += volCaido;
        listaCaidosTemp.add(i);
      }
    }

    for (var i in despachosFiltrados) {
      var valorGuias =
          i["volumen_guias"] ?? i["volumen guias"] ?? i["VOLUMEN GUIAS"];
      double vol = limpiarYExtraerNumero(valorGuias);
      if (vol == 0.0) {
        var valorNormal = i["volumen"] ?? i["VOLUMEN"];
        vol = limpiarYExtraerNumero(valorNormal);
      }

      desp += vol;

      if (vol > 0) {
        String mixer = i["mixer"]?.toString() ?? "Sin Mixer";
        vMixer[mixer] = (vMixer[mixer] ?? 0) + vol;
        String operador = i["operador"]?.toString() ?? "Sin Operador";
        vOperador[operador] = (vOperador[operador] ?? 0) + vol;

        if (mixer != "Sin Mixer" && mixer.trim().isNotEmpty) {
          oMixer[operador] = mixer;
        }
      }
    }

    listaCaidosTemp.sort((a, b) {
      String fA = a["fecha_entrega"] ?? "";
      String fB = b["fecha_entrega"] ?? "";
      return fB.compareTo(fA);
    });

    setState(() {
      totalProgramado = prog;
      totalDespachado = desp;
      volumenPorMixer = vMixer;
      volumenPorOperador = vOperador;
      operadorMixer = oMixer;
      totalVolumenCancelado = volCaidoTemp;
      totalObrasCanceladas = listaCaidosTemp.length;
      listaObrasCanceladas = listaCaidosTemp;
    });
  }

  Future<void> _generarExcel(List datosExportar, String nombreArchivo) async {
    // ... [Tu código de Excel se mantiene exactamente igual] ...
    // (Omitido aquí para no hacer larguísima la respuesta, pero no se toca nada de la función)
  }

  void _mostrarViajesDelMixer(String mixerNombre) {
    // ... [Tu código del modal de mixer se mantiene igual] ...
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: cargarDatos,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 15,
              runSpacing: 15,
              children: [
                Text(
                  "Dashboard",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: AppColors.success,
                        size: 28,
                      ),
                      tooltip: "Descargar Todos los Viajes a Excel",
                      onPressed: () => _generarExcel(
                        despachosFiltrados,
                        "Reporte_Global_Planta",
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.date_range,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              etiquetaFiltro,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
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
                ),
              ],
            ).animate().fade().slideY(begin: -0.2, end: 0),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton("🏗️ Operaciones", 0)),
                  Expanded(child: _buildTabButton("🚫 Cancelados", 1)),
                ],
              ),
            ).animate().fade().scale(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: vistaActiva == 0
                  ? _buildVistaOperaciones()
                  : _buildVistaCancelados(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String titulo, int indice) {
    bool activo = vistaActiva == indice;
    return GestureDetector(
      onTap: () => setState(() => vistaActiva = indice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? Theme.of(context).cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: activo ? AppColors.accent : Colors.grey.shade600,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildVistaOperaciones() {
    var operadoresOrdenados = volumenPorOperador.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _buildModernKPI(
                      "Programado",
                      "${totalProgramado.toStringAsFixed(1)} m³",
                      Icons.insert_chart,
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: _buildModernKPI(
                      "Despachado",
                      "${totalDespachado.toStringAsFixed(1)} m³",
                      Icons.local_shipping,
                      const Color(0xFF0D9488),
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _buildModernKPI(
                    "Programado",
                    "${totalProgramado.toStringAsFixed(1)} m³",
                    Icons.insert_chart,
                    AppColors.accent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildModernKPI(
                    "Despachado",
                    "${totalDespachado.toStringAsFixed(1)} m³",
                    Icons.local_shipping,
                    const Color(0xFF0D9488),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        if (volumenPorMixer.isNotEmpty) ...[
          Text(
            "Rendimiento por Mixer",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 600;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: cardDecoration(context),
                child: Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  children: [
                    if (isMobile)
                      SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: _buildPieChartMixer(),
                      )
                    else
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 220,
                          child: _buildPieChartMixer(),
                        ),
                      ),
                    if (isMobile) const SizedBox(height: 20),
                    if (isMobile)
                      SizedBox(height: 200, child: _buildListMixer())
                    else
                      Expanded(
                        flex: 5,
                        child: SizedBox(height: 220, child: _buildListMixer()),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        if (operadoresOrdenados.isNotEmpty) ...[
          Text(
            "Ranking Global de Operadores",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(context),
            child: Column(
              children: operadoresOrdenados.asMap().entries.map((entry) {
                int idx = entry.key;
                var op = entry.value;
                Widget iconoPosicion;
                if (idx == 0) {
                  iconoPosicion = const Text(
                    "🥇",
                    style: TextStyle(fontSize: 28),
                  );
                } else if (idx == 1)
                  iconoPosicion = const Text(
                    "🥈",
                    style: TextStyle(fontSize: 28),
                  );
                else if (idx == 2)
                  iconoPosicion = const Text(
                    "🥉",
                    style: TextStyle(fontSize: 28),
                  );
                else
                  iconoPosicion = CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade100,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    leading: SizedBox(
                      width: 40,
                      child: Center(child: iconoPosicion),
                    ),
                    title: Text(
                      "${op.key} ${operadorMixer[op.key] != null ? '(${operadorMixer[op.key]})' : ''}",
                      style: TextStyle(
                        fontWeight: idx < 3 ? FontWeight.w900 : FontWeight.w600,
                        fontSize: idx < 3 ? 16 : 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    trailing: Text(
                      "${op.value.toStringAsFixed(1)} m³",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: idx == 0
                            ? const Color(0xFFB59410)
                            : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVistaCancelados() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _buildModernKPI(
                      "Volumen Caído",
                      "${totalVolumenCancelado.toStringAsFixed(1)} m³",
                      Icons.trending_down,
                      Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: _buildModernKPI(
                      "Clientes Cancelados",
                      "$totalObrasCanceladas",
                      Icons.person_off,
                      Colors.orange.shade800,
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Flexible(
                  child: _buildModernKPI(
                    "Volumen Caído",
                    "${totalVolumenCancelado.toStringAsFixed(1)} m³",
                    Icons.trending_down,
                    Colors.red.shade600,
                  ),
                ),
                const SizedBox(width: 15),
                Flexible(
                  child: _buildModernKPI(
                    "Clientes Cancelados",
                    "$totalObrasCanceladas",
                    Icons.person_off,
                    Colors.orange.shade800,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        if (listaObrasCanceladas.isNotEmpty) ...[
          Text(
            "Detalle de Cancelaciones",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(context),
            child: Column(
              children: listaObrasCanceladas.map((obra) {
                double vol = limpiarYExtraerNumero(obra["volumen"]);
                String asesor =
                    obra["asesor_comercial"]?.toString().toUpperCase() ??
                    "SIN ASIGNAR";
                if (asesor.trim().isEmpty || asesor == "NULL") {
                  asesor = "SIN ASIGNAR";
                }

                String disenoRaw = obra["diseno"]?.toString() ?? "210";
                String diseno = disenoRaw
                    .toUpperCase()
                    .replaceAll("F'C=", "")
                    .replaceAll("F'C =", "")
                    .trim();

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: Icon(
                        Icons.block,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      obra["nombre_razon_social"] ?? "Sin Cliente",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Fecha: ${obra["fecha_entrega"] ?? '-'} | Asesor: $asesor\nF'c= $diseno | ${obra["elemento"] ?? ''}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Text(
                      "${vol.toStringAsFixed(1)} m³",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Colors.red.shade700,
                      ),
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
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "¡Excelente! No hay cancelaciones.",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModernKPI(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(context),
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
    );
  }

  Widget _buildPieChartMixer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 45,
            startDegreeOffset: 180,
            sections: volumenPorMixer.entries.map((e) {
              int idx = volumenPorMixer.keys.toList().indexOf(e.key);
              return PieChartSectionData(
                color: mixerColors[idx % mixerColors.length],
                value: e.value,
                title: e.value.toStringAsFixed(1),
                radius: 40,
                titleStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                badgePositionPercentageOffset: .98,
              );
            }).toList(),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fire_truck, size: 18, color: Colors.grey),
            Text(
              "${totalDespachado.toStringAsFixed(1)} m³",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListMixer() {
    return ListView(
      children: volumenPorMixer.entries.map((e) {
        int idx = volumenPorMixer.keys.toList().indexOf(e.key);
        Color c = mixerColors[idx % mixerColors.length];
        return InkWell(
          onTap: () => _mostrarViajesDelMixer(e.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                Text(
                  "${e.value.toStringAsFixed(1)} m³",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ... EL RESTO DEL ARCHIVO QUEDA IGUAL (_PortafolioAsesorModal, etc.)

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
