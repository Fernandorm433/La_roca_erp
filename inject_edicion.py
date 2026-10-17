import sys

code = """
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
        // Sync to Drive
        await _enviarRequerimientoDrive({...v, ...updates}, isCancel: true);
      } else if (isReprogramado) {
        // Cancelar el actual
        await supabase.from('ventas_programacion').update({'estado': 'REPROGRAMADO', 'numero_atencion': '0'}).eq('id', idVenta);
        await _enviarRequerimientoDrive(v, isCancel: true); // Drive must know today's is cancelled
        
        // Crear copia para la nueva fecha
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
        // Sync new row to Drive
        await _enviarRequerimientoDrive(vCopy);
      } else {
        // Solo editar
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

with open("lib/screens/logistica/gestor_mixers_page.dart", "r") as f:
    content = f.read()

target = "  InputDecoration _softInput({Color? fillColor}) {"
new_content = content.replace(target, code + "\n" + target)

with open("lib/screens/logistica/gestor_mixers_page.dart", "w") as f:
    f.write(new_content)
