import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/services/disenos_service.dart';

class DisenosMezclaPage extends StatefulWidget {
  const DisenosMezclaPage({super.key});

  @override
  State<DisenosMezclaPage> createState() => _DisenosMezclaPageState();
}

class _DisenosMezclaPageState extends State<DisenosMezclaPage> {
  final _service = DisenosService();
  bool loading = true;
  bool sincronizando = false;
  List<Map<String, dynamic>> disenos = [];
  String searchQuery = "";
  List<String> activos = [];

  @override
  void initState() {
    super.initState();
    cargarDisenos();
  }

  Future<void> cargarDisenos({bool forceDrive = false}) async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      activos = prefs.getStringList('disenos_activos') ?? [];

      final data = await _service.obtenerDisenos(forceDrive: forceDrive);
      if (mounted) {
        setState(() {
          disenos = data;
          loading = false;
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Error al cargar diseños: $e', isError: true);
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> eliminarDiseno(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Eliminar Diseño"),
        content: const Text("¿Estás seguro de eliminar este diseño? No se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.eliminarDiseno(id);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Diseño eliminado correctamente');
      cargarDisenos();
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Error: $e', isError: true);
    }
  }

  void abrirFormulario([Map<String, dynamic>? disenoExistente]) {
    showDialog(
      context: context,
      builder: (context) => _FormularioDiseno(
        disenoExistente: disenoExistente,
        onGuardado: cargarDisenos,
      ),
    );
  }

  void abrirAjustePorcentajes(Map<String, dynamic> diseno) {
    showDialog(
      context: context,
      builder: (context) => _DialogAjustarPorcentajes(
        diseno: diseno,
        onGuardado: cargarDisenos,
      ),
    );
  }

  Future<void> toggleActivo(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (activos.contains(id)) {
      activos.remove(id);
    } else {
      activos.add(id);
    }
    await prefs.setStringList('disenos_activos', activos);
    setState(() {});
  }

  /// Sincroniza e importa los diseños de mezcla directamente desde Google Drive / Google Sheets
  Future<void> sincronizarDesdeGoogleSheets() async {
    setState(() => sincronizando = true);
    try {
      final recetas = await _service.sincronizarDesdeGoogleSheets();
      if (!mounted) return;
      setState(() {
        disenos = recetas;
        sincronizando = false;
      });
      Helpers.showSnackBar(
        context,
        '✅ ${recetas.length} recetas sincronizadas directamente desde Google Drive y listas para producción.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => sincronizando = false);
        Helpers.showSnackBar(context, 'Error al sincronizar con Drive: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = disenos.where((d) {
      final str = "${d['huso']} ${d['tipo_vaciado']} ${d['resistencia']}".toLowerCase();
      return str.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Diseños de Mezcla (Recetas)",
          style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        actions: [
          Tooltip(
            message: "Sincronizar directamente desde Google Drive",
            child: sincronizando
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.accent),
                    onPressed: sincronizarDesdeGoogleSheets,
                  ),
          ),
          IconButton(
            tooltip: "Recargar",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => cargarDisenos(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Buscar por Resistencia, Huso o Tipo...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => setState(() => searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => abrirFormulario(),
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        label: const Text("Nuevo Diseño", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text("No se encontraron diseños de mezcla", style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.cloud_download_outlined),
                                  label: const Text("Descargar recetas desde Google Drive"),
                                  onPressed: sincronizarDesdeGoogleSheets,
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth > 1200
                                  ? 3
                                  : (constraints.maxWidth > 750 ? 2 : 1);
                              return GridView.builder(
                                padding: const EdgeInsets.only(top: 4, bottom: 32),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 380, // Altura adecuada para celdas cuadradas
                                ),
                                itemCount: filtrados.length,
                                itemBuilder: (context, index) {
                                  final d = filtrados[index];
                                  final idStr = d['id'].toString();
                                  final isActivo = activos.contains(idStr);

                                  final cemento = double.tryParse(d['cemento_kg']?.toString() ?? '0') ?? 0.0;
                                  final arena = double.tryParse(d['arena_kg']?.toString() ?? '0') ?? 0.0;
                                  final piedraTotal = double.tryParse(d['piedra_total_kg']?.toString() ?? '0') ?? 0.0;
                                  final pct12 = double.tryParse(d['piedra_12_porcentaje']?.toString() ?? '100') ?? 100.0;
                                  final pct34 = double.tryParse(d['piedra_34_porcentaje']?.toString() ?? '0') ?? 0.0;
                                  final pct38 = double.tryParse(d['piedra_38_porcentaje']?.toString() ?? '0') ?? 0.0;
                                  final pctA1 = double.tryParse(d['arena_1_porcentaje']?.toString() ?? '100') ?? 100.0;
                                  final agua = double.tryParse(d['agua_lt']?.toString() ?? '0') ?? 0.0;
                                  final aditivo = double.tryParse(d['aditivo_kg']?.toString() ?? '0') ?? 0.0;

                                  final piedra12Kg = piedraTotal * (pct12 / 100.0);
                                  final piedra34Kg = piedraTotal * (pct34 / 100.0);
                                  final piedra38Kg = piedraTotal * (pct38 / 100.0);

                                  return Card(
                                    elevation: isActivo ? 5 : 2,
                                    shadowColor: isActivo ? AppColors.success.withOpacity(0.3) : Colors.black12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: isActivo
                                          ? const BorderSide(color: AppColors.success, width: 2)
                                          : BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: isActivo ? AppColors.success.withOpacity(0.03) : Colors.white,
                                      ),
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header de la tarjeta
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryDark,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  "f'c ${d['resistencia']}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Wrap(
                                                      spacing: 6,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.shade50,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            "Huso ${d['huso']}",
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.blue.shade800,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFE0F2FE),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            "${d['tipo_vaciado']}",
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFF004899),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                                splashRadius: 20,
                                                onSelected: (val) {
                                                  if (val == 'edit') abrirFormulario(d);
                                                  if (val == 'pct') abrirAjustePorcentajes(d);
                                                  if (val == 'delete') eliminarDiseno(d['id'].toString());
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'pct',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.tune, size: 18, color: AppColors.accent),
                                                        SizedBox(width: 8),
                                                        Text("Modificar Porcentajes (%)"),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                                                        SizedBox(width: 8),
                                                        Text("Editar Receta"),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete, size: 18, color: AppColors.error),
                                                        SizedBox(width: 8),
                                                        Text("Eliminar"),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Barra de acción rápida: Activo y Modificar %
                                          Row(
                                            children: [
                                              if (isActivo)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check, size: 12, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text("PLANTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                                    ],
                                                  ),
                                                ),
                                              const Spacer(),
                                              // Botón rápido para modificar porcentajes de agregados
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.accent,
                                                  side: const BorderSide(color: AppColors.accent),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () => abrirAjustePorcentajes(d),
                                                icon: const Icon(Icons.tune, size: 14),
                                                label: const Text("Modificar %", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 6),
                                              // Botón activar/desactivar
                                              InkWell(
                                                onTap: () => toggleActivo(idStr),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: isActivo ? Colors.grey.shade400 : AppColors.success),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    isActivo ? "Desactivar" : "Activar",
                                                    style: TextStyle(
                                                      color: isActivo ? Colors.grey.shade600 : AppColors.success,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(height: 1, thickness: 1),
                                          const SizedBox(height: 10),

                                          // Celdas Cuadradas de Dosificación (Vista Planta por m³)
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (ctx, box) {
                                                return SingleChildScrollView(
                                                  child: Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: [
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "CEMENTO",
                                                        valor: "${cemento.toStringAsFixed(0)} kg",
                                                        icon: Icons.square_outlined,
                                                        color: const Color(0xFF1E293B),
                                                        bgColor: const Color(0xFFF1F5F9),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "ARENA",
                                                        valor: "${arena.toStringAsFixed(0)} kg",
                                                        subtexto: "A1: ${pctA1.toStringAsFixed(0)}%",
                                                        icon: Icons.grain,
                                                        color: Colors.amber.shade800,
                                                        bgColor: const Color(0xFFFFFBEB),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "PIEDRA 1/2",
                                                        valor: "${piedra12Kg.toStringAsFixed(0)} kg",
                                                        subtexto: "${pct12.toStringAsFixed(0)}%",
                                                        icon: Icons.terrain,
                                                        color: Colors.deepOrange.shade700,
                                                        bgColor: const Color(0xFFFFF7ED),
                                                        onTap: () => abrirAjustePorcentajes(d),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "PIEDRA 3/4",
                                                        valor: "${piedra34Kg.toStringAsFixed(0)} kg",
                                                        subtexto: "${pct34.toStringAsFixed(0)}%",
                                                        icon: Icons.terrain,
                                                        color: Colors.brown.shade700,
                                                        bgColor: const Color(0xFFFDF4E7),
                                                        onTap: () => abrirAjustePorcentajes(d),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "PIEDRA 3/8",
                                                        valor: "${piedra38Kg.toStringAsFixed(0)} kg",
                                                        subtexto: "${pct38.toStringAsFixed(0)}%",
                                                        icon: Icons.terrain,
                                                        color: Colors.blueGrey.shade700,
                                                        bgColor: const Color(0xFFF8FAFC),
                                                        onTap: () => abrirAjustePorcentajes(d),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "AGUA",
                                                        valor: "${agua.toStringAsFixed(0)} L",
                                                        icon: Icons.water_drop,
                                                        color: const Color(0xFF0284C7),
                                                        bgColor: const Color(0xFFF0F9FF),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "ADITIVO",
                                                        valor: "${aditivo.toStringAsFixed(2)} kg",
                                                        icon: Icons.science,
                                                        color: Colors.purple.shade700,
                                                        bgColor: const Color(0xFFFAF5FF),
                                                      ),
                                                      _CeldaCuadradaDosificacion(
                                                        titulo: "TOT PIEDRA",
                                                        valor: "${piedraTotal.toStringAsFixed(0)} kg",
                                                        subtexto: "100%",
                                                        icon: Icons.layers,
                                                        color: Colors.teal.shade700,
                                                        bgColor: const Color(0xFFF0FDFA),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Celda cuadrada compacta de dosificación para pantalla de planta
class _CeldaCuadradaDosificacion extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? subtexto;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _CeldaCuadradaDosificacion({
    required this.titulo,
    required this.valor,
    this.subtexto,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 84,
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (subtexto != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  subtexto!,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// Diálogo interactivo para modificar porcentajes de agregados en planta
class _DialogAjustarPorcentajes extends StatefulWidget {
  final Map<String, dynamic> diseno;
  final VoidCallback onGuardado;

  const _DialogAjustarPorcentajes({required this.diseno, required this.onGuardado});

  @override
  State<_DialogAjustarPorcentajes> createState() => _DialogAjustarPorcentajesState();
}

class _DialogAjustarPorcentajesState extends State<_DialogAjustarPorcentajes> {
  final _service = DisenosService();

  late TextEditingController cPct12;
  late TextEditingController cPct34;
  late TextEditingController cPct38;
  late TextEditingController cPctA1;
  late TextEditingController cPctA2;

  bool guardando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.diseno;
    cPct12 = TextEditingController(text: (d['piedra_12_porcentaje'] ?? 100).toString());
    cPct34 = TextEditingController(text: (d['piedra_34_porcentaje'] ?? 0).toString());
    cPct38 = TextEditingController(text: (d['piedra_38_porcentaje'] ?? 0).toString());
    cPctA1 = TextEditingController(text: (d['arena_1_porcentaje'] ?? 100).toString());
    cPctA2 = TextEditingController(text: (d['arena_2_porcentaje'] ?? 0).toString());
  }

  @override
  void dispose() {
    cPct12.dispose();
    cPct34.dispose();
    cPct38.dispose();
    cPctA1.dispose();
    cPctA2.dispose();
    super.dispose();
  }

  void _aplicarPresetPiedra(double p12, double p34, double p38) {
    setState(() {
      cPct12.text = p12.toStringAsFixed(0);
      cPct34.text = p34.toStringAsFixed(0);
      cPct38.text = p38.toStringAsFixed(0);
    });
  }

  Future<void> _guardar() async {
    final p12 = double.tryParse(cPct12.text.replaceAll(',', '.')) ?? 0.0;
    final p34 = double.tryParse(cPct34.text.replaceAll(',', '.')) ?? 0.0;
    final p38 = double.tryParse(cPct38.text.replaceAll(',', '.')) ?? 0.0;

    final sumaPiedras = p12 + p34 + p38;
    if ((sumaPiedras - 100.0).abs() > 0.5) {
      Helpers.showSnackBar(
        context,
        'La suma de porcentajes de piedras debe ser exactamente 100% (actual: ${sumaPiedras.toStringAsFixed(1)}%)',
        isError: true,
      );
      return;
    }

    final a1 = double.tryParse(cPctA1.text.replaceAll(',', '.')) ?? 100.0;
    final a2 = double.tryParse(cPctA2.text.replaceAll(',', '.')) ?? 0.0;
    final sumaArenas = a1 + a2;
    if ((sumaArenas - 100.0).abs() > 0.5) {
      Helpers.showSnackBar(
        context,
        'La suma de porcentajes de arena debe ser exactamente 100% (actual: ${sumaArenas.toStringAsFixed(1)}%)',
        isError: true,
      );
      return;
    }

    setState(() => guardando = true);
    try {
      await _service.actualizarPorcentajes(
        id: widget.diseno['id'],
        p12: p12,
        p34: p34,
        p38: p38,
        a1: a1,
        a2: a2,
      );

      widget.onGuardado();
      if (!mounted) return;
      Navigator.pop(context);
      Helpers.showSnackBar(
        context,
        '✅ Porcentajes actualizados para f\'c ${widget.diseno['resistencia']}. Los nuevos carguíos usarán esta dosificación.',
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(context, 'Error al guardar porcentajes: $e', isError: true);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diseno;
    final piedraTotal = double.tryParse(d['piedra_total_kg']?.toString() ?? '0') ?? 0.0;
    final arenaTotal = double.tryParse(d['arena_kg']?.toString() ?? '0') ?? 0.0;

    final p12Val = double.tryParse(cPct12.text.replaceAll(',', '.')) ?? 0.0;
    final p34Val = double.tryParse(cPct34.text.replaceAll(',', '.')) ?? 0.0;
    final p38Val = double.tryParse(cPct38.text.replaceAll(',', '.')) ?? 0.0;
    final sumaPiedras = p12Val + p34Val + p38Val;
    final piedrasOk = (sumaPiedras - 100.0).abs() <= 0.5;

    final p12KgPreview = piedraTotal * (p12Val / 100.0);
    final p34KgPreview = piedraTotal * (p34Val / 100.0);
    final p38KgPreview = piedraTotal * (p38Val / 100.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Modificar % Agregados · f'c ${d['resistencia']}",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Huso ${d['huso']} • ${d['tipo_vaciado']} (Planta de Carguío)",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terrain, size: 18, color: Colors.brown),
                        const SizedBox(width: 8),
                        Text(
                          "Distribución de Piedras (Total: ${piedraTotal.toStringAsFixed(0)} kg/m³)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Presets comunes de planta:",
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text("100% 1/2", style: TextStyle(fontSize: 11)),
                          onPressed: () => _aplicarPresetPiedra(100, 0, 0),
                        ),
                        ActionChip(
                          label: const Text("75% 1/2 - 25% 3/4", style: TextStyle(fontSize: 11)),
                          onPressed: () => _aplicarPresetPiedra(75, 25, 0),
                        ),
                        ActionChip(
                          label: const Text("70% 1/2 - 30% 3/4", style: TextStyle(fontSize: 11)),
                          onPressed: () => _aplicarPresetPiedra(70, 30, 0),
                        ),
                        ActionChip(
                          label: const Text("65% 1/2 - 35% 3/4", style: TextStyle(fontSize: 11)),
                          onPressed: () => _aplicarPresetPiedra(65, 35, 0),
                        ),
                        ActionChip(
                          label: const Text("50% 1/2 - 50% 3/4", style: TextStyle(fontSize: 11)),
                          onPressed: () => _aplicarPresetPiedra(50, 50, 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPctInput("% Piedra 1/2", cPct12, (v) => setState(() {})),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPctInput("% Piedra 3/4", cPct34, (v) => setState(() {})),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPctInput("% Piedra 3/8", cPct38, (v) => setState(() {})),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: piedrasOk ? AppColors.success.withOpacity(0.08) : AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: piedrasOk ? AppColors.success.withOpacity(0.4) : AppColors.error.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                piedrasOk ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 16,
                                color: piedrasOk ? AppColors.success : AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Suma: ${sumaPiedras.toStringAsFixed(1)}% ${piedrasOk ? '(Correcto 100%)' : '(Debe ser 100%)'}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: piedrasOk ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("1/2: ${p12KgPreview.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              Text("3/4: ${p34KgPreview.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              Text("3/8: ${p38KgPreview.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.grain, size: 18, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Text(
                          "Distribución de Arena (Total: ${arenaTotal.toStringAsFixed(0)} kg/m³)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPctInput("% Arena 1 (Fina)", cPctA1, (v) => setState(() {})),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPctInput("% Arena 2 (Gruesa)", cPctA2, (v) => setState(() {})),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: piedrasOk ? AppColors.accent : Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: (guardando || !piedrasOk) ? null : _guardar,
                    icon: guardando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save, size: 18),
                    label: const Text("Guardar Porcentajes"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPctInput(String label, TextEditingController controller, ValueChanged<String> onChanged) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        suffixText: "%",
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

/// Formulario completo para crear o editar la receta base
class _FormularioDiseno extends StatefulWidget {
  final Map<String, dynamic>? disenoExistente;
  final VoidCallback onGuardado;

  const _FormularioDiseno({this.disenoExistente, required this.onGuardado});

  @override
  State<_FormularioDiseno> createState() => _FormularioDisenoState();
}

class _FormularioDisenoState extends State<_FormularioDiseno> {
  final _service = DisenosService();
  final formKey = GlobalKey<FormState>();

  final cHuso = TextEditingController(text: "67");
  final cTipoVaciado = TextEditingController(text: "BOMBEABLE");
  final cResistencia = TextEditingController();
  final cCemento = TextEditingController();
  final cArena = TextEditingController();
  final cPiedraTotal = TextEditingController();
  final cAgua = TextEditingController();
  final cAditivo = TextEditingController();

  final cPctPiedra12 = TextEditingController(text: "100");
  final cPctPiedra34 = TextEditingController(text: "0");
  final cPctPiedra38 = TextEditingController(text: "0");
  final cPctArena1 = TextEditingController(text: "100");
  final cPctArena2 = TextEditingController(text: "0");

  bool guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.disenoExistente != null) {
      final d = widget.disenoExistente!;
      cHuso.text = d['huso'].toString();
      cTipoVaciado.text = d['tipo_vaciado'].toString();
      cResistencia.text = d['resistencia'].toString();
      cCemento.text = d['cemento_kg'].toString();
      cArena.text = d['arena_kg'].toString();
      cPiedraTotal.text = d['piedra_total_kg'].toString();
      cAgua.text = d['agua_lt'].toString();
      cAditivo.text = d['aditivo_kg'].toString();

      cPctPiedra12.text = (d['piedra_12_porcentaje'] ?? 100).toString();
      cPctPiedra34.text = (d['piedra_34_porcentaje'] ?? 0).toString();
      cPctPiedra38.text = (d['piedra_38_porcentaje'] ?? 0).toString();
      cPctArena1.text = (d['arena_1_porcentaje'] ?? 100).toString();
      cPctArena2.text = (d['arena_2_porcentaje'] ?? 0).toString();
    }
  }

  Future<void> guardar() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => guardando = true);

    final payload = {
      'huso': cHuso.text.trim(),
      'tipo_vaciado': cTipoVaciado.text.trim().toUpperCase(),
      'resistencia': cResistencia.text.trim(),
      'cemento_kg': double.tryParse(cCemento.text) ?? 0,
      'arena_kg': double.tryParse(cArena.text) ?? 0,
      'piedra_total_kg': double.tryParse(cPiedraTotal.text) ?? 0,
      'agua_lt': double.tryParse(cAgua.text) ?? 0,
      'aditivo_kg': double.tryParse(cAditivo.text) ?? 0,
      'piedra_12_porcentaje': double.tryParse(cPctPiedra12.text) ?? 0,
      'piedra_34_porcentaje': double.tryParse(cPctPiedra34.text) ?? 0,
      'piedra_38_porcentaje': double.tryParse(cPctPiedra38.text) ?? 0,
      'arena_1_porcentaje': double.tryParse(cPctArena1.text) ?? 0,
      'arena_2_porcentaje': double.tryParse(cPctArena2.text) ?? 0,
    };

    try {
      await _service.guardarDiseno(payload, idExistente: widget.disenoExistente?['id']);
      widget.onGuardado();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Error al guardar: $e', isError: true);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.science, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.disenoExistente == null ? "Nuevo Diseño de Mezcla" : "Editar Diseño",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Información General", Icons.info_outline),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildInput("F'C (Ej. 210, 280)", cResistencia, Icons.compress)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("Huso (Ej. 67, 57)", cHuso, Icons.tag)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("Tipo (BOMBEABLE / DIRECTO)", cTipoVaciado, Icons.category)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Cantidades Base (por m³)", Icons.scale),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildInput("Cemento (kg)", cCemento, Icons.square_outlined, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("Arena Total (kg)", cArena, Icons.grain, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("Piedra Total (kg)", cPiedraTotal, Icons.terrain, true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildInput("Agua (Lt)", cAgua, Icons.water_drop, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("Aditivo (kg)", cAditivo, Icons.science, true)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Porcentajes de División (%)", Icons.pie_chart),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildInput("% Piedra 1/2", cPctPiedra12, Icons.percent, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("% Piedra 3/4", cPctPiedra34, Icons.percent, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("% Piedra 3/8", cPctPiedra38, Icons.percent, true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildInput("% Arena 1", cPctArena1, Icons.percent, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInput("% Arena 2", cPctArena2, Icons.percent, true)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: guardando ? null : guardar,
                    icon: guardando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save, size: 18),
                    label: Text(guardando ? "Guardando..." : "Guardar Diseño"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon, [bool isNumeric = false]) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 18),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: (v) => v!.isEmpty ? 'Requerido' : null,
    );
  }
}
