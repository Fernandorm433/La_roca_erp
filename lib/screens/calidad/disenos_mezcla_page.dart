import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';

class DisenosMezclaPage extends StatefulWidget {
  const DisenosMezclaPage({super.key});

  @override
  State<DisenosMezclaPage> createState() => _DisenosMezclaPageState();
}

class _DisenosMezclaPageState extends State<DisenosMezclaPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List disenos = [];
  String searchQuery = "";
  List<String> activos = [];

  @override
  void initState() {
    super.initState();
    cargarDisenos();
  }

  Future cargarDisenos() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      activos = prefs.getStringList('disenos_activos') ?? [];

      final data = await supabase
          .from('disenos_mezcla')
          .select()
          .order('resistencia', ascending: true);
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

  Future eliminarDiseno(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      await supabase.from('disenos_mezcla').delete().eq('id', id);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Diseño eliminado correctamente');
      cargarDisenos();
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Error: $e', isError: true);
    }
  }

  void abrirFormulario([Map? disenoExistente]) {
    showDialog(
      context: context,
      builder: (context) => _FormularioDiseno(
        disenoExistente: disenoExistente,
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

  @override
  Widget build(BuildContext context) {
    List filtrados = disenos.where((d) {
      final str = "${d['huso']} ${d['tipo_vaciado']} ${d['resistencia']}".toLowerCase();
      return str.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Diseños de Mezcla (Recetas)", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: cargarDisenos),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setState(() => searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => abrirFormulario(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text("Nuevo Diseño", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text("No se encontraron diseños", style: TextStyle(color: Colors.grey)))
                        : GridView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 32),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 350,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              mainAxisExtent: 320, // Incrementado para evitar overflow en móvil
                            ),
                            itemCount: filtrados.length,
                            itemBuilder: (context, index) {
                              final d = filtrados[index];
                              final idStr = d['id'].toString();
                              final isActivo = activos.contains(idStr);

                              return Card(
                                elevation: isActivo ? 6 : 3,
                                shadowColor: isActivo ? AppColors.success.withOpacity(0.4) : Colors.black12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: isActivo ? const BorderSide(color: AppColors.success, width: 2) : BorderSide.none,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: isActivo ? AppColors.success.withOpacity(0.05) : Colors.white,
                                    gradient: isActivo ? null : LinearGradient(
                                      colors: [Colors.white, AppColors.background.withOpacity(0.5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accent.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: const Icon(Icons.receipt_long, color: AppColors.accent),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          "f'c ${d['resistencia']}", 
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          "Huso ${d['huso']} • ${d['tipo_vaciado']}", 
                                                          style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                                              splashRadius: 20,
                                              onSelected: (val) {
                                                if (val == 'edit') abrirFormulario(d);
                                                if (val == 'delete') eliminarDiseno(d['id'].toString());
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20, color: AppColors.accent), SizedBox(width: 8), Text("Editar")])),
                                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: AppColors.error), SizedBox(width: 8), Text("Eliminar")])),
                                              ],
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          alignment: WrapAlignment.spaceBetween,
                                          children: [
                                            if (isActivo)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                                                child: const Text("ACTIVO EN PLANTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                              )
                                            else
                                              const SizedBox(),
                                            InkWell(
                                              onTap: () => toggleActivo(idStr),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: isActivo ? Colors.grey : AppColors.success),
                                                  borderRadius: BorderRadius.circular(20)
                                                ),
                                                child: Text(isActivo ? "Desactivar" : "Fijar como Activo", style: TextStyle(color: isActivo ? Colors.grey : AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                            )
                                          ],
                                        ),
                                        const Divider(height: 16, thickness: 1),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            physics: const NeverScrollableScrollPhysics(),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _IngredienteItem(icon: Icons.square, color: Colors.blueGrey, label: "Cemento", value: "${d['cemento_kg']} kg"),
                                                _IngredienteItem(icon: Icons.grain, color: Colors.amber.shade700, label: "Arena", value: "${d['arena_kg']} kg"),
                                                _IngredienteItem(icon: Icons.terrain, color: Colors.brown.shade400, label: "Piedra", value: "${d['piedra_total_kg']} kg"),
                                                _IngredienteItem(icon: Icons.water_drop, color: Colors.blue.shade400, label: "Agua", value: "${d['agua_lt']} L"),
                                                _IngredienteItem(icon: Icons.science, color: Colors.purple.shade400, label: "Aditivo", value: "${d['aditivo_kg']} kg"),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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

class _IngredienteItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  
  const _IngredienteItem({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormularioDiseno extends StatefulWidget {
  final Map? disenoExistente;
  final VoidCallback onGuardado;

  const _FormularioDiseno({this.disenoExistente, required this.onGuardado});

  @override
  State<_FormularioDiseno> createState() => _FormularioDisenoState();
}

class _FormularioDisenoState extends State<_FormularioDiseno> {
  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();

  final cHuso = TextEditingController();
  final cTipoVaciado = TextEditingController();
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

  Future guardar() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => guardando = true);

    final payload = {
      'huso': cHuso.text.trim(),
      'tipo_vaciado': cTipoVaciado.text.trim(),
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
      if (widget.disenoExistente == null) {
        await supabase.from('disenos_mezcla').insert(payload);
      } else {
        await supabase.from('disenos_mezcla').update(payload).eq('id', widget.disenoExistente!['id']);
      }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 20,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.science, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.disenoExistente == null ? "Nuevo Diseño de Mezcla" : "Editar Diseño",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Información General", Icons.info_outline),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildInput("Huso (Ej. 67)", cHuso, Icons.tag)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("Tipo (BOMBEABLE)", cTipoVaciado, Icons.category)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("F'C (Ej. 210)", cResistencia, Icons.compress)),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle("Cantidades Base (por m³)", Icons.scale),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildInput("Cemento (kg)", cCemento, Icons.square, true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("Arena Total (kg)", cArena, Icons.grain, true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("Piedra Total (kg)", cPiedraTotal, Icons.terrain, true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildInput("Agua (Lt)", cAgua, Icons.water_drop, true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("Aditivo (kg)", cAditivo, Icons.science, true)),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildSectionTitle("Porcentajes de División (%)", Icons.pie_chart),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildInput("% Piedra 1/2", cPctPiedra12, Icons.percent, true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("% Piedra 3/4", cPctPiedra34, Icons.percent, true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("% Piedra 3/8", cPctPiedra38, Icons.percent, true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildInput("% Arena 1", cPctArena1, Icons.percent, true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInput("% Arena 2", cPctArena2, Icons.percent, true)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: guardando ? null : guardar,
                    icon: guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                    label: Text(guardando ? "Guardando..." : "Guardar Diseño", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon, [bool isNumeric = false]) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: (v) => v!.isEmpty ? 'Requerido' : null,
    );
  }
}
