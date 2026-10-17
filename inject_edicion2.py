import os
import re

file_path = "lib/screens/logistica/gestor_mixers_page.dart"
with open(file_path, "r") as f:
    content = f.read()

# 1. Imports
content = content.replace(
    "import 'guia_pdf_preview.dart';",
    "import 'guia_pdf_preview.dart';\nimport 'package:intl/intl.dart';\nimport 'package:http/http.dart' as http;"
)

# 2. variables
content = content.replace(
    "List<Map<String, dynamic>> ventas = [];",
    "List<Map<String, dynamic>> ventas = [];\n  List<Map<String, dynamic>> ventasInactivas = [];"
)

# 3. Filtering
filter_orig = """      final ventasData = ventasDataRaw.where((v) => v['numero_atencion']?.toString() != '0').toList();"""
filter_new = """      final ventasData = ventasDataRaw.where((v) {
        final esInactivo = v['numero_atencion']?.toString() == '0' || v['estado'] == 'CANCELADO' || v['estado'] == 'REPROGRAMADO' || v['estado'] == 'SUSPENDIDO';
        return !esInactivo;
      }).toList();

      final inactivos = ventasDataRaw.where((v) {
        final esInactivo = v['numero_atencion']?.toString() == '0' || v['estado'] == 'CANCELADO' || v['estado'] == 'REPROGRAMADO' || v['estado'] == 'SUSPENDIDO';
        return esInactivo;
      }).toList();"""
content = content.replace(filter_orig, filter_new)

# 4. setState
state_orig = """        setState(() {
          ventas = List<Map<String, dynamic>>.from(ventasData);
          conductores = List<Map<String, dynamic>>.from(conductoresData);
          carguiosPorVenta = agrupados;
          bombasPorVenta = mapaBombas;
          loading = false;
        });"""
state_new = """        setState(() {
          ventas = ventasData;
          ventasInactivas = inactivos;
          conductores = conductoresData;
          carguiosPorVenta = agrupados;
          bombasPorVenta = mapaBombas;
          loading = false;
        });"""
if state_orig in content:
    content = content.replace(state_orig, state_new)
else:
    # Try another format
    state_orig2 = """        setState(() {
          ventas = ventasData;
          carguiosPorVenta = agrupados;
          conductores = conductoresData;
          bombasPorVenta = mapaBombas;
          loading = false;
        });"""
    state_new2 = """        setState(() {
          ventas = ventasData;
          ventasInactivas = inactivos;
          carguiosPorVenta = agrupados;
          conductores = conductoresData;
          bombasPorVenta = mapaBombas;
          loading = false;
        });"""
    content = content.replace(state_orig2, state_new2)

# 5. _buildClientInfo definition
buildClientOrig = """  Widget _buildClientInfo(Map<String, dynamic> v, String bomba) {
    bool hasHuso = v['huso'] != null && v['huso'].toString().trim().isNotEmpty;
    bool hasSlump = v['slump'] != null && v['slump'].toString().trim().isNotEmpty;
    bool hasAditivo = v['aditivo'] != null && v['aditivo'].toString().trim().isNotEmpty && v['aditivo'].toString() != '-';
    bool hasObs = v['observaciones'] != null && v['observaciones'].toString().trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v['nombre_razon_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 15), overflow: TextOverflow.ellipsis),"""

buildClientNew = """  Widget _buildClientInfo(Map<String, dynamic> v, String bomba, {bool isReadOnly = false}) {
    bool hasHuso = v['huso'] != null && v['huso'].toString().trim().isNotEmpty;
    bool hasSlump = v['slump'] != null && v['slump'].toString().trim().isNotEmpty;
    bool hasAditivo = v['aditivo'] != null && v['aditivo'].toString().trim().isNotEmpty && v['aditivo'].toString() != '-';
    bool hasObs = v['observaciones'] != null && v['observaciones'].toString().trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(v['nombre_razon_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 15), overflow: TextOverflow.ellipsis),
            ),
            if (!isReadOnly && !pantallaOculta)
              IconButton(
                icon: const Icon(Icons.edit_note, color: AppColors.primaryDark, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _mostrarOpcionesEdicion(v),
              ),
          ],
        ),"""
content = content.replace(buildClientOrig, buildClientNew)

# 6. _buildClientInfo calls
content = content.replace("_buildClientInfo(v, bomba),", "_buildClientInfo(v, bomba, isReadOnly: isReadOnly),")

# 7. Body logic
bodyOrig = """      body: loading 
          ? const Center(child: CircularProgressIndicator()) 
          : ventas.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fire_truck_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No hay programación para esta fecha.", style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _buildModernList(isReadOnly),"""
bodyNew = """      body: loading 
          ? const Center(child: CircularProgressIndicator()) 
          : (ventas.isEmpty && ventasInactivas.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fire_truck_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No hay programación para esta fecha.", style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _buildModernList(isReadOnly),"""
content = content.replace(bodyOrig, bodyNew)

# 8. _buildModernList definition update.
# Instead of replacing ListView.builder entirely, let's just rename it and wrap it.
modernListOrig = """  Widget _buildModernList(bool isReadOnly) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: ventas.length,
      itemBuilder: (context, index) {
        var v = ventas[index];"""

modernListNew = """  Widget _buildModernList(bool isReadOnly) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (ventas.isNotEmpty) ...ventas.map((v) => _buildVentaItem(v, isReadOnly)).toList(),
        if (ventasInactivas.isNotEmpty) ...[
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text("Requerimientos Inactivos del Día", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red.shade800)),
                  ]
                ),
                const SizedBox(height: 16),
                ...ventasInactivas.map((v) => _buildVentaItem(v, true, isInactive: true)).toList(),
              ]
            )
          )
        ]
      ],
    );
  }

  Widget _buildVentaItem(Map<String, dynamic> v, bool isReadOnly, {bool isInactive = false}) {"""
content = content.replace(modernListOrig, modernListNew)

# Now we need to fix the end of `_buildModernList` where it previously returned `Padding`.
# It used to end with `      }, \n    ); \n  }`
paddingEndOrig = """                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }"""

paddingEndNew = """                  ),
                ),
              ],
            ),
          ),
        );
  }"""
content = content.replace(paddingEndOrig, paddingEndNew)

# 9. Style inactive items in _buildVentaItem
content = content.replace("color: Colors.white,", "color: isInactive ? Colors.white70 : Colors.white,")
content = content.replace("BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))", "if (!isInactive) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))")
content = content.replace("border: Border.all(color: Colors.grey.shade200),", "border: isInactive ? Border.all(color: Colors.red.shade200, width: 1.5) : Border.all(color: Colors.grey.shade200),")
content = content.replace("color: const Color(0xFFF8FAFC),", "color: isInactive ? Colors.red.shade50 : const Color(0xFFF8FAFC),")

# Label for inactive
headerLogisticoOrig = """                        children: [
                          SizedBox(
                            width: 80,"""
headerLogisticoNew = """                        children: [
                          if (isInactive)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                              child: Text(v['estado'] ?? 'INACTIVO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          SizedBox(
                            width: 80,"""
content = content.replace(headerLogisticoOrig, headerLogisticoNew)

headerLogisticoOrig2 = """                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,"""
headerLogisticoNew2 = """                              Row(
                                children: [
                                  if (isInactive)
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                                      child: Text(v['estado'] ?? 'INACTIVO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  SizedBox(
                                    width: 80,"""
content = content.replace(headerLogisticoOrig2, headerLogisticoNew2)

# Disable textfield for inactive
content = content.replace("enabled: !isReadOnly,", "enabled: !isReadOnly && !isInactive,")
# Hide saldo for inactive
content = content.replace("""Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(balanceado ? "✓ Completo" : "Saldo: ${saldo > 0 ? '+' : ''}${saldo.toStringAsFixed(1)} m³",""", """if (!isInactive) Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(balanceado ? "✓ Completo" : "Saldo: ${saldo > 0 ? '+' : ''}${saldo.toStringAsFixed(1)} m³",""")
# Hide TRIPS for inactive
content = content.replace("""// TRIPS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),""", """// TRIPS
                if (!isInactive) Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),""")


# Inject the new functions right before `InputDecoration _softInput`
# Which is at the bottom.
methods = """
  Future<void> _enviarRequerimientoDrive(Map<String, dynamic> v, {bool isCancel = false}) async {
    try {
      final gasUrl = 'https://script.google.com/macros/s/AKfycbzKlmfOBqCQSewWueYIdBwvjj_RP7uUty2qGRjGeS3i1XrS3a0qiLeUMl8I8SfT3ut2Fg/exec';

      String doc = v['dni_ruc']?.toString() ?? '';
      String tipoDoc = doc.length == 11 ? 'FACTURA' : 'BOLETA';

      DateTime fecha = DateTime.tryParse(v['fecha_entrega']?.toString() ?? '') ?? DateTime.now();
      String hora = v['hora_entrega']?.toString() ?? '';
      if (hora.length >= 5) hora = hora.substring(0, 5);

      final params = {
        'asesor': v['creado_por'] ?? '',
        'day': DateFormat('dd/MM/yyyy').format(fecha),
        'hour': hora,
        'client': (v['nombre_razon_social'] ?? '').toString().toUpperCase(),
        'tipoDocumento': tipoDoc,
        'document': doc,
        'address': v['direccion'] ?? '',
        'phone': v['telefono'] ?? '',
        'distrito': v['distrito'] ?? '',
        'volumen': isCancel ? '0' : (v['volumen']?.toString() ?? '0'),
        'fuerza': v['diseno'] ?? '',
        'elemento': v['elemento'] ?? '',
        'huso': v['huso'] ?? '',
        'slump': v['slump'] ?? '',
        'aditivo': v['aditivo'] ?? '',
        'cemento': v['cemento'] ?? '',
        'bombas': v['bomba'] ?? '', 
        'extensiones': '',
        'selectedMixer': '',
        'selectedCapacity': '',
        'time': hora,
        'quality': '',
        'commentReturn': isCancel ? 'CANCELADO DESDE APP' : 'MODIFICADO DESDE APP',
        'location': v['obra_maps_link'] ?? '',
        'urlVoucher': '',
        'emisionReq': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        'observaciones': v['observaciones'] ?? '',
      };

      final bodyText = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      await http.post(
        Uri.parse(gasUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyText,
      );
    } catch (e) {
      debugPrint("Error al enviar a Drive desde Despachos: $e");
    }
  }

  void _mostrarOpcionesEdicion(Map<String, dynamic> v) {
    String estadoSeleccionado = v['estado'] ?? 'ACTIVO';
    if (estadoSeleccionado == 'PENDIENTE') estadoSeleccionado = 'ACTIVO';
    if (v['numero_atencion']?.toString() == '0') estadoSeleccionado = 'CANCELADO';
    
    DateTime nuevaFecha = DateTime.tryParse(v['fecha_entrega']?.toString() ?? '') ?? DateTime.now();
    
    TextEditingController volCtrl = TextEditingController(text: v['volumen']?.toString() ?? '');
    TextEditingController disenoCtrl = TextEditingController(text: v['diseno']?.toString() ?? '');
    TextEditingController husoCtrl = TextEditingController(text: v['huso']?.toString() ?? '');
    TextEditingController slumpCtrl = TextEditingController(text: v['slump']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Editar Requerimiento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  // Estado
                  const Text("Estado", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    value: ['ACTIVO', 'REPROGRAMADO', 'CANCELADO', 'SUSPENDIDO'].contains(estadoSeleccionado) ? estadoSeleccionado : 'ACTIVO',
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
                    items: ['ACTIVO', 'REPROGRAMADO', 'CANCELADO', 'SUSPENDIDO'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) async {
                      setStateModal(() => estadoSeleccionado = val!);
                      if (val == 'REPROGRAMADO') {
                        final res = await showDatePicker(
                          context: context,
                          initialDate: nuevaFecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (res != null) {
                          setStateModal(() => nuevaFecha = res);
                        } else {
                          setStateModal(() => estadoSeleccionado = 'ACTIVO');
                        }
                      }
                    },
                  ),
                  
                  if (estadoSeleccionado == 'REPROGRAMADO') ...[
                    const SizedBox(height: 10),
                    Text("Nueva Fecha: ${DateFormat('dd/MM/yyyy').format(nuevaFecha)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildModalTextField("Volumen", volCtrl, isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildModalTextField("Diseño", disenoCtrl)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildModalTextField("Huso", husoCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildModalTextField("Slump", slumpCtrl)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _guardarCambiosEdicion(v, estadoSeleccionado, nuevaFecha, volCtrl.text, disenoCtrl.text, husoCtrl.text, slumpCtrl.text);
                      },
                      child: const Text("Guardar Cambios", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildModalTextField(String label, TextEditingController ctrl, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        )
      ],
    );
  }

  Future<void> _guardarCambiosEdicion(Map<String, dynamic> v, String estado, DateTime nuevaFecha, String volumen, String diseno, String huso, String slump) async {
    setState(() => loading = true);
    try {
      String idVenta = v['id'].toString();
      bool isCancel = estado == 'CANCELADO' || estado == 'SUSPENDIDO';
      bool isReprogramado = estado == 'REPROGRAMADO';
      
      Map<String, dynamic> updates = {
        'volumen': double.tryParse(volumen) ?? 0,
        'diseno': diseno,
        'huso': huso,
        'slump': slump,
        'estado': estado,
        'numero_atencion': isCancel ? '0' : v['numero_atencion']
      };

      if (isCancel) {
        await supabase.from('ventas_programacion').update(updates).eq('id', idVenta);
        await _enviarRequerimientoDrive({...v, ...updates}, isCancel: true);
      } else if (isReprogramado) {
        // Cancel current row
        await supabase.from('ventas_programacion').update({'estado': 'REPROGRAMADO', 'numero_atencion': '0'}).eq('id', idVenta);
        await _enviarRequerimientoDrive(v, isCancel: true); 
        
        // New row
        Map<String, dynamic> vCopy = Map<String, dynamic>.from(v);
        vCopy.remove('id');
        vCopy.remove('created_at');
        vCopy['fecha_entrega'] = nuevaFecha.toIso8601String().split('T')[0];
        vCopy['estado'] = 'ACTIVO';
        vCopy['numero_atencion'] = '1';
        vCopy['volumen'] = double.tryParse(volumen) ?? 0;
        vCopy['diseno'] = diseno;
        vCopy['huso'] = huso;
        vCopy['slump'] = slump;
        
        await supabase.from('ventas_programacion').insert(vCopy);
        await _enviarRequerimientoDrive(vCopy);
      } else {
        await supabase.from('ventas_programacion').update(updates).eq('id', idVenta);
        await _enviarRequerimientoDrive({...v, ...updates});
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requerimiento actualizado con éxito ✅'), backgroundColor: Colors.green));
      }
      
      await _cargarDatos();
    } catch (e) {
      debugPrint("Error guardando cambios requerimiento: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
      setState(() => loading = false);
    }
  }

"""

content = content.replace("  InputDecoration _softInput", methods + "\n  InputDecoration _softInput")

with open(file_path, "w") as f:
    f.write(content)
